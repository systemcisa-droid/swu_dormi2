import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_model.dart';
import '../utils/navigation_service.dart';
import '../screens/alarm/alarm_ring_screen.dart';
import 'native_alarm_channel.dart';

/// 학생이 직접 등록하는 개인 알람을 저장/예약하는 서비스.
/// 서버/푸시와 무관하게 기기 안에서만 동작한다.
///
/// 안드로이드 알림(Notification) 시스템을 거치지 않고 AlarmManager.setAlarmClock()으로
/// 알람 시각에 앱 화면을 직접 띄운다. 알림을 거치지 않으므로, 화면이 켜져 있을 때
/// 안드로이드가 대신 띄우는 헤드업 팝업도 생기지 않고, 잠금화면에서도 항상 바로
/// 알람 울림 화면(AlarmRingScreen)으로 이동한다.
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  static const _prefsKey = 'student_alarms';
  static const int _snoozeSlot = 9; // 0=1회성, 1~7=요일별, 9=다시 울림용

  bool _initialized = false;

  /// 앱 시작 시 호출. 알람 울림 콜백을 등록하고, 저장된 알람들을 다시
  /// 예약해 둔다(기기 재부팅 등으로 네이티브 알람이 사라졌을 수 있으므로).
  /// 또한 알람 화면으로 바로 실행되어(cold start) 앱이 뜬 경우 울림 화면을 연다.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    NativeAlarmChannel.setRingHandler(_handleRing);

    final alarms = await loadAlarms();
    for (final alarm in alarms.where((a) => a.enabled)) {
      await _reschedule(alarm);
    }

    final launch = await NativeAlarmChannel.getLaunchAlarm();
    if (launch != null) {
      await _handleRing(
        launch['alarmId'] as int,
        launch['snoozeCount'] as int,
        launch['weekday'] as int,
      );
    }
  }

  Future<void> _handleRing(int alarmId, int snoozeCount, int weekday) async {
    final alarms = await loadAlarms();
    AlarmModel? alarm;
    for (final a in alarms) {
      if (a.id == alarmId) {
        alarm = a;
        break;
      }
    }
    final found = alarm;
    if (found == null) return;

    // 반복 요일 알람이면, 다음 주 같은 요일로 바로 다시 예약해 둔다.
    // (setAlarmClock은 1회성이라 OS가 자동으로 반복해주지 않는다.)
    if (weekday > 0 && snoozeCount == 0 && found.enabled) {
      await _scheduleWeekday(found, weekday, addWeek: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AlarmRingScreen(alarm: found, snoozeCount: snoozeCount),
        ),
      );
    });
  }

  Future<List<AlarmModel>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    final alarms = raw
        .map((s) => AlarmModel.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    alarms.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return alarms;
  }

  Future<void> _saveAlarms(List<AlarmModel> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      alarms.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  int generateId() => DateTime.now().millisecondsSinceEpoch % 100000;

  /// 반환값: (갱신된 알람 목록, 네이티브 예약 실패 시 에러 메시지(성공하면 null)).
  Future<(List<AlarmModel>, String?)> addOrUpdateAlarm(AlarmModel alarm) async {
    final alarms = await loadAlarms();
    final idx = alarms.indexWhere((a) => a.id == alarm.id);
    if (idx >= 0) {
      alarms[idx] = alarm;
    } else {
      alarms.add(alarm);
    }
    await _saveAlarms(alarms);
    final error = await _reschedule(alarm);
    return (await loadAlarms(), error);
  }

  Future<List<AlarmModel>> deleteAlarm(int id) async {
    final alarms = await loadAlarms();
    alarms.removeWhere((a) => a.id == id);
    await _saveAlarms(alarms);
    await _cancelAll(id);
    return alarms;
  }

  Future<(List<AlarmModel>, String?)> setEnabled(int id, bool enabled) async {
    final alarms = await loadAlarms();
    final idx = alarms.indexWhere((a) => a.id == id);
    if (idx < 0) return (alarms, null);
    alarms[idx] = alarms[idx].copyWith(enabled: enabled);
    await _saveAlarms(alarms);
    String? error;
    if (enabled) {
      error = await _reschedule(alarms[idx]);
    } else {
      await _cancelAll(id);
    }
    return (alarms, error);
  }

  Future<void> _cancelAll(int id) async {
    await NativeAlarmChannel.cancelAlarm(id * 10);
    for (var weekday = 1; weekday <= 7; weekday++) {
      await NativeAlarmChannel.cancelAlarm(id * 10 + weekday);
    }
    await NativeAlarmChannel.cancelAlarm(id * 10 + _snoozeSlot);
  }

  /// 성공하면 null, 실패하면 에러 메시지를 반환한다(요일별로 여러 건 예약하는
  /// 경우 처음 실패한 건의 메시지).
  Future<String?> _reschedule(AlarmModel alarm) async {
    await _cancelAll(alarm.id);
    if (!alarm.enabled) return null;

    if (alarm.repeatDays.isEmpty) {
      return NativeAlarmChannel.scheduleAlarmClock(
        requestCode: alarm.id * 10,
        triggerAt: _nextInstanceOfTime(alarm.hour, alarm.minute),
        alarmId: alarm.id,
        snoozeCount: 0,
        weekday: 0,
      );
    } else {
      String? firstError;
      for (final weekday in alarm.repeatDays) {
        final error = await _scheduleWeekday(alarm, weekday, addWeek: false);
        firstError ??= error;
      }
      return firstError;
    }
  }

  Future<String?> _scheduleWeekday(AlarmModel alarm, int weekday, {required bool addWeek}) async {
    var when = _nextInstanceOfTimeAndWeekday(alarm.hour, alarm.minute, weekday);
    if (addWeek) when = when.add(const Duration(days: 7));
    return NativeAlarmChannel.scheduleAlarmClock(
      requestCode: alarm.id * 10 + weekday,
      triggerAt: when,
      alarmId: alarm.id,
      snoozeCount: 0,
      weekday: weekday,
    );
  }

  /// "다시 울림"(스누즈). 같은 알람을 설정된 분 뒤에 한 번 더 울린다.
  /// [nextSnoozeCount]는 이번이 몇 번째 다시 울림인지(1부터)를 나타내며,
  /// 다음 울림 화면에서 반복 횟수 제한을 판단하는 데 쓰인다.
  Future<void> scheduleSnooze(AlarmModel alarm, int nextSnoozeCount) async {
    final when = DateTime.now().add(Duration(minutes: alarm.snoozeMinutes));
    await NativeAlarmChannel.scheduleAlarmClock(
      requestCode: alarm.id * 10 + _snoozeSlot,
      triggerAt: when,
      alarmId: alarm.id,
      snoozeCount: nextSnoozeCount,
      weekday: 0,
    );
  }

  DateTime _nextInstanceOfTime(int hour, int minute) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  DateTime _nextInstanceOfTimeAndWeekday(int hour, int minute, int weekday) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
