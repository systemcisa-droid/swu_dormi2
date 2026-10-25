class AlarmSoundOption {
  final String id;
  final String assetFileName;
  final String nameKo;
  final String nameEn;
  const AlarmSoundOption({
    required this.id,
    required this.assetFileName,
    required this.nameKo,
    required this.nameEn,
  });

  String get assetPath => 'sounds/$assetFileName';
  String name(bool isEnglish) => isEnglish ? nameEn : nameKo;
}

const List<AlarmSoundOption> kAlarmSoundOptions = [
  AlarmSoundOption(
    id: 'beep',
    assetFileName: 'alarm_beep.wav',
    nameKo: '기본 알람',
    nameEn: 'Default',
  ),
  AlarmSoundOption(
    id: 'bell',
    assetFileName: 'alarm_bell.wav',
    nameKo: '클래식 벨',
    nameEn: 'Classic Bell',
  ),
  AlarmSoundOption(
    id: 'digital',
    assetFileName: 'alarm_digital.wav',
    nameKo: '디지털 알람',
    nameEn: 'Digital',
  ),
  AlarmSoundOption(
    id: 'gentle',
    assetFileName: 'alarm_gentle.wav',
    nameKo: '부드러운 알람',
    nameEn: 'Gentle',
  ),
  AlarmSoundOption(
    id: 'urgent',
    assetFileName: 'alarm_urgent.wav',
    nameKo: '긴급 알람',
    nameEn: 'Urgent',
  ),
];

const String kDefaultAlarmSoundId = 'beep';

AlarmSoundOption alarmSoundById(String? id) {
  return kAlarmSoundOptions.firstWhere(
    (o) => o.id == id,
    orElse: () => kAlarmSoundOptions.first,
  );
}
