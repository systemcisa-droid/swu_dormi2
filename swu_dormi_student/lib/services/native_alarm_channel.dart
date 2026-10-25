import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 안드로이드 네이티브 AlarmManager.setAlarmClock()을 사용하는 채널.
/// 알림(Notification) 시스템을 거치지 않고 알람 시각에 직접 앱 화면을 띄우므로,
/// 화면이 켜져 있을 때 안드로이드가 대신 띄우는 헤드업 팝업이 생기지 않는다.
class NativeAlarmChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.swu.dormi2/alarm_scheduler',
  );

  /// 성공하면 null, 실패하면 화면에 보여줄 수 있는 에러 메시지를 반환한다.
  static Future<String?> scheduleAlarmClock({
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
      debugPrint(
        '[알람] 예약됨 requestCode=$requestCode alarmId=$alarmId triggerAt=$triggerAt',
      );
      return null;
    } catch (e, st) {
      debugPrint('[알람] scheduleAlarmClock 실패: $e\n$st');
      if (e is PlatformException) {
        return e.message ?? e.code;
      }
      return e.toString();
    }
  }

  static Future<void> cancelAlarm(int requestCode) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {'requestCode': requestCode});
    } catch (e) {
      debugPrint('[알람] cancelAlarm 실패: $e');
    }
  }

  /// 알람 화면으로 바로 실행되어(cold start) 앱이 뜬 경우, 그 알람 정보를 가져온다.
  static Future<Map<String, dynamic>?> getLaunchAlarm() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getLaunchAlarm',
      );
      return result;
    } catch (e) {
      debugPrint('[알람] getLaunchAlarm 실패: $e');
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

  /// 안드로이드 시스템 알람음 선택창(RingtoneManager)을 띄운다.
  /// 반환값: (선택 결과 {uri, title}(취소 시 null), 실패 시 에러 메시지).
  static Future<(Map<String, String>?, String?)> pickSystemRingtone({
    String? currentUri,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'pickSystemRingtone',
        {'currentUri': currentUri},
      );
      if (result == null) return (null, null);
      return (
        {
          'uri': result['uri'] as String,
          'title': result['title'] as String? ?? '',
        },
        null,
      );
    } catch (e) {
      debugPrint('[알람] pickSystemRingtone 실패: $e');
      final message = e is PlatformException ? (e.message ?? e.code) : e.toString();
      return (null, message);
    }
  }

  /// 기기(안드로이드)에서 사용자가 지금 쓰고 있는 전화 벨소리를 가져온다.
  /// 실패하거나 안드로이드가 아니면 null.
  static Future<Map<String, String>?> getDefaultSystemRingtone() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getDefaultSystemRingtone',
      );
      if (result == null) return null;
      return {
        'uri': result['uri'] as String,
        'title': result['title'] as String? ?? '',
      };
    } catch (e) {
      debugPrint('[알람] getDefaultSystemRingtone 실패: $e');
      return null;
    }
  }

  static Future<void> playSystemRingtoneLoop(String uri) async {
    try {
      await _channel.invokeMethod('playSystemRingtoneLoop', {'uri': uri});
    } catch (e) {
      debugPrint('[알람] playSystemRingtoneLoop 실패: $e');
    }
  }

  static Future<void> stopSystemRingtoneLoop() async {
    try {
      await _channel.invokeMethod('stopSystemRingtoneLoop');
    } catch (e) {
      debugPrint('[알람] stopSystemRingtoneLoop 실패: $e');
    }
  }
}
