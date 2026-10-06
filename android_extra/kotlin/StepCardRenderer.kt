package com.ihsanstudio.halalcalorie

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.graphics.Typeface
import java.util.Locale

// ─────────────────────────────────────────────────────────────
//  StepCardRenderer.kt — HalalCalorie v59 (PATCH_V59_STEPCARD)
//  Draws the whole card into a Bitmap, so the notification shade
//  shows exactly the same polished artwork the settings preview does.
//  Everything is a pure function of (config, palette, time, steps).
// ─────────────────────────────────────────────────────────────

class RenderState(
    val cfg: CardConfig,
    val pal: Pal,
    val shown: Float,          // the animated (counting-up) step number
    val steps: Int,            // the true step count
    val t: Float,              // seconds, drives every animation
    val sinceStepMs: Long,
    val sinceCelebMs: Long,
    val week: IntArray,
    val anim: Int              // effective animation level 0..3
)

class StepCardRenderer(private val ctx: Context) {
    companion object {
        const val W = 900
        const val H_SMALL = 156
        const val GOLD1 = 0xFFFFC94D.toInt()
        const val GOLD2 = 0xFFFFF0B8.toInt()
    }

    private val fontBold: Typeface = loadFont("AligarhArabicFREEPERSONALUSE-Bold.otf", Typeface.DEFAULT_BOLD)
    private val fontHeavy: Typeface = loadFont("AligarhArabicFREEPERSONALUSE-ExtraBold.otf", fontBold)
    private var logo: Bitmap? = loadLogo()

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private val tp = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bmpPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val path = Path()
    private val rect = RectF()

    // per-frame working state
    private lateinit var c: Canvas
    private lateinit var st: RenderState
    private var h = H_SMALL
    private var rtl = false
    private var acc = 0
    private var acc2 = 0
    private var done = false
    private var pct = 0f

    private fun loadFont(file: String, fallback: Typeface): Typeface = try {
        Typeface.createFromAsset(ctx.assets, "flutter_assets/assets/fonts/$file")
    } catch (e: Exception) { fallback }

    private fun loadLogo(): Bitmap? = try {
        ctx.assets.open("flutter_assets/assets/logo.png").use { ins ->
            val raw = BitmapFactory.decodeStream(ins)
            if (raw == null) null else {
                val side = minOf(raw.width, raw.height)
                val target = 256
                val sq = Bitmap.createBitmap(raw, (raw.width - side) / 2, (raw.height - side) / 2, side, side)
                if (side > target) Bitmap.createScaledBitmap(sq, target, target, true) else sq
            }
        }
    } catch (e: Exception) { null }

    fun heightFor(expanded: Boolean, cfg: CardConfig): Int =
        if (!expanded) H_SMALL else if (cfg.showWeek) 560 else 420

    // ── public ────────────────────────────────────────────────
    fun render(expanded: Boolean, state: RenderState, reuse: Bitmap?): Bitmap {
        val hh = heightFor(expanded, state.cfg)
        val bmp = if (reuse != null && reuse.width == W && reuse.height == hh && reuse.isMutable) reuse
                  else Bitmap.createBitmap(W, hh, Bitmap.Config.ARGB_8888)
        bmp.eraseColor(Color.TRANSPARENT)
        c = Canvas(bmp)
        st = state
        h = hh
        rtl = state.cfg.rtl
        pct = (state.steps.toFloat() / state.cfg.goal).coerceIn(0f, 1f)
        done = state.steps >= state.cfg.goal
        acc = if (done) GOLD1 else state.pal.accent
        acc2 = if (done) GOLD2 else state.pal.accent2

        drawBackground()
        if (state.anim >= 1) drawAmbient()
        if (state.sinceCelebMs in 0..9000L) drawConfetti()

        if (expanded) layoutExpanded() else layoutCollapsed()
        drawBorder()
        return bmp
    }

