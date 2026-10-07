package com.ihsanstudio.halalcalorie

import android.app.Activity
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors

// ─────────────────────────────────────────────────────────────
//  StepCardBridge.kt — HalalCalorie v59 (PATCH_V59_STEPCARD)
//  Dart <-> native. The in-app preview asks the very same renderer
//  that draws the notification for frames, so what you tune is what
//  you get in the shade.
// ─────────────────────────────────────────────────────────────

object StepCardBridge {
    private const val CHANNEL = "hc/stepcard"
    private var channel: MethodChannel? = null
    private var pendingRoute: String? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var previewRenderer: StepCardRenderer? = null
    private var previewBmp: Bitmap? = null

    fun register(activity: Activity, messenger: BinaryMessenger) {
        val ctx = activity.applicationContext
        StepState.init(ctx)
        val ch = MethodChannel(messenger, CHANNEL)
        channel = ch
        captureIntent(activity.intent)
        ch.setMethodCallHandler { call, result -> handle(activity, ctx, call, result) }
    }

    fun captureIntent(intent: Intent?) {
        val r = intent?.getStringExtra("hc_route") ?: return
        pendingRoute = r
        intent.removeExtra("hc_route")
        try { channel?.invokeMethod("route", r) } catch (e: Exception) {}
    }

