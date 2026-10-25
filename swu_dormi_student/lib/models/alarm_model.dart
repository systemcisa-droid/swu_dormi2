import '../utils/alarm_sounds.dart';

class AlarmModel {
  final int id;
  final String label;
  final int hour;
  final int minute;
  final bool enabled;
  final Set<int> repeatDays; // DateTime.weekday 기준 1=월 ... 7=일, 비어있으면 1회성
  final bool qrDismissEnabled;
  final String? qrCode; // 알람을 끄기 위해 스캔해야 하는 QR 코드 내용
  final bool soundEnabled;
  final String soundId; // kAlarmSoundOptions 중 하나(soundUri가 없을 때 쓰인다)
  final String? soundUri; // 안드로이드 기기 알람음(RingtoneManager)을 골랐을 때의 content URI
  final String? soundTitle; // soundUri의 표시용 이름
  final bool vibrationEnabled;
  final bool snoozeEnabled;
  final int snoozeMinutes;
  final int snoozeRepeatCount; // -1 = 계속 반복
  // 시간표의 수업에서 자동으로 만들어진 알람이면 그 수업(ClassItem.id)을 가리킨다.
  // 시간표가 바뀔 때 이 값으로 어떤 알람을 갱신/삭제할지 찾는다. 사용자가 직접
  // 만든 알람은 null이다.
  final String? sourceClassId;

  const AlarmModel({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.enabled,
    required this.repeatDays,
    this.qrDismissEnabled = false,
    this.qrCode,
    this.soundEnabled = true,
    this.soundId = kDefaultAlarmSoundId,
    this.soundUri,
    this.soundTitle,
    this.vibrationEnabled = true,
    this.snoozeEnabled = false,
    this.snoozeMinutes = 5,
    this.snoozeRepeatCount = 3,
    this.sourceClassId,
  });

  AlarmModel copyWith({
    String? label,
    int? hour,
    int? minute,
    bool? enabled,
    Set<int>? repeatDays,
    bool? qrDismissEnabled,
    String? qrCode,
    bool? soundEnabled,
    String? soundId,
    String? soundUri,
    bool clearSoundUri = false,
    String? soundTitle,
    bool? vibrationEnabled,
    bool? snoozeEnabled,
    int? snoozeMinutes,
    int? snoozeRepeatCount,
    String? sourceClassId,
  }) {
    return AlarmModel(
      id: id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      repeatDays: repeatDays ?? this.repeatDays,
      qrDismissEnabled: qrDismissEnabled ?? this.qrDismissEnabled,
      qrCode: qrCode ?? this.qrCode,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundId: soundId ?? this.soundId,
      soundUri: clearSoundUri ? null : (soundUri ?? this.soundUri),
      soundTitle: clearSoundUri ? null : (soundTitle ?? this.soundTitle),
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      snoozeRepeatCount: snoozeRepeatCount ?? this.snoozeRepeatCount,
      sourceClassId: sourceClassId ?? this.sourceClassId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
    'repeatDays': repeatDays.toList(),
    'qrDismissEnabled': qrDismissEnabled,
    'qrCode': qrCode,
    'soundEnabled': soundEnabled,
    'soundId': soundId,
    'soundUri': soundUri,
    'soundTitle': soundTitle,
    'vibrationEnabled': vibrationEnabled,
    'snoozeEnabled': snoozeEnabled,
    'snoozeMinutes': snoozeMinutes,
    'snoozeRepeatCount': snoozeRepeatCount,
    'sourceClassId': sourceClassId,
  };

  factory AlarmModel.fromJson(Map<String, dynamic> json) => AlarmModel(
    id: json['id'] as int,
    label: json['label'] as String? ?? '',
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    enabled: json['enabled'] as bool? ?? true,
    repeatDays: ((json['repeatDays'] as List?) ?? [])
        .map((e) => e as int)
        .toSet(),
    qrDismissEnabled: json['qrDismissEnabled'] as bool? ?? false,
    qrCode: json['qrCode'] as String?,
    soundEnabled: json['soundEnabled'] as bool? ?? true,
    soundId: json['soundId'] as String? ?? kDefaultAlarmSoundId,
    soundUri: json['soundUri'] as String?,
    soundTitle: json['soundTitle'] as String?,
    vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
    snoozeEnabled: json['snoozeEnabled'] as bool? ?? false,
    snoozeMinutes: json['snoozeMinutes'] as int? ?? 5,
    snoozeRepeatCount: json['snoozeRepeatCount'] as int? ?? 3,
    sourceClassId: json['sourceClassId'] as String?,
  );
}
