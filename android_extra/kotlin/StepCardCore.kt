package com.ihsanstudio.halalcalorie

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

// ─────────────────────────────────────────────────────────────
//  StepCardCore.kt — HalalCalorie v59 (PATCH_V59_STEPCARD)
//  Config + palettes + the persistent step state behind the
//  live step card in the notification shade.
// ─────────────────────────────────────────────────────────────

class CardConfig(p: SharedPreferences) {
    val enabled = p.getBoolean("enabled", false)
    val theme = p.getString("theme", "green") ?: "green"        // green | white | random | auto
    val style = p.getString("style", "orbit") ?: "orbit"        // orbit | stride | zen
    val accent = p.getString("accent", "default") ?: "default"
    val goal = num(p, "goal", 10000f).toInt().coerceIn(1000, 100000)
    val kcalPerStep = num(p, "kcalPerStep", 0.04f).coerceIn(0.005f, 0.2f)
    val strideCm = num(p, "strideCm", 76f).coerceIn(30f, 150f)
    val anim = num(p, "anim", 2f).toInt().coerceIn(0, 3)        // 0 off, 1 calm, 2 lively, 3 max
    val particles = p.getBoolean("particles", true)
    val shimmer = p.getBoolean("shimmer", true)
    val footprints = p.getBoolean("footprints", true)
    val celebrate = p.getBoolean("celebrate", true)
    val showKcal = p.getBoolean("showKcal", true)
    val showDist = p.getBoolean("showDist", true)
    val showPct = p.getBoolean("showPct", true)
    val showWeek = p.getBoolean("showWeek", true)
    val showMsg = p.getBoolean("showMsg", true)
    val arabicDigits = p.getBoolean("arabicDigits", false)
    val statusIcon = p.getBoolean("statusIcon", true)
    val lock = p.getString("lock", "full") ?: "full"            // full | hide
    val bootStart = p.getBoolean("bootStart", true)
    val lang = p.getString("lang", "ar") ?: "ar"
    val dark = p.getBoolean("dark", true)
    val ramadan = p.getBoolean("ramadan", false)
    val shuffle = p.getString("shuffle", "day") ?: "day"        // day | launch | manual
    private val strings: JSONObject = try {
        JSONObject(p.getString("strings", "{}") ?: "{}")
    } catch (e: Exception) { JSONObject() }

    val rtl: Boolean get() = lang == "ar" || lang == "ur"
    val strideKm: Float get() = strideCm / 100000f

    fun s(key: String, def: String): String {
        val v = strings.optString(key, "")
        return if (v.isEmpty()) def else v
    }

    companion object {
        const val FILE = "hc_step_card"
        /** Reads a number whatever numeric type Dart happened to send. */
        fun num(p: SharedPreferences, key: String, def: Float): Float = when (val v = p.all[key]) {
            is Float -> v
            is Int -> v.toFloat()
            is Long -> v.toFloat()
            is Double -> v.toFloat()
            else -> def
        }
        fun load(ctx: Context): CardConfig =
            CardConfig(ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE))
    }
}

class Pal(
    val name: String,
    val bgTop: Int, val bgBottom: Int,
    val glow1: Int, val glow2: Int,
    val accent: Int, val accent2: Int,
    val text: Int, val sub: Int,
    val track: Int, val chip: Int, val plate: Int,
    val border: Int, val spark: Int,
    val light: Boolean
)

object Palettes {
    private fun c(hex: Long) = hex.toInt()