    fun describe(state: RenderState): String {
        val cfg = state.cfg
        val sb = StringBuilder()
        sb.append(fmtInt(state.steps)).append(' ').append(cfg.s("steps", "steps"))
        if (cfg.showKcal) sb.append(", ").append(fmtInt((state.steps * cfg.kcalPerStep).toInt())).append(' ').append(cfg.s("kcal", "kcal"))
        if (cfg.showDist) sb.append(", ").append(fmtDec(state.steps * cfg.strideKm)).append(' ').append(cfg.s("km", "km"))
        sb.append(", ").append((state.steps * 100 / cfg.goal)).append("%")
        return sb.toString()
    }

    // ── formatting ────────────────────────────────────────────
    private fun digits(s: String): String {
        if (!st.cfg.arabicDigits) return s
        val sb = StringBuilder()
        for (ch in s) {
            sb.append(when (ch) {
                in '0'..'9' -> ('\u0660' + (ch - '0'))
                ',' -> '\u066C'
                '.' -> '\u066B'
                else -> ch
            })
        }
        return sb.toString()
    }
    private fun fmtInt(n: Int): String = digits(String.format(Locale.US, "%,d", n))
    private fun fmtDec(x: Float): String = digits(String.format(Locale.US, "%.1f", x))

    // ── drawing helpers ───────────────────────────────────────
    /** Run [block] in LTR coordinates; mirrored for right-to-left languages. */
    private inline fun gfx(block: () -> Unit) {
        c.save()
        if (rtl) { c.translate(W.toFloat(), 0f); c.scale(-1f, 1f) }
        block()
        c.restore()
    }

    /** align: 0 = start edge, 1 = end edge, 2 = centre — all in LTR coordinates. Returns the text width. */
    private fun text(s: String, x: Float, y: Float, size: Float, color: Int,
                     align: Int = 0, maxW: Float = 0f, heavy: Boolean = false): Float {
        tp.typeface = if (heavy) fontHeavy else fontBold
        tp.textSize = size
        tp.color = color
        tp.shader = null
        var w = tp.measureText(s)
        if (maxW > 0f && w > maxW) { tp.textSize = size * maxW / w; w = tp.measureText(s) }
        val ax = if (rtl) W - x else x
        tp.textAlign = when (align) {
            2 -> Paint.Align.CENTER
            1 -> if (rtl) Paint.Align.LEFT else Paint.Align.RIGHT
            else -> if (rtl) Paint.Align.RIGHT else Paint.Align.LEFT
        }
        c.drawText(s, ax, y, tp)
        return w
    }

    private fun measure(s: String, size: Float, heavy: Boolean = false): Float {
        tp.typeface = if (heavy) fontHeavy else fontBold
        tp.textSize = size
        return tp.measureText(s)
    }

    private fun rnd(i: Int, k: Int): Float {
        val x = Math.sin(i * 127.1 + k * 311.7) * 43758.5453
        return (x - Math.floor(x)).toFloat()
    }

    private fun glow(x: Float, y: Float, r: Float, color: Int, a: Float) {
        fill.shader = RadialGradient(x, y, r, Palettes.withAlpha(color, a), Color.TRANSPARENT, Shader.TileMode.CLAMP)
        c.drawCircle(x, y, r, fill)
        fill.shader = null
    }

