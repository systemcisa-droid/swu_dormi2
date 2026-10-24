import 'package:flutter/services.dart';

/// 안드로이드 네이티브 AlarmManager.setAlarmClock()을 사용하는 채널.
/// 알림(Notification) 시스템을 거치지 않고 알람 시각에 직접 앱 화면을 띄우므로,
/// 화면이 켜져 있을 때 안드로이드가 대신 띄우는 헤드업 팝업이 생기지 않는다.
class NativeAlarmChannel {
  static const MethodChannel _channel = MethodChannel('com.swu.dormi2/alarm_scheduler');

  static Future<void> scheduleAlarmClock({
    required int requestCode,
    required DateTime triggerAt,
    required int alarmId,
    required int snoozeCount,
    required int weekday,
  }) async {
    try {
      await _channel.invokeMethod('scheduleAlarmClock', {
        'requestCode': requestCode,
        'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
        'alarmId': alarmId,
        'snoozeCount': snoozeCount,
        'weekday': weekday,
      });
    } catch (_) {}
  }

  static Future<void> cancelAlarm(int requestCode) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {'requestCode': requestCode});
    } catch (_) {}
  }

  /// 알람 화면으로 바로 실행되어(cold start) 앱이 뜬 경우, 그 알람 정보를 가져온다.
  static Future<Map<String, dynamic>?> getLaunchAlarm() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getLaunchAlarm');
      return result;
    } catch (_) {
      return null;
    }
  }

  /// 앱이 이미 떠 있는 상태(warm)에서 알람이 울려 액티비티가 다시 포그라운드로
  /// 올라온 경우 호출된다.
  static void setRingHandler(
    Future<void> Function(int alarmId, int snoozeCount, int weekday) handler,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmRing') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        await handler(
          args['alarmId'] as int,
          args['snoozeCount'] as int,
          args['weekday'] as int,
        );
      }
    });
  }
}