    val GREEN = Pal("green",
        c(0xFF06201A), c(0xFF0F4030), c(0xFF3FB950), c(0xFF78E08E),
        c(0xFF3FD07A), c(0xFF9CF2B8), c(0xFFFFFFFF), c(0xB8E3F4E9),
        c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF0B2A20), c(0x40A7F3C4), c(0xFFD8FFE6), false)

    val WHITE = Pal("white",
        c(0xFFFFFFFF), c(0xFFE6F4E9), c(0xFF9BE3B0), c(0xFFD4F5DD),
        c(0xFF1F9D4A), c(0xFF52D17C), c(0xFF10241A), c(0xFF5C6B62),
        c(0x1F10241A), c(0x14238636), c(0xFFFFFFFF), c(0x33238636), c(0xFF52D17C), true)

    val RAMADAN = Pal("ramadan",
        c(0xFF0B0919), c(0xFF241A52), c(0xFF6B4FD8), c(0xFFE8B84B),
        c(0xFFE8B84B), c(0xFFF6DD94), c(0xFFF3ECD6), c(0xB8D9C79B),
        c(0x33E8B84B), c(0x22E8B84B), c(0xFF150F2C), c(0x55E8B84B), c(0xFFFFE9A8), false)

    private val POOL = listOf(
        Pal("ocean",
            c(0xFF061B2E), c(0xFF0B3A5C), c(0xFF2F8CFF), c(0xFF6FB3FF),
            c(0xFF6FB3FF), c(0xFFB5DBFF), c(0xFFFFFFFF), c(0xB8D6E8FA),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF081F33), c(0x406FB3FF), c(0xFFD6EBFF), false),
        Pal("violet",
            c(0xFF14082B), c(0xFF2E1A5C), c(0xFF7B4DFF), c(0xFFBC8CFF),
            c(0xFFBC8CFF), c(0xFFE3CFFF), c(0xFFFFFFFF), c(0xB8E6DAF8),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF180B33), c(0x40BC8CFF), c(0xFFEBDDFF), false),
        Pal("sunset",
            c(0xFF2B0B12), c(0xFF5C2230), c(0xFFFF6B4A), c(0xFFFFB36B),
            c(0xFFFF8A5B), c(0xFFFFC796), c(0xFFFFFFFF), c(0xB8F8DCD2),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF30101A), c(0x40FF8A5B), c(0xFFFFE0CC), false),
        Pal("gold",
            c(0xFF1F1606), c(0xFF40300D), c(0xFFDBA75D), c(0xFFF0CF98),
            c(0xFFDBA75D), c(0xFFF4DBA8), c(0xFFFFF6E3), c(0xB8EAD9B4),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF261B08), c(0x40DBA75D), c(0xFFFFEFC9), false),
        Pal("rose",
            c(0xFF2A0A1E), c(0xFF55203F), c(0xFFFF5C9A), c(0xFFFFA3C7),
            c(0xFFFF7BAC), c(0xFFFFC0D8), c(0xFFFFFFFF), c(0xB8F5D7E4),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF300E24), c(0x40FF7BAC), c(0xFFFFD9E8), false),
        Pal("aurora",
            c(0xFF04161F), c(0xFF0C3F3C), c(0xFF22D3BE), c(0xFF8CF0E0),
            c(0xFF5EEAD4), c(0xFFB2F6EA), c(0xFFFFFFFF), c(0xB8D3F2EC),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF062229), c(0x405EEAD4), c(0xFFD4FBF3), false),
        Pal("sky",
            c(0xFFF5FAFF), c(0xFFD9ECFF), c(0xFF8EC5FF), c(0xFFCBE4FF),
            c(0xFF1E7BE0), c(0xFF5AA9FF), c(0xFF0E2238), c(0xFF55677C),
            c(0x1F0E2238), c(0x141E7BE0), c(0xFFFFFFFF), c(0x331E7BE0), c(0xFF5AA9FF), true),
        Pal("blush",
            c(0xFFFFF8FA), c(0xFFFFE1EB), c(0xFFFFA9C6), c(0xFFFFD3E2),
            c(0xFFD81B60), c(0xFFFF6FA0), c(0xFF3A0F20), c(0xFF7A5463),
            c(0x1F3A0F20), c(0x14D81B60), c(0xFFFFFFFF), c(0x33D81B60), c(0xFFFF6FA0), true)
    )

    fun poolSize() = POOL.size

    // name -> (dark-card pair, light-card pair)
    private val ACCENTS: Map<String, Pair<IntArray, IntArray>> = mapOf(
        "mint" to Pair(intArrayOf(c(0xFF5EEAD4), c(0xFFB2F6EA)), intArrayOf(c(0xFF0E9F8A), c(0xFF3CCFB8))),
        "gold" to Pair(intArrayOf(c(0xFFDBA75D), c(0xFFF4DBA8)), intArrayOf(c(0xFFB27A1C), c(0xFFE0A94C))),
        "ocean" to Pair(intArrayOf(c(0xFF6FB3FF), c(0xFFB5DBFF)), intArrayOf(c(0xFF1E7BE0), c(0xFF5AA9FF))),
        "violet" to Pair(intArrayOf(c(0xFFBC8CFF), c(0xFFE3CFFF)), intArrayOf(c(0xFF7B3FE4), c(0xFFA878FF))),
        "rose" to Pair(intArrayOf(c(0xFFFF7BAC), c(0xFFFFC0D8)), intArrayOf(c(0xFFD81B60), c(0xFFFF6FA0))),
        "sunset" to Pair(intArrayOf(c(0xFFFF8A5B), c(0xFFFFC796)), intArrayOf(c(0xFFE0561F), c(0xFFFF9A63)))
    )

    private fun recolor(base: Pal, accentKey: String): Pal {
        val pair = ACCENTS[accentKey] ?: return base
        val a = if (base.light) pair.second else pair.first
        return Pal(base.name + "-" + accentKey,
            base.bgTop, base.bgBottom, a[0], a[1], a[0], a[1],
            base.text, base.sub, base.track, base.chip, base.plate, base.border, a[1], base.light)
    }

    fun resolve(cfg: CardConfig, randIdx: Int): Pal {
        val base: Pal = when (cfg.theme) {
            "white" -> WHITE
            "random" -> POOL[((randIdx % POOL.size) + POOL.size) % POOL.size]
            "auto" -> if (cfg.ramadan) RAMADAN else if (cfg.dark) GREEN else WHITE
            else -> GREEN
        }
        // The accent override only applies to the two house themes.
        return if (cfg.theme == "green" || cfg.theme == "white" || cfg.theme == "auto")
            recolor(base, cfg.accent) else base
    }

    fun withAlpha(color: Int, a: Float): Int =
        Color.argb((Color.alpha(color) * a.coerceIn(0f, 1f)).toInt(),
            Color.red(color), Color.green(color), Color.blue(color))
}