    // ── background, ambience, border ──────────────────────────
    private fun drawBackground() {
        val p = st.pal
        val radius = if (h <= H_SMALL) 46f else 58f
        rect.set(0f, 0f, W.toFloat(), h.toFloat())
        path.reset()
        path.addRoundRect(rect, radius, radius, Path.Direction.CW)
        c.save()
        c.clipPath(path)
        fill.shader = LinearGradient(0f, 0f, W * 0.7f, h.toFloat(), p.bgTop, p.bgBottom, Shader.TileMode.CLAMP)
        c.drawRect(rect, fill)
        fill.shader = null
        val t = if (st.anim >= 1) st.t else 0f
        val big = h * 1.15f
        glow(W * (0.18f + 0.10f * Math.sin(t * 0.45).toFloat()), h * (0.30f + 0.10f * Math.cos(t * 0.35).toFloat()),
             big, if (done) GOLD1 else p.glow1, if (p.light) 0.30f else 0.34f)
        glow(W * (0.88f + 0.06f * Math.cos(t * 0.40).toFloat()), h * (0.85f + 0.08f * Math.sin(t * 0.30).toFloat()),
             big * 0.9f, if (done) GOLD2 else p.glow2, if (p.light) 0.35f else 0.20f)
        // soft top sheen
        fill.shader = LinearGradient(0f, 0f, 0f, h * 0.55f,
            Palettes.withAlpha(Color.WHITE, if (p.light) 0.55f else 0.10f), Color.TRANSPARENT, Shader.TileMode.CLAMP)
        c.drawRect(0f, 0f, W.toFloat(), h * 0.55f, fill)
        fill.shader = null
        c.restore()
    }

    private fun drawBorder() {
        val radius = if (h <= H_SMALL) 46f else 58f
        rect.set(1.5f, 1.5f, W - 1.5f, h - 1.5f)
        line.shader = null
        line.strokeWidth = 3f
        line.color = Palettes.withAlpha(if (done) GOLD1 else st.pal.border, if (done) 0.55f else 1f)
        c.drawRoundRect(rect, radius, radius, line)
    }

    private fun drawAmbient() {
        val cfg = st.cfg
        val p = st.pal
        if (cfg.style != "zen" && cfg.particles) {
            val n = intArrayOf(0, 7, 13, 20)[st.anim.coerceIn(0, 3)]
            for (i in 0 until n) {
                val speed = 0.035f + 0.05f * rnd(i, 1)
                val u = (st.t * speed + rnd(i, 2)) % 1f
                val x = rnd(i, 3) * W
                val y = h * (1.05f - 1.1f * u)
                val r = 2.2f + 3.6f * rnd(i, 4)
                val tw = 0.5f + 0.5f * Math.sin(st.t * (1.2 + rnd(i, 5) * 1.8) + i).toFloat()
                val edge = Math.sin(Math.PI * u).toFloat()
                fill.color = Palettes.withAlpha(p.spark, (0.10f + 0.38f * tw) * edge * (if (p.light) 0.8f else 1f))
                c.drawCircle(x, y, r, fill)
            }
        }
        if (cfg.footprints && cfg.style != "zen" && st.anim >= 1) {
            val n = 6
            for (i in 0 until n) {
                val u = (st.t * 0.10f + i / n.toFloat()) % 1f
                val side = if (i % 2 == 0) 1f else -1f
                val x = W * (0.50f + 0.46f * u)
                val y = h * (0.92f - 0.80f * u) + side * 26f
                val a = Math.sin(Math.PI * u).toFloat() * (if (p.light) 0.10f else 0.13f)
                footprint(x, y, 30f, -28f, Palettes.withAlpha(if (p.light) p.accent else Color.WHITE, a), side < 0f)
            }
        }
    }

    private fun drawConfetti() {
        val s = st.sinceCelebMs / 1000f
        val colors = intArrayOf(GOLD1, GOLD2, st.pal.accent2, 0xFFFF7BAC.toInt(), 0xFF6FB3FF.toInt(), Color.WHITE)
        val fade = (1f - ((st.sinceCelebMs - 6500f) / 2500f)).coerceIn(0f, 1f)
        for (i in 0 until 46) {
            val x0 = rnd(i, 7) * W
            val sway = 38f * Math.sin(s * (2.0 + rnd(i, 8) * 3.0) + i).toFloat()
            val fall = 150f + 230f * rnd(i, 9)
            val y = -30f + s * fall - 160f * rnd(i, 10)
            if (y < -20f || y > h + 20f) continue
            fill.color = Palettes.withAlpha(colors[i % colors.size], 0.95f * fade)
            c.save()
            c.translate(x0 + sway, y)
            c.rotate(s * (180f + 300f * rnd(i, 11)) + i * 17f)
            val w = 8f + 9f * rnd(i, 12)
            c.drawRect(-w / 2, -w / 4, w / 2, w / 4, fill)
            c.restore()
        }
    }

