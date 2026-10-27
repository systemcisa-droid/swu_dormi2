package com.swu.dormi2

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/// 기기가 재부팅되면(또는 앱이 업데이트되면) 안드로이드가 예약된 AlarmManager
/// 알람을 전부 지워버린다. 앱을 다시 열면 AlarmService.init()이 알아서 다시
/// 예약해 주지만, 재부팅 이후 앱을 한 번도 안 연 상태에서 알람 시각이 되면
/// 그 전까지는 울리지 않는다. 그래서 재부팅 시 Flutter의 shared_preferences가
/// 저장해 둔 알람 목록을 직접 읽어서(Dart 코드 없이) 다시 예약해 둔다.
class BootAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                try {
                    rescheduleAll(context.applicationContext)
                } catch (e: Exception) {
                    // 복구는 best-effort다: 실패해도 앱을 열면 다시 맞춰진다.
                }
            }
        }
    }

    private fun rescheduleAll(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.student_alarms", null) ?: return
        // shared_preferences 플러그인이 List<String>을 저장할 때 붙이는 식별 접두사.
        // (io.flutter.plugins.sharedpreferences 패키지의 jsonListPrefix와 동일해야 한다.)
        val jsonListPrefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"
        if (!raw.startsWith(jsonListPrefix)) return
        val array = JSONArray(raw.substring(jsonListPrefix.length))

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        for (i in 0 until array.length()) {
            try {
                val alarm = JSONObject(array.getString(i))
                if (!alarm.optBoolean("enabled", true)) continue
                val id = alarm.optInt("id", -1)
                if (id < 0) continue
                val hour = alarm.optInt("hour", 0)
                val minute = alarm.optInt("minute", 0)

                val repeatDaysJson = alarm.optJSONArray("repeatDays")
                val repeatDays = mutableListOf<Int>()
                if (repeatDaysJson != null) {
                    for (j in 0 until repeatDaysJson.length()) {
                        repeatDays.add(repeatDaysJson.getInt(j))
                    }
                }

                if (repeatDays.isEmpty()) {
                    scheduleOne(context, alarmManager, id * 10, nextInstanceOfTime(hour, minute), id, 0)
                } else {
                    for (weekday in repeatDays) {
                        scheduleOne(
                            context,
                            alarmManager,
                            id * 10 + weekday,
                            nextInstanceOfTimeAndWeekday(hour, minute, weekday),
                            id,
                            weekday,
                        )
                    }
                }
            } catch (e: Exception) {
                // 알람 하나가 깨져 있어도 나머지는 계속 예약한다.
            }
        }
    }

    private fun scheduleOne(
        context: Context,
        alarmManager: AlarmManager,
        requestCode: Int,
        triggerAtMillis: Long,
        alarmId: Int,
        weekday: Int,
    ) {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        val showIntent = Intent(context, MainActivity::class.java)
        val showPendingIntent = PendingIntent.getActivity(context, requestCode, showIntent, flags)

        val ringIntent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_ALARM_RING
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(MainActivity.EXTRA_ALARM_ID, alarmId)
            putExtra(MainActivity.EXTRA_SNOOZE_COUNT, 0)
            putExtra(MainActivity.EXTRA_WEEKDAY, weekday)
        }
        val operationPendingIntent = PendingIntent.getActivity(context, requestCode, ringIntent, flags)

        val info = AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent)
        alarmManager.setAlarmClock(info, operationPendingIntent)
    }

    private fun nextInstanceOfTime(hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val nowMillis = now.timeInMillis
        now.set(Calendar.HOUR_OF_DAY, hour)
        now.set(Calendar.MINUTE, minute)
        now.set(Calendar.SECOND, 0)
        now.set(Calendar.MILLISECOND, 0)
        if (now.timeInMillis <= nowMillis) {
            now.add(Calendar.DAY_OF_YEAR, 1)
        }
        return now.timeInMillis
    }

    /// weekday: Dart DateTime.weekday 기준(1=월 ... 7=일).
    private fun nextInstanceOfTimeAndWeekday(hour: Int, minute: Int, weekday: Int): Long {
        val cal = Calendar.getInstance()
        cal.timeInMillis = nextInstanceOfTime(hour, minute)
        while (dartWeekday(cal) != weekday) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return cal.timeInMillis
    }

    private fun dartWeekday(cal: Calendar): Int {
        // Calendar.DAY_OF_WEEK: 일=1, 월=2 ... 토=7 → Dart: 월=1 ... 일=7
        val c = cal.get(Calendar.DAY_OF_WEEK)
        return if (c == Calendar.SUNDAY) 7 else c - 1
    }
}