/** Today's steps, persisted so the card survives the app (and the service) being killed. */
object StepState {
    private const val FILE = "hc_step_state"
    private lateinit var sp: SharedPreferences
    private var ready = false
    private var lastPersist = 0L
    private var dirtyEvents = 0

    var day = ""
    var base = 0
    var baseSensor = -1L
    var lastSensor = -1L
    var useDetector = false
    var lastStepAt = 0L
    var celebDay = ""
    var celebAt = 0L
    var randIdx = 0
    var randDay = ""
    var error = ""
    private val hist = LinkedHashMap<String, Int>()

    fun dayKey(cal: Calendar = Calendar.getInstance()): String {
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        return cal.get(Calendar.YEAR).toString() + "-" + (if (m < 10) "0$m" else "$m") + "-" + (if (d < 10) "0$d" else "$d")
    }

    @Synchronized fun init(ctx: Context) {
        if (ready) return
        sp = ctx.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        day = sp.getString("day", "") ?: ""
        base = sp.getInt("base", 0)
        baseSensor = sp.getLong("baseSensor", -1L)
        lastSensor = sp.getLong("lastSensor", -1L)
        lastStepAt = 0L
        celebDay = sp.getString("celebDay", "") ?: ""
        celebAt = sp.getLong("celebAt", 0L)
        randIdx = sp.getInt("randIdx", 0)
        randDay = sp.getString("randDay", "") ?: ""
        error = sp.getString("error", "") ?: ""
        hist.clear()
        (sp.getString("hist", "") ?: "").split(",").forEach {
            val i = it.lastIndexOf(':')
            if (i > 0) {
                val n = it.substring(i + 1).toIntOrNull()
                if (n != null) hist[it.substring(0, i)] = n
            }
        }
        ready = true
        rollIfNeeded()
    }

    @Synchronized fun steps(): Int {
        val delta = if (!useDetector && baseSensor >= 0 && lastSensor >= baseSensor) (lastSensor - baseSensor) else 0L
        return (base + delta).coerceIn(0L, 999999L).toInt()
    }