    // ── icons (unit boxes centred on cx, cy) ──────────────────
    private fun footprint(cx: Float, cy: Float, size: Float, rot: Float, color: Int, flip: Boolean) {
        c.save()
        c.translate(cx, cy)
        c.rotate(rot)
        if (flip) c.scale(-1f, 1f)
        fill.color = color
        rect.set(-0.24f * size, -0.02f * size, 0.24f * size, 0.62f * size)
        c.drawOval(rect, fill)
        c.drawCircle(-0.26f * size, -0.28f * size, 0.10f * size, fill)
        c.drawCircle(-0.09f * size, -0.40f * size, 0.10f * size, fill)
        c.drawCircle(0.09f * size, -0.42f * size, 0.10f * size, fill)
        c.drawCircle(0.26f * size, -0.32f * size, 0.09f * size, fill)
        c.restore()
    }

    private fun iconFlame(cx: Float, cy: Float, s: Float, color: Int) {
        c.save()
        c.translate(cx - s / 2, cy - s / 2)
        c.scale(s, s)
        path.reset()
        path.moveTo(0.50f, 0.00f)
        path.cubicTo(0.56f, 0.24f, 0.90f, 0.38f, 0.88f, 0.68f)
        path.cubicTo(0.86f, 0.88f, 0.68f, 1.00f, 0.50f, 1.00f)
        path.cubicTo(0.32f, 1.00f, 0.14f, 0.88f, 0.12f, 0.68f)
        path.cubicTo(0.10f, 0.52f, 0.24f, 0.42f, 0.30f, 0.26f)
        path.cubicTo(0.38f, 0.38f, 0.42f, 0.42f, 0.46f, 0.44f)
        path.cubicTo(0.50f, 0.30f, 0.44f, 0.14f, 0.50f, 0.00f)
        path.close()
        fill.color = color
        c.drawPath(path, fill)
        fill.color = Palettes.withAlpha(Color.WHITE, 0.45f)
        c.drawCircle(0.5f, 0.74f, 0.17f, fill)
        c.restore()
    }

    private fun iconRoute(cx: Float, cy: Float, s: Float, color: Int) {
        c.save()
        c.translate(cx - s / 2, cy - s / 2)
        c.scale(s, s)
        path.reset()
        path.moveTo(0.22f, 0.80f)
        path.cubicTo(0.22f, 0.40f, 0.78f, 0.62f, 0.78f, 0.22f)
        line.shader = null
        line.color = color
        line.strokeWidth = 0.11f
        c.drawPath(path, line)
        fill.color = color
        c.drawCircle(0.22f, 0.80f, 0.13f, fill)
        c.drawCircle(0.78f, 0.22f, 0.13f, fill)
        c.restore()
    }

    private fun iconTarget(cx: Float, cy: Float, s: Float, color: Int) {
        line.shader = null
        line.color = color
        line.strokeWidth = s * 0.12f
        c.drawCircle(cx, cy, s * 0.40f, line)
        fill.color = color
        c.drawCircle(cx, cy, s * 0.16f, fill)
    }

    private fun iconFlag(cx: Float, cy: Float, s: Float, color: Int) {
        c.save()
        c.translate(cx - s / 2, cy - s / 2)
        c.scale(s, s)
        line.shader = null
        line.color = color
        line.strokeWidth = 0.10f
        c.drawLine(0.24f, 0.08f, 0.24f, 0.96f, line)
        path.reset()
        path.moveTo(0.26f, 0.10f)
        path.cubicTo(0.46f, 0.00f, 0.60f, 0.22f, 0.86f, 0.12f)
        path.lineTo(0.86f, 0.56f)
        path.cubicTo(0.60f, 0.66f, 0.46f, 0.44f, 0.26f, 0.54f)
        path.close()
        fill.color = color
        c.drawPath(path, fill)
        c.restore()
    }

