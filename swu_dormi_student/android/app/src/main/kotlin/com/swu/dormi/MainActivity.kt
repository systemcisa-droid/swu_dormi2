package com.swu.dormi2

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// 알람 기능: 안드로이드 알림(Notification) 시스템을 거치지 않고
/// AlarmManager.setAlarmClock()으로 이 액티비티를 직접 띄운다.
/// 이렇게 하면 화면이 켜져 있을 때 안드로이드가 자동으로 대신 띄우는
/// 헤드업 팝업 없이, 항상 바로 알람 화면(Flutter 쪽 AlarmRingScreen)으로 간다.
class MainActivity : FlutterActivity() {
    private var methodChannel: MethodChannel? = null
    private var pendingAlarmId: Int? = null
    private var pendingSnoozeCount: Int = 0
    private var pendingWeekday: Int = 0
    private var pendingRingtoneResult: MethodChannel.Result? = null
    private var systemRingtonePlayer: MediaPlayer? = null

    private var ringWakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == ACTION_ALARM_RING) {
            wakeScreenForRing()
        }
        consumeRingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_ALARM_RING) {
            wakeScreenForRing()
            val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
            val snoozeCount = intent.getIntExtra(EXTRA_SNOOZE_COUNT, 0)
            val weekday = intent.getIntExtra(EXTRA_WEEKDAY, 0)
            if (alarmId != -1) {
                methodChannel?.invokeMethod(
                    "onAlarmRing",
                    mapOf(
                        "alarmId" to alarmId,
                        "snoozeCount" to snoozeCount,
                        "weekday" to weekday,
                    ),
                )
            }
        }
    }

    private fun consumeRingIntent(intent: Intent?) {
        if (intent?.action == ACTION_ALARM_RING) {
            val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
            pendingAlarmId = if (alarmId != -1) alarmId else null
            pendingSnoozeCount = intent.getIntExtra(EXTRA_SNOOZE_COUNT, 0)
            pendingWeekday = intent.getIntExtra(EXTRA_WEEKDAY, 0)
        }
    }

    /// 매니페스트의 showWhenLocked/turnScreenOn만으로는 일부 기기(특히 제조사
    /// 커스텀 ROM)에서 화면이 꺼진 상태일 때 믿을 수 없이 동작한다. 그래서
    /// 창(window) 플래그를 직접 켜고, Flutter 엔진이 뜨는 동안 기기가 다시
    /// 잠들지 않도록 잠깐 WakeLock도 잡아 둔다.
    private fun wakeScreenForRing() {
        try {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        } catch (e: Exception) {
        }

        try {
            ringWakeLock?.let { if (it.isHeld) it.release() }
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "$CHANNEL_NAME:ring",
            )
            wakeLock.acquire(20_000L)
            ringWakeLock = wakeLock
        } catch (e: Exception) {
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "scheduleAlarmClock" -> {
                        val requestCode = call.argument<Number>("requestCode")?.toInt() ?: -1
                        val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L
                        val alarmId = call.argument<Number>("alarmId")?.toInt() ?: -1
                        val snoozeCount = call.argument<Number>("snoozeCount")?.toInt() ?: 0
                        val weekday = call.argument<Number>("weekday")?.toInt() ?: 0
                        scheduleAlarmClock(requestCode, triggerAtMillis, alarmId, snoozeCount, weekday)
                        result.success(null)
                    }
                    "cancelAlarm" -> {
                        val requestCode = call.argument<Number>("requestCode")?.toInt() ?: -1
                        cancelAlarm(requestCode)
                        result.success(null)
                    }
                    "getLaunchAlarm" -> {
                        val id = pendingAlarmId
                        if (id != null) {
                            result.success(
                                mapOf(
                                    "alarmId" to id,
                                    "snoozeCount" to pendingSnoozeCount,
                                    "weekday" to pendingWeekday,
                                ),
                            )
                            pendingAlarmId = null
                        } else {
                            result.success(null)
                        }
                    }
                    "pickSystemRingtone" -> {
                        if (pendingRingtoneResult != null) {
                            result.error("busy", "이미 선택 창이 열려 있습니다", null)
                        } else {
                            try {
                                openRingtonePicker(call.argument<String>("currentUri"))
                                pendingRingtoneResult = result
                            } catch (e: Exception) {
                                result.error(
                                    "ringtone_picker_error",
                                    "알람음 선택창을 열 수 없습니다: ${e.message}",
                                    e.stackTraceToString(),
                                )
                            }
                        }
                    }
                    "getRingtoneTitle" -> {
                        val uriString = call.argument<String>("uri")
                        result.success(if (uriString != null) ringtoneTitle(uriString) else null)
                    }
                    "getDefaultSystemRingtone" -> {
                        // 알람 전용 기본음이 아니라, 사용자가 지금 쓰고 있는 전화 벨소리를 기본값으로 쓴다.
                        val uri = RingtoneManager.getActualDefaultRingtoneUri(
                            this,
                            RingtoneManager.TYPE_RINGTONE,
                        )
                        if (uri != null) {
                            val uriString = uri.toString()
                            result.success(mapOf("uri" to uriString, "title" to ringtoneTitle(uriString)))
                        } else {
                            result.success(null)
                        }
                    }
                    "playSystemRingtoneLoop" -> {
                        val uriString = call.argument<String>("uri") ?: ""
                        playSystemRingtoneLoop(uriString)
                        result.success(null)
                    }
                    "stopSystemRingtoneLoop" -> {
                        stopSystemRingtoneLoop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("alarm_scheduler_error", e.message, e.stackTraceToString())
            }
        }
    }

    // ───────────── 기기(시스템) 알람음 선택 ─────────────

    private fun openRingtonePicker(currentUriString: String?) {
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(
                RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI,
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
            )
            if (currentUriString != null) {
                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(currentUriString))
            }
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_CODE_RINGTONE_PICKER)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_CODE_RINGTONE_PICKER) return
        val pendingResult = pendingRingtoneResult ?: return
        pendingRingtoneResult = null
        val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        if (uri == null) {
            pendingResult.success(null)
            return
        }
        val uriString = uri.toString()
        pendingResult.success(mapOf("uri" to uriString, "title" to ringtoneTitle(uriString)))
    }

    private fun ringtoneTitle(uriString: String): String? {
        return try {
            RingtoneManager.getRingtone(this, Uri.parse(uriString))?.getTitle(this)
        } catch (e: Exception) {
            null
        }
    }

    private fun playSystemRingtoneLoop(uriString: String) {
        stopSystemRingtoneLoop()
        try {
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setDataSource(this, Uri.parse(uriString))
            player.isLooping = true
            player.setOnPreparedListener { it.start() }
            player.prepareAsync()
            systemRingtonePlayer = player
        } catch (e: Exception) {
            systemRingtonePlayer = null
        }
    }

    private fun stopSystemRingtoneLoop() {
        try {
            systemRingtonePlayer?.stop()
        } catch (e: Exception) {
        }
        systemRingtonePlayer?.release()
        systemRingtonePlayer = null
    }

    override fun onDestroy() {
        stopSystemRingtoneLoop()
        try {
            ringWakeLock?.let { if (it.isHeld) it.release() }
        } catch (e: Exception) {
        }
        ringWakeLock = null
        super.onDestroy()
    }

    // ───────────── 알람 예약(AlarmManager) ─────────────

    private fun scheduleAlarmClock(
        requestCode: Int,
        triggerAtMillis: Long,
        alarmId: Int,
        snoozeCount: Int,
        weekday: Int,
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        // 상태바의 알람 아이콘을 누르면(알람이 울리기 전) 그냥 앱만 연다.
        val showIntent = Intent(this, MainActivity::class.java)
        val showPendingIntent = PendingIntent.getActivity(this, requestCode, showIntent, flags)

        // 실제 알람 시각에 실행되는 인텐트: 알람 울림 화면으로 바로 이동.
        val ringIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_ALARM_RING
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_SNOOZE_COUNT, snoozeCount)
            putExtra(EXTRA_WEEKDAY, weekday)
        }
        val operationPendingIntent = PendingIntent.getActivity(this, requestCode, ringIntent, flags)

        val info = AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent)
        alarmManager.setAlarmClock(info, operationPendingIntent)
    }

    private fun cancelAlarm(requestCode: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val ringIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_ALARM_RING
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getActivity(this, requestCode, ringIntent, flags)
        alarmManager.cancel(pendingIntent)
    }

    companion object {
        const val CHANNEL_NAME = "com.swu.dormi2/alarm_scheduler"
        const val ACTION_ALARM_RING = "com.swu.dormi2.ACTION_ALARM_RING"
        const val EXTRA_ALARM_ID = "alarmId"
        const val EXTRA_SNOOZE_COUNT = "snoozeCount"
        const val EXTRA_WEEKDAY = "weekday"
        const val REQUEST_CODE_RINGTONE_PICKER = 9001
    }
}