    private fun handle(activity: Activity, ctx: Context, call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "configure" -> {
                    val map = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val e = ctx.getSharedPreferences(CardConfig.FILE, Context.MODE_PRIVATE).edit()
                    for ((k, v) in map) {
                        val key = k as? String ?: continue
                        when (v) {
                            is Boolean -> e.putBoolean(key, v)
                            is Int -> e.putInt(key, v)
                            is Long -> e.putInt(key, v.toInt())
                            is Double -> e.putFloat(key, v.toFloat())
                            is String -> e.putString(key, v)
                            else -> {}
                        }
                    }
                    e.apply()
                    rawCfg = null // PATCH_V60
                    val cfg = CardConfig.load(ctx)
                    if (cfg.theme == "random" && cfg.shuffle == "day" && StepState.randDay != StepState.dayKey()) {
                        StepState.shuffle(Palettes.poolSize())
                    }
                    StepCardService.refresh(ctx)
                    result.success(true)
                }
                "start" -> {
                    val cfg = CardConfig.load(ctx)
                    if (!StepCardService.hasActivityPermission(ctx)) { result.success(false); return }
                    if (cfg.enabled) StepCardService.start(ctx)
                    result.success(true)
                }
                "stop" -> { StepCardService.stop(ctx); result.success(true) }
                "pushSteps" -> {
                    val n = (call.arguments as? Number)?.toInt() ?: 0
                    StepState.push(n)
                    StepCardService.instance?.onPushed()
                    result.success(true)
                }
                "seedHistory" -> {
                    StepState.seedHistory(call.arguments as? String ?: "")
                    result.success(true)
                }
                "shuffle" -> {
                    StepState.shuffle(Palettes.poolSize())
                    StepCardService.refresh(ctx)
                    result.success(true)
                }
                "testGoal" -> {
                    val s = StepCardService.instance
                    if (s != null) s.testGoal() else StepState.markCelebrated(System.currentTimeMillis())
                    result.success(s != null)
                }
                "status" -> {
                    val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager
                    val sensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null ||
                        sm.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR) != null
                    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val notifOn = if (Build.VERSION.SDK_INT >= 24) nm.areNotificationsEnabled() else true
                    result.success(hashMapOf<String, Any>(
                        "running" to StepCardService.running,
                        "sensor" to sensor,
                        "permission" to StepCardService.hasActivityPermission(ctx),
                        "notifications" to notifOn,
                        "error" to StepState.error,
                        "steps" to StepState.steps()))
                }
                "consumeRoute" -> {
                    val r = pendingRoute
                    pendingRoute = null
                    result.success(r)
                }
                "preview" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val expanded = args["expanded"] as? Boolean ?: true
                    val tMs = (args["t"] as? Number)?.toDouble() ?: 0.0
                    val fake = (args["steps"] as? Number)?.toInt() ?: -1
                    val sinceCeleb = (args["sinceCelebMs"] as? Number)?.toLong() ?: 99999L
                    val sinceStep = (args["sinceStepMs"] as? Number)?.toLong() ?: 99999L
                    io.execute {
                        try {
                            val bytes = renderPreview(ctx, expanded, tMs, fake, sinceCeleb, sinceStep)
                            main.post { result.success(bytes) }
                        } catch (e: Exception) {
                            main.post { result.error("preview", e.toString(), null) }
                        }
                    }
                }
                "previewBoth" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val tMs = (args["t"] as? Number)?.toDouble() ?: 0.0
                    val fake = (args["steps"] as? Number)?.toInt() ?: -1
                    val sinceCeleb = (args["sinceCelebMs"] as? Number)?.toLong() ?: 99999L
                    val sinceStep = (args["sinceStepMs"] as? Number)?.toLong() ?: 99999L
                    io.execute {
                        try {
                            val out = renderPreviewRaw(ctx, tMs, fake, sinceCeleb, sinceStep)
                            main.post { result.success(out) }
                        } catch (e: Exception) {
                            main.post { result.error("preview", e.toString(), null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("stepcard", e.toString(), null)
        }
    }

    @Synchronized
    private fun renderPreview(ctx: Context, expanded: Boolean, tMs: Double, fake: Int,
                              sinceCeleb: Long, sinceStep: Long): ByteArray {
        val r = previewRenderer ?: StepCardRenderer(ctx).also { previewRenderer = it }
        val cfg = CardConfig.load(ctx)
        val steps = if (fake >= 0) fake else StepState.steps()
        val week = StepState.week()
        if (fake >= 0) week[6] = fake
        val anim = if (cfg.anim == 0) 0 else cfg.anim
        val state = StepRenderHelper.state(cfg, StepState.randIdx, steps.toFloat(), steps,
            (tMs / 1000.0).toFloat(), sinceStep, sinceCeleb, week, anim)
        previewBmp = r.render(expanded, state, previewBmp)
        val out = ByteArrayOutputStream()
        previewBmp!!.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }

    // PATCH_V60: raw-pixel preview (no PNG round trip), both cards in one call.
    private var rawCfg: CardConfig? = null
    private var rawSmall: Bitmap? = null
    private var rawBig: Bitmap? = null
    private var rawSmallBytes: ByteArray? = null
    private var rawBigBytes: ByteArray? = null

    private fun pixelsOf(b: Bitmap, reuse: ByteArray?): ByteArray {
        val n = b.byteCount
        val arr = if (reuse != null && reuse.size == n) reuse else ByteArray(n)
        b.copyPixelsToBuffer(ByteBuffer.wrap(arr))
        return arr
    }

    @Synchronized
    private fun renderPreviewRaw(ctx: Context, tMs: Double, fake: Int,
                                 sinceCeleb: Long, sinceStep: Long): HashMap<String, Any> {
        val r = previewRenderer ?: StepCardRenderer(ctx).also { previewRenderer = it }
        val cfg = rawCfg ?: CardConfig.load(ctx).also { rawCfg = it }
        val steps = if (fake >= 0) fake else StepState.steps()
        val week = StepState.week()
        if (fake >= 0) week[6] = fake
        val state = StepRenderHelper.state(cfg, StepState.randIdx, steps.toFloat(), steps,
            (tMs / 1000.0).toFloat(), sinceStep, sinceCeleb, week, cfg.anim)
        val sb = r.render(false, state, rawSmall); rawSmall = sb
        val bb = r.render(true, state, rawBig); rawBig = bb
        rawSmallBytes = pixelsOf(sb, rawSmallBytes)
        rawBigBytes = pixelsOf(bb, rawBigBytes)
        val out = HashMap<String, Any>()
        out["small"] = rawSmallBytes!!
        out["big"] = rawBigBytes!!
        out["sw"] = sb.width; out["sh"] = sb.height
        out["bw"] = bb.width; out["bh"] = bb.height
        return out
    }
}

class StepCardBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            val cfg = CardConfig.load(context)
            if (cfg.enabled && cfg.bootStart && StepCardService.hasActivityPermission(context)) {
                StepCardService.start(context)
            }
        } catch (e: Exception) {}
    }
}