    // ── emblem: the logo, framed ──────────────────────────────
    private fun drawLogoIn(cx: Float, cy: Float, r: Float, squircle: Boolean) {
        val bob = if (st.anim >= 1) (1f + 0.025f * Math.sin(st.t * 2.2).toFloat()) else 1f
        c.save()
        c.translate(cx, cy)
        c.scale(bob, bob)
        path.reset()
        if (squircle) { rect.set(-r, -r, r, r); path.addRoundRect(rect, r * 0.42f, r * 0.42f, Path.Direction.CW) }
        else path.addCircle(0f, 0f, r, Path.Direction.CW)
        c.clipPath(path)
        fill.color = st.pal.plate
        c.drawRect(-r, -r, r, r, fill)
        val lg = logo
        if (lg != null) {
            rect.set(-r, -r, r, r)
            c.drawBitmap(lg, null, rect, bmpPaint)
        } else {
            footprint(0f, -r * 0.1f, r * 1.1f, -18f, acc, false)
        }
        // glassy highlight
        fill.shader = LinearGradient(0f, -r, 0f, r * 0.2f, Palettes.withAlpha(Color.WHITE, 0.20f), Color.TRANSPARENT, Shader.TileMode.CLAMP)
        c.drawRect(-r, -r, r, r, fill)
        fill.shader = null
        c.restore()
    }

    /** kind 0 = ring + logo, 1 = squircle plate, 2 = small calm ring. */
    private fun drawEmblem(cx: Float, cy: Float, r: Float, kind: Int) {
        gfx {
            val t = if (st.anim >= 1) st.t else 0f
            val pulse = 0.5f + 0.5f * Math.sin(t * 2.4).toFloat()
            glow(cx, cy, r * 1.9f, acc, (if (st.pal.light) 0.16f else 0.20f) + 0.12f * pulse)
            if (kind == 1) {
                drawLogoIn(cx, cy, r, true)
                line.shader = null
                line.strokeWidth = 3f
                line.color = Palettes.withAlpha(acc2, 0.55f)
                rect.set(cx - r, cy - r, cx + r, cy + r)
                c.drawRoundRect(rect, r * 0.42f, r * 0.42f, line)
                return@gfx
            }
            val stroke = r * (if (kind == 0) 0.17f else 0.14f)
            val ringR = if (kind == 0) r else r
            val inner = ringR - stroke * 1.15f
            // track
            line.shader = null
            line.strokeWidth = stroke
            line.color = st.pal.track
            c.drawCircle(cx, cy, ringR, line)
            // progress
            val sweep = 360f * pct
            rect.set(cx - ringR, cy - ringR, cx + ringR, cy + ringR)
            if (sweep > 0.5f) {
                c.save()
                c.rotate(-90f, cx, cy)
                val sg = SweepGradient(cx, cy, intArrayOf(acc2, acc, acc), floatArrayOf(0f, (pct).coerceAtLeast(0.02f), 1f))
                line.shader = sg
                line.strokeWidth = stroke
                c.drawArc(rect, 0f, sweep, false, line)
                line.shader = null
                c.restore()
                // glowing head
                val ang = Math.toRadians((-90f + sweep).toDouble())
                val hx = cx + ringR * Math.cos(ang).toFloat()
                val hy = cy + ringR * Math.sin(ang).toFloat()
                glow(hx, hy, stroke * (1.5f + 0.5f * pulse), Color.WHITE, 0.55f)
                fill.color = Color.WHITE
                c.drawCircle(hx, hy, stroke * 0.30f, fill)
            }
            // a walker orbiting the ring
            if (st.anim >= 2 && !done && kind == 0) {
                for (k in 0 until 5) {
                    val a = Math.toRadians((st.t * 55f - k * 7f).toDouble())
                    val ox = cx + (ringR + stroke * 0.95f) * Math.cos(a).toFloat()
                    val oy = cy + (ringR + stroke * 0.95f) * Math.sin(a).toFloat()
                    fill.color = Palettes.withAlpha(acc2, 0.85f - k * 0.17f)
                    c.drawCircle(ox, oy, stroke * (0.26f - k * 0.035f), fill)
                }
            }
            // ripple when a step just landed
            if (st.anim >= 1 && st.sinceStepMs in 0..1100L) {
                val e = st.sinceStepMs / 1100f
                line.strokeWidth = 4f
                line.color = Palettes.withAlpha(acc2, (1f - e) * 0.8f)
                c.drawCircle(cx, cy, ringR + stroke + e * r * 0.55f, line)
            }
            drawLogoIn(cx, cy, inner, false)
        }
    }

