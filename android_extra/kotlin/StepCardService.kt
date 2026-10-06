package com.ihsanstudio.halalcalorie

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import android.widget.RemoteViews

// ─────────────────────────────────────────────────────────────
//  StepCardService.kt — HalalCalorie v59 (PATCH_V59_STEPCARD)
//  The live step card: a foreground service that counts steps with
//  the hardware sensor and keeps an animated card in the shade.
//  Animation only runs while the screen is on.
// ─────────────────────────────────────────────────────────────

class StepCardService : Service(), SensorEventListener {

    companion object {
        const val ACTION_START = "com.ihsanstudio.halalcalorie.STEPCARD_START"
        const val ACTION_STOP = "com.ihsanstudio.halalcalorie.STEPCARD_STOP"
        const val ACTION_REFRESH = "com.ihsanstudio.halalcalorie.STEPCARD_REFRESH"
        const val ACTION_DISMISSED = "com.ihsanstudio.halalcalorie.STEPCARD_DISMISSED"
        const val NOTIF_ID = 4201
        const val GOAL_ID = 4202
        const val CH_LOW = "hc_step_card_low"
        const val CH_MIN = "hc_step_card_min"
        const val CH_GOAL = "hc_step_goal"

        @Volatile var running = false
        @Volatile var instance: StepCardService? = null

        fun hasActivityPermission(ctx: Context): Boolean =
            Build.VERSION.SDK_INT < 29 ||
                ctx.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

        fun start(ctx: Context) {
            val i = Intent(ctx, StepCardService::class.java).setAction(ACTION_START)
            try {
                if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
            } catch (e: Exception) {
                StepState.init(ctx)
                StepState.recordError("start: " + e.javaClass.simpleName)
            }
        }

        fun stop(ctx: Context) {
            val i = instance
            if (i != null) i.shutDown()
            else try { ctx.stopService(Intent(ctx, StepCardService::class.java)) } catch (e: Exception) {}
        }

        fun refresh(ctx: Context) {
            val i = instance ?: return
            i.reload()
        }
    }

    private lateinit var thread: HandlerThread
    private lateinit var bg: Handler
    private lateinit var nm: NotificationManager
    private lateinit var sm: SensorManager
    private lateinit var renderer: StepCardRenderer
    private lateinit var cfg: CardConfig
    private var smallBmp: Bitmap? = null
    private var bigBmp: Bitmap? = null
    private var shown = 0f
    private var startNs = System.nanoTime()
    private var screenOn = true
    private var dismissed = false
    private var registered = false
    private var lastPosted = 0L

