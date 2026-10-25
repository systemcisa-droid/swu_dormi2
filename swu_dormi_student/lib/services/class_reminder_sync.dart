import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/alarm_model.dart';
import 'alarm_service.dart';
import 'native_alarm_channel.dart';

/// 시간표의 수업마다 선택된 사전 알림(5/10/20분 전)을 자동으로 만들고 동기화한다.
/// 시간표가 바뀔 때마다 다시 호출하면, 없어졌거나 체크 해제된 알람은 지우고
/// 남아있는 알람은 시간/이름이 바뀐 경우에만 갱신한다. (사용자가 직접 만든
/// 미션알람에는 영향을 주지 않는다.)
class ClassReminderSync {
  // 사용자가 직접 만드는 알람 id(0~99999 범위)와 겹치지 않도록 분리된 영역.
  static const int _idRangeStart = 300000;

  /// (classId, offset) 조합마다 고유한 id를 만든다. offset은 5/10/20분 중 하나.
  static int _idFor(String classId, int offset) =>
      _idRangeStart + (('$classId:$offset').hashCode.abs() % 90000);

  static Future<void> sync(
    List<
      ({
        String id,
        String title,
        int dayIndex,
        int startHour,
        int startMinute,
        Set<int> reminderOffsets,
      })
    >
    classes,
  ) async {
    try {
      final service = AlarmService();
      final alarms = await service.loadAlarms();
      final autoAlarms = {
        for (final a in alarms)
          if (a.sourceClassId != null) a.sourceClassId!: a,
      };

      // 지금 있어야 할 (sourceClassId) 집합 = "classId:offset" 문자열.
      final desiredKeys = {
        for (final c in classes)
          for (final offset in c.reminderOffsets) '${c.id}:$offset',
      };

      // 더 이상 없거나 체크 해제된 알람은 지운다.
      for (final entry in autoAlarms.entries) {
        if (!desiredKeys.contains(entry.key)) {
          await service.deleteAlarm(entry.value.id);
        }
      }

      // 새로 만들 알람이 있을 때만, 사용자가 지금 쓰고 있는 전화 벨소리를 한 번 가져온다.
      final hasNewReminder = desiredKeys.any((k) => !autoAlarms.containsKey(k));
      Map<String, String>? defaultSound;
      if (hasNewReminder && Platform.isAndroid) {
        defaultSound = await NativeAlarmChannel.getDefaultSystemRingtone();
      }

      // 선택된 사전 알림마다 알람을 만들거나(시간/이름이 바뀌었으면) 갱신한다.
      for (final c in classes) {
        for (final offset in c.reminderOffsets) {
          var hour = c.startHour;
          var minute = c.startMinute - offset;
          if (minute < 0) {
            minute += 60;
            hour -= 1;
            if (hour < 0) hour += 24;
          }
          final weekday = c.dayIndex + 1; // dayIndex 0=월 → DateTime.weekday 1=월
          final label = '${c.title} 수업 $offset분 전';
          final key = '${c.id}:$offset';
          final existing = autoAlarms[key];

          if (existing != null) {
            final sameSchedule =
                existing.hour == hour &&
                existing.minute == minute &&
                existing.label == label &&
                existing.repeatDays.length == 1 &&
                existing.repeatDays.contains(weekday);
            if (!sameSchedule) {
              await service.addOrUpdateAlarm(
                existing.copyWith(
                  label: label,
                  hour: hour,
                  minute: minute,
                  repeatDays: {weekday},
                ),
              );
            }
          } else {
            await service.addOrUpdateAlarm(
              AlarmModel(
                id: _idFor(c.id, offset),
                label: label,
                hour: hour,
                minute: minute,
                enabled: true,
                repeatDays: {weekday},
                sourceClassId: key,
                soundUri: defaultSound?['uri'],
                soundTitle: defaultSound?['title'],
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[수업 알림] 동기화 실패: $e');
    }
  }
}