    // ── progress bar ──────────────────────────────────────────
    private fun drawBar(x: Float, y: Float, w: Float, bh: Float) {
        gfx {
            val rad = bh / 2
            rect.set(x, y, x + w, y + bh)
            fill.shader = null
            fill.color = st.pal.track
            c.drawRoundRect(rect, rad, rad, fill)
            val fw = (w * pct).coerceAtLeast(if (pct > 0f) bh else 0f)
            if (fw > 0f) {
                rect.set(x, y, x + fw, y + bh)
                c.save()
                path.reset(); path.addRoundRect(rect, rad, rad, Path.Direction.CW)
                c.clipPath(path)
                fill.shader = LinearGradient(x, 0f, x + w, 0f, acc2, acc, Shader.TileMode.CLAMP)
                c.drawRect(rect, fill)
                fill.shader = null
                if (st.cfg.shimmer && st.anim >= 1) {
                    val band = bh * 5f
                    val u = (st.t * 0.42f) % 1.6f - 0.3f
                    val sx = x + (fw + band) * u - band * 0.5f
                    fill.shader = LinearGradient(sx, 0f, sx + band, 0f,
                        intArrayOf(Color.TRANSPARENT, Palettes.withAlpha(Color.WHITE, 0.75f), Color.TRANSPARENT),
                        floatArrayOf(0f, 0.5f, 1f), Shader.TileMode.CLAMP)
                    c.drawRect(rect, fill)
                    fill.shader = null
                }
                // top gloss
                fill.shader = LinearGradient(0f, y, 0f, y + bh, Palettes.withAlpha(Color.WHITE, 0.35f), Color.TRANSPARENT, Shader.TileMode.CLAMP)
                c.drawRect(x, y, x + fw, y + bh * 0.55f, fill)
                fill.shader = null
                c.restore()
                // glowing head
                val pulse = 0.5f + 0.5f * Math.sin((if (st.anim >= 1) st.t else 0f) * 3.0).toFloat()
                glow(x + fw - rad, y + rad, bh * (1.2f + 0.5f * pulse), acc2, 0.55f)
            }
            // milestones
            for (m in 1..3) {
                val mx = x + w * m / 4f
                val passed = pct >= m / 4f
                fill.color = if (passed) Palettes.withAlpha(Color.WHITE, 0.85f) else Palettes.withAlpha(st.pal.text, 0.22f)
                c.drawCircle(mx, y + rad, bh * 0.11f, fill)
            }
        }
    }

    // ── layouts ───────────────────────────────────────────────
    private fun numberText(): String = fmtInt(Math.round(st.shown))

    private fun bumpScale(): Float {
        if (st.anim < 1 || st.sinceStepMs !in 0..700L) return 1f
        val e = st.sinceStepMs / 700f
        return 1f + 0.07f * (1f - e) * (1f - e)
    }