    private val ticker = object : Runnable {
        override fun run() {
            frame()
            val ms = frameInterval()
            if (ms > 0 && screenOn && !dismissed) bg.postDelayed(this, ms)
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> { screenOn = false; bg.removeCallbacks(ticker); bg.post { frame() } }
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> { screenOn = true; kick() }
            }
        }
    }

    private val dismissReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            // The user swiped the card away: respect it until the app is opened again.
            dismissed = true
            bg.removeCallbacks(ticker)
        }
    }

    // ── lifecycle ─────────────────────────────────────────────
    override fun onCreate() {
        super.onCreate()
        instance = this
        thread = HandlerThread("hc-step-card").also { it.start() }
        bg = Handler(thread.looper)
        nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        StepState.init(applicationContext)
        cfg = CardConfig.load(this)
        renderer = StepCardRenderer(applicationContext)
        createChannels()
        screenOn = (getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
        val f = IntentFilter()
        f.addAction(Intent.ACTION_SCREEN_ON)
        f.addAction(Intent.ACTION_SCREEN_OFF)
        f.addAction(Intent.ACTION_USER_PRESENT)
        registerReceiver(screenReceiver, f)
        val d = IntentFilter(ACTION_DISMISSED)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(dismissReceiver, d, Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(dismissReceiver, d)
        if (cfg.theme == "random" && cfg.shuffle == "launch") StepState.shuffle(Palettes.poolSize())
        shown = StepState.steps().toFloat()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { shutDown(); return START_NOT_STICKY }
        cfg = CardConfig.load(this)
        if (!cfg.enabled || !hasActivityPermission(this)) {
            // Must still satisfy startForeground when started via startForegroundService.
            try { promote(buildNotification(true)) } catch (e: Exception) {}
            shutDown()
            return START_NOT_STICKY
        }
        dismissed = false
        StepState.rollIfNeeded()
        try {
            promote(buildNotification(true))
            StepState.recordError("")
        } catch (e: Exception) {
            StepState.recordError("fgs: " + e.javaClass.simpleName)
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        registerSensor()
        kick()
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        instance = null
        try { sm.unregisterListener(this) } catch (e: Exception) {}
        try { unregisterReceiver(screenReceiver) } catch (e: Exception) {}
        try { unregisterReceiver(dismissReceiver) } catch (e: Exception) {}
        StepState.persist(true)
        bg.removeCallbacksAndMessages(null)
        thread.quitSafely()
        super.onDestroy()
    }

    fun shutDown() {
        running = false
        try { bg.removeCallbacksAndMessages(null) } catch (e: Exception) {}
        try { stopForeground(true) } catch (e: Exception) {}
        try { nm.cancel(NOTIF_ID) } catch (e: Exception) {}
        stopSelf()
    }

    /** Called when the app changed a setting or pushed new steps. */
    fun reload() {
        bg.post {
            cfg = CardConfig.load(this)
            if (!cfg.enabled) { shutDown(); return@post }
            dismissed = false
            if (cfg.theme == "random" && cfg.shuffle == "day" && StepState.randDay != StepState.dayKey()) {
                StepState.shuffle(Palettes.poolSize())
            }
            kick()
        }
    }

    fun onPushed() { bg.post { frame() } }

    // ── sensor ────────────────────────────────────────────────
    private fun registerSensor() {
        if (registered) return
        var s = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        var detector = false
        if (s == null) { s = sm.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR); detector = true }
        if (s == null) return
        StepState.useDetector = detector
        registered = try { sm.registerListener(this, s, SensorManager.SENSOR_DELAY_NORMAL, 0, bg) } catch (e: Exception) { false }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onSensorChanged(e: SensorEvent) {
        val changed = if (e.sensor.type == Sensor.TYPE_STEP_COUNTER) StepState.onSensor(e.values[0].toLong())
                      else StepState.onDetector()
        if (changed) {
            checkGoal()
            // With animation off (or the screen off) a step is the only reason to repaint.
            if (!screenOn || frameInterval() <= 0L) frame() else if (!dismissed) { bg.removeCallbacks(ticker); bg.post(ticker) }
        }
    }

    // ── frames ────────────────────────────────────────────────
    private fun reducedMotion(): Boolean = try {
        Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    } catch (e: Exception) { false }

    private fun animLevel(): Int = if (reducedMotion() || !screenOn) 0 else cfg.anim

    private fun frameInterval(): Long = when (animLevel()) { 1 -> 1000L; 2 -> 500L; 3 -> 340L; else -> 0L }

    private fun kick() {
        bg.removeCallbacks(ticker)
        bg.post(ticker)
    }

    private fun checkGoal() {
        val steps = StepState.steps()
        if (steps >= cfg.goal && StepState.celebDay != StepState.dayKey()) {
            StepState.markCelebrated(System.currentTimeMillis())
            if (cfg.celebrate) postGoalNotification(steps)
        }
    }

    private fun buildState(): RenderState {
        val steps = StepState.steps()
        val level = animLevel()
        // count up towards the real number instead of jumping
        shown = if (level == 0 || Math.abs(steps - shown) < 1f) steps.toFloat() else shown + (steps - shown) * 0.35f
        val now = System.currentTimeMillis()
        val sinceStep = if (StepState.lastStepAt == 0L) 99999L else now - StepState.lastStepAt
        val sinceCeleb = if (StepState.celebDay == StepState.dayKey()) now - StepState.celebAt else 99999L
        val t = (System.nanoTime() - startNs) / 1_000_000_000f
        return StepRenderHelper.state(cfg, StepState.randIdx, shown, steps, t, sinceStep, sinceCeleb, StepState.week(), level)
    }

    private fun frame() {
        if (dismissed || !running) return
        try {
            if (StepState.rollIfNeeded()) shown = 0f
            if (cfg.theme == "random" && cfg.shuffle == "day" && StepState.randDay != StepState.dayKey()) {
                StepState.shuffle(Palettes.poolSize())
            }
            nm.notify(NOTIF_ID, buildNotification(false))
        } catch (e: Exception) { /* a dropped frame is fine */ }
    }

    private fun promote(n: Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            // FOREGROUND_SERVICE_TYPE_HEALTH
            startForeground(NOTIF_ID, n, 0x00000100)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    // ── notification ──────────────────────────────────────────
    private fun createChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        val low = NotificationChannel(CH_LOW, "HalalCalorie · Step card", NotificationManager.IMPORTANCE_LOW)
        low.setShowBadge(false)
        low.description = "Live step counter"
        val min = NotificationChannel(CH_MIN, "HalalCalorie · Step card (no status-bar icon)", NotificationManager.IMPORTANCE_MIN)
        min.setShowBadge(false)
        val goal = NotificationChannel(CH_GOAL, "HalalCalorie · Daily goal", NotificationManager.IMPORTANCE_DEFAULT)
        goal.enableVibration(true)
        nm.createNotificationChannel(low)
        nm.createNotificationChannel(min)
        nm.createNotificationChannel(goal)
    }

    private fun res(name: String, type: String): Int = resources.getIdentifier(name, type, packageName)

    private fun contentIntent(): PendingIntent {
        val i = Intent(this, MainActivity::class.java)
        i.putExtra("hc_route", "/health")
        i.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getActivity(this, 7, i, flags)
    }

    private fun deleteIntent(): PendingIntent {
        val i = Intent(ACTION_DISMISSED).setPackage(packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getBroadcast(this, 8, i, flags)
    }

    private fun views(layout: String, bmp: Bitmap, desc: String): RemoteViews {
        val rv = RemoteViews(packageName, res(layout, "layout"))
        val id = res("hc_card_img", "id")
        rv.setImageViewBitmap(id, bmp)
        rv.setContentDescription(id, desc)
        return rv
    }

    private val lock = Any()

    private fun buildNotification(first: Boolean): Notification = synchronized(lock) {
        val state = buildState()
        smallBmp = renderer.render(false, state, smallBmp)
        bigBmp = renderer.render(true, state, bigBmp)
        val desc = renderer.describe(state)
        val small = views("hc_step_card_small", smallBmp!!, desc)
        val big = views("hc_step_card_big", bigBmp!!, desc)

        val channel = if (cfg.statusIcon) CH_LOW else CH_MIN
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else Notification.Builder(this)
        val icon = res("ic_stat_halal", "drawable")
        b.setSmallIcon(if (icon != 0) icon else android.R.drawable.ic_menu_compass)
        b.setCustomContentView(small)
        b.setCustomBigContentView(big)
        b.setStyle(Notification.DecoratedCustomViewStyle())
        b.setContentIntent(contentIntent())
        b.setDeleteIntent(deleteIntent())
        b.setOngoing(true)
        b.setOnlyAlertOnce(true)
        b.setShowWhen(false)
        b.setLocalOnly(true)
        b.setColor(state.pal.accent)
        b.setCategory(Notification.CATEGORY_STATUS)
        b.setVisibility(if (cfg.lock == "hide") Notification.VISIBILITY_SECRET else Notification.VISIBILITY_PUBLIC)
        if (Build.VERSION.SDK_INT < 26) b.setPriority(if (cfg.statusIcon) Notification.PRIORITY_LOW else Notification.PRIORITY_MIN)
        if (Build.VERSION.SDK_INT >= 31) b.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        b.build()
    }

    private fun postGoalNotification(steps: Int) {
        try {
            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CH_GOAL) else Notification.Builder(this)
            val icon = res("ic_stat_halal", "drawable")
            b.setSmallIcon(if (icon != 0) icon else android.R.drawable.ic_menu_compass)
            b.setContentTitle(cfg.s("celebTitle", "Goal reached!"))
            b.setContentText(cfg.s("celebBody", "{n} steps today — well done").replace("{n}", String.format(java.util.Locale.US, "%,d", steps)))
            b.setContentIntent(contentIntent())
            b.setAutoCancel(true)
            b.setColor(Palettes.resolve(cfg, StepState.randIdx).accent)
            b.setTimeoutAfter(6L * 60L * 60L * 1000L)
            if (Build.VERSION.SDK_INT < 26) b.setPriority(Notification.PRIORITY_DEFAULT)
            nm.notify(GOAL_ID, b.build())
        } catch (e: Exception) {}
    }

    /** Posts the goal notification on demand (the settings "test" button). */
    fun testGoal() {
        bg.post {
            StepState.markCelebrated(System.currentTimeMillis())
            postGoalNotification(cfg.goal)
            kick()
        }
    }
}

/** Keeps the RenderState construction in one place for the service and the in-app preview. */
object StepRenderHelper {
    fun state(cfg: CardConfig, randIdx: Int, shown: Float, steps: Int, t: Float,
              sinceStepMs: Long, sinceCelebMs: Long, week: IntArray, anim: Int): RenderState =
        RenderState(cfg, Palettes.resolve(cfg, randIdx), shown, steps, t, sinceStepMs, sinceCelebMs, week, anim)
}
