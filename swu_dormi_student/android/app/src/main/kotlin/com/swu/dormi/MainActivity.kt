package com.swu.dormi2

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeRingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_ALARM_RING) {
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarmClock" -> {
                    val requestCode = call.argument<Int>("requestCode") ?: -1
                    val triggerAtMillis = (call.argument<Number>("triggerAtMillis"))?.toLong() ?: 0L
                    val alarmId = call.argument<Int>("alarmId") ?: -1
                    val snoozeCount = call.argument<Int>("snoozeCount") ?: 0
                    val weekday = call.argument<Int>("weekday") ?: 0
                    scheduleAlarmClock(requestCode, triggerAtMillis, alarmId, snoozeCount, weekday)
                    result.success(null)
                }
                "cancelAlarm" -> {
                    val requestCode = call.argument<Int>("requestCode") ?: -1
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
                else -> result.notImplemented()
            }
        }
    }

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
    }
}