    private fun drawBig(s: String, x: Float, y: Float, size: Float, maxW: Float) {
        val sc = bumpScale()
        val ax = if (rtl) W - x else x
        c.save()
        c.scale(sc, sc, ax, y)
        text(s, x, y, size, if (done) GOLD2 else st.pal.text, 0, maxW, true)
        c.restore()
    }

    private fun statValues(): List<Triple<Int, String, String>> {
        val cfg = st.cfg
        val out = ArrayList<Triple<Int, String, String>>()
        if (cfg.showKcal) out.add(Triple(0, fmtInt((st.steps * cfg.kcalPerStep).toInt()), cfg.s("kcal", "kcal")))
        if (cfg.showDist) out.add(Triple(1, fmtDec(st.steps * cfg.strideKm), cfg.s("km", "km")))
        if (cfg.showPct) out.add(Triple(2, digits((st.steps * 100 / cfg.goal).toString()), "%"))
        return out
    }

    private fun statIcon(kind: Int, cx: Float, cy: Float, s: Float, color: Int) {
        gfx {
            when (kind) {
                0 -> iconFlame(cx, cy, s, color)
                1 -> iconRoute(cx, cy, s, color)
                else -> iconTarget(cx, cy, s, color)
            }
        }
    }

    private fun message(): String {
        val cfg = st.cfg
        if (done) return cfg.s("goalDone", "Goal reached")
        val left = cfg.goal - st.steps
        val key = when {
            pct < 0.25f -> "m0"
            pct < 0.5f -> "m1"
            pct < 0.75f -> "m2"
            else -> "m3"
        }
        // Alternate between the encouragement and the remaining count.
        val showLeft = ((st.t / 6f).toInt() % 2 == 1) && st.anim >= 1
        return if (showLeft) cfg.s("toGo", "{n} to go").replace("{n}", fmtInt(left))
               else cfg.s(key, "Keep going")
    }

    private fun layoutCollapsed() {
        val cfg = st.cfg
        when (cfg.style) {
            "stride" -> drawEmblem(78f, 78f, 50f, 1)
            "zen" -> drawEmblem(62f, 70f, 36f, 2)
            else -> drawEmblem(84f, 78f, 56f, 0)
        }
        val tx = when (cfg.style) { "stride" -> 156f; "zen" -> 124f; else -> 172f }
        val statsW = if (cfg.style == "zen") 120f else 250f
        text(cfg.s("today", "TODAY"), tx, 40f, 24f, st.pal.sub, 0, 300f)
        drawBig(numberText(), tx, 104f, if (cfg.style == "zen") 78f else 72f, W - tx - statsW - 20f)
        // right-hand stats
        val vals = statValues()
        if (cfg.style == "zen") {
            val pv = digits((st.steps * 100 / cfg.goal).toString()) + "%"
            text(pv, W - 40f, 100f, 46f, acc2, 1, 0f, true)
        } else if (vals.isNotEmpty()) {
            val rows = vals.filter { it.first != 2 }.take(2)
            var yy = if (rows.size == 1) 88f else 62f
            for (r in rows) {
                val label = r.second + " " + r.third
                val wv = text(label, W - 44f, yy + 10f, 30f, st.pal.text, 1, statsW - 44f, false)
                statIcon(r.first, W - 44f - wv - 24f, yy, 28f, acc)
                yy += 44f
            }
        }
        drawBar(tx, 124f, W - tx - 44f, 14f)
    }