    /** Rolls to a new day if the date changed. Returns true when it did. */
    @Synchronized fun rollIfNeeded(): Boolean {
        val today = dayKey()
        if (day == today) return false
        if (day.isNotEmpty()) hist[day] = steps()
        day = today
        base = 0
        baseSensor = if (lastSensor >= 0) lastSensor else -1L
        trimHist()
        persist(true)
        return true
    }

    /** A hardware step-counter reading. Returns true when the step total changed. */
    @Synchronized fun onSensor(v: Long): Boolean {
        rollIfNeeded()
        val before = steps()
        if (baseSensor < 0) baseSensor = v
        if (v < baseSensor) baseSensor = 0L          // the counter restarts at boot
        lastSensor = v
        val after = steps()
        if (after != before) {
            lastStepAt = System.currentTimeMillis()
            hist[day] = after
            dirtyEvents++
            persist(false)
        }
        return after != before
    }

    @Synchronized fun onDetector(): Boolean {
        rollIfNeeded()
        useDetector = true
        base += 1
        lastStepAt = System.currentTimeMillis()
        hist[day] = steps()
        dirtyEvents++
        persist(false)
        return true
    }

    /** The app's own number wins: the card must read exactly what the app shows. */
    @Synchronized fun push(n: Int) {
        rollIfNeeded()
        val v = n.coerceIn(0, 999999)
        val before = steps()
        base = v
        baseSensor = if (lastSensor >= 0) lastSensor else -1L
        if (v > before) lastStepAt = System.currentTimeMillis()
        hist[day] = v
        persist(true)
    }

    /** Seeds days the card never saw (from the app database). Never overwrites. */
    @Synchronized fun seedHistory(csv: String) {
        csv.split(",").forEach {
            val i = it.lastIndexOf(':')
            if (i > 0) {
                val k = it.substring(0, i)
                val n = it.substring(i + 1).toIntOrNull()
                if (n != null && k != day && !hist.containsKey(k)) hist[k] = n
            }
        }
        trimHist()
        persist(true)
    }

    /** The last 7 days ending today, oldest first. */
    @Synchronized fun week(): IntArray {
        val out = IntArray(7)
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -6)
        for (i in 0 until 7) {
            val k = dayKey(cal)
            out[i] = if (k == day) steps() else (hist[k] ?: 0)
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return out
    }

    @Synchronized fun markCelebrated(now: Long) {
        celebDay = day
        celebAt = now
        persist(true)
    }

    @Synchronized fun shuffle(poolSize: Int) {
        var n = (Math.random() * poolSize).toInt() % poolSize
        if (n == randIdx) n = (n + 1) % poolSize
        randIdx = n
        randDay = dayKey()
        persist(true)
    }

    @Synchronized fun recordError(e: String) {
        error = e
        persist(true)
    }

    private fun trimHist() {
        while (hist.size > 21) {
            val first = hist.keys.minOrNull() ?: break
            hist.remove(first)
        }
    }

    @Synchronized fun persist(force: Boolean) {
        if (!ready) return
        val now = System.currentTimeMillis()
        if (!force && dirtyEvents < 15 && now - lastPersist < 30000L) return
        dirtyEvents = 0
        lastPersist = now
        val sb = StringBuilder()
        for ((k, v) in hist) { if (sb.isNotEmpty()) sb.append(','); sb.append(k).append(':').append(v) }
        sp.edit()
            .putString("day", day).putInt("base", base)
            .putLong("baseSensor", baseSensor).putLong("lastSensor", lastSensor)
            .putString("celebDay", celebDay).putLong("celebAt", celebAt)
            .putInt("randIdx", randIdx).putString("randDay", randDay)
            .putString("error", error)
            .putString("hist", sb.toString())
            .apply()
    }

    fun narrowDay(offsetFromToday: Int, lang: String): String {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, offsetFromToday)
        return try {
            SimpleDateFormat("EEEEE", Locale(lang)).format(Date(cal.timeInMillis))
        } catch (e: Exception) { "" }
    }
}
