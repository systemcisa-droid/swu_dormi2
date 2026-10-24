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
  final bool vibrationEnabled;
  final bool snoozeEnabled;
  final int snoozeMinutes;
  final int snoozeRepeatCount; // -1 = 계속 반복

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
    this.vibrationEnabled = true,
    this.snoozeEnabled = false,
    this.snoozeMinutes = 5,
    this.snoozeRepeatCount = 3,
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
    bool? vibrationEnabled,
    bool? snoozeEnabled,
    int? snoozeMinutes,
    int? snoozeRepeatCount,
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
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      snoozeRepeatCount: snoozeRepeatCount ?? this.snoozeRepeatCount,
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
        'vibrationEnabled': vibrationEnabled,
        'snoozeEnabled': snoozeEnabled,
        'snoozeMinutes': snoozeMinutes,
        'snoozeRepeatCount': snoozeRepeatCount,
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
        vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
        snoozeEnabled: json['snoozeEnabled'] as bool? ?? false,
        snoozeMinutes: json['snoozeMinutes'] as int? ?? 5,
        snoozeRepeatCount: json['snoozeRepeatCount'] as int? ?? 3,
      );
}