    private fun layoutExpanded() {
        val cfg = st.cfg
        val style = cfg.style
        val vals = statValues()
        // emblem
        when (style) {
            "stride" -> drawEmblem(130f, 130f, 92f, 1)
            "zen" -> drawEmblem(82f, 84f, 44f, 2)
            else -> drawEmblem(150f, 150f, 100f, 0)
        }
        val tx = when (style) { "stride" -> 258f; "zen" -> 150f; else -> 296f }
        val zen = style == "zen"
        if (zen) {
            text(cfg.s("today", "TODAY"), tx, 96f, 30f, st.pal.sub, 0, 400f)
            drawBig(numberText(), 40f, 270f, 176f, W - 80f)
        } else {
            text(cfg.s("today", "TODAY"), tx, 74f, 30f, st.pal.sub, 0, 560f)
            drawBig(numberText(), tx, 190f, 124f, W - tx - 36f)
        }
        // stats
        val rowY = if (zen) 0f else if (style == "stride") 232f else 214f
        if (!zen && vals.isNotEmpty()) {
            var x = tx
            for (v in vals) {
                val label = v.second + (if (v.third == "%") "" else " " + v.third)
                val tw = measure(label, 32f)
                val chipW = tw + 64f
                if (style == "orbit") {
                    gfx {
                        rect.set(x, rowY, x + chipW, rowY + 62f)
                        fill.color = st.pal.chip
                        c.drawRoundRect(rect, 31f, 31f, fill)
                    }
                    statIcon(v.first, x + 30f, rowY + 31f, 30f, acc)
                    text(label, x + 52f, rowY + 43f, 32f, st.pal.text)
                    x += chipW + 14f
                } else {
                    statIcon(v.first, x + 16f, rowY + 22f, 32f, acc)
                    text(label, x + 40f, rowY + 33f, 32f, st.pal.text)
                    x += tw + 40f + 28f
                }
            }
        }
        if (zen) {
            val pv = digits((st.steps * 100 / cfg.goal).toString()) + "%"
            text(pv, W - 40f, 96f, 48f, acc2, 1, 0f, true)
        }
        // bar
        val barY = 312f
        val barH = if (style == "stride") 34f else if (zen) 14f else 26f
        drawBar(40f, barY, W - 80f, barH)
        if (cfg.showMsg) {
            text(message(), 40f, barY + barH + 50f, 31f, st.pal.sub, 0, 560f)
        }
        // goal flag
        val goalLabel = fmtInt(cfg.goal)
        val gw = measure(goalLabel, 30f)
        gfx { iconFlag(W - 40f - gw - 26f, barY + barH + 38f, 28f, if (done) GOLD1 else st.pal.sub) }
        text(goalLabel, W - 40f, barY + barH + 50f, 30f, if (done) GOLD2 else st.pal.sub, 1)
        if (cfg.showWeek) drawWeek(barY + barH + 78f)
    }

    private fun drawWeek(top: Float) {
        val cfg = st.cfg
        val wk = st.week
        var mx = cfg.goal
        for (v in wk) if (v > mx) mx = v
        val baseline = top + 92f
        val bw = 66f
        val gap = (W - 80f - bw * 7f) / 6f
        gfx {
            // goal line
            val gy = baseline - 92f * cfg.goal / mx
            line.shader = null
            line.strokeWidth = 2f
            line.color = Palettes.withAlpha(st.pal.text, 0.14f)
            c.drawLine(40f, gy, W - 40f, gy, line)
            for (i in 0 until 7) {
                val x = 40f + i * (bw + gap)
                val hv = (92f * wk[i] / mx).coerceAtLeast(if (wk[i] > 0) 8f else 5f)
                val isToday = i == 6
                rect.set(x, baseline - hv, x + bw, baseline)
                if (isToday) {
                    fill.shader = LinearGradient(0f, baseline - hv, 0f, baseline, acc2, acc, Shader.TileMode.CLAMP)
                } else {
                    fill.shader = null
                    fill.color = if (wk[i] >= cfg.goal) Palettes.withAlpha(GOLD1, 0.85f) else Palettes.withAlpha(st.pal.text, 0.20f)
                }
                c.drawRoundRect(rect, 14f, 14f, fill)
                fill.shader = null
            }
        }
        for (i in 0 until 7) {
            val x = 40f + i * (bw + gap)
            val letter = StepState.narrowDay(i - 6, cfg.lang)
            text(letter, x + bw / 2, baseline + 36f, 26f, if (i == 6) st.pal.text else st.pal.sub, 2)
        }
    }
}
