import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/locale_provider.dart';
import '../../models/alarm_model.dart';
import '../../services/alarm_service.dart';
import '../../services/native_alarm_channel.dart';
import '../../utils/alarm_format.dart';
import '../../utils/alarm_sounds.dart';
import 'alarm_snooze_settings_screen.dart';

const List<String> _kWeekdayLabelsKo = ['월', '화', '수', '목', '금', '토', '일'];
const List<String> _kWeekdayLabelsEn = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// 기숙사 공용 "미션알람" QR 코드(기숙사 내 지정 장소에 부착된 코드).
/// 새 알람에서 QR로 끄기를 켜면 별도 스캔 없이 바로 이 코드로 동작한다.
const String _kDefaultMissionQrCode = 'https://m.site.naver.com/2jsh5';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final _service = AlarmService();
  List<AlarmModel> _alarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final alarms = await _service.loadAlarms();
    if (!mounted) return;
    setState(() {
      _alarms = alarms;
      _isLoading = false;
    });
  }

  String _repeatSummary(AlarmModel alarm, bool isEnglish) {
    if (alarm.repeatDays.isEmpty) {
      return formatAlarmDate(
        nextOccurrence(alarm.hour, alarm.minute),
        isEnglish,
      );
    }
    if (alarm.repeatDays.length == 7) {
      return isEnglish ? 'Every day' : '매일';
    }
    final labels = isEnglish ? _kWeekdayLabelsEn : _kWeekdayLabelsKo;
    final sorted = alarm.repeatDays.toList()..sort();
    return sorted.map((d) => labels[d - 1]).join(', ');
  }

  Future<void> _openEditor({AlarmModel? existing}) async {
    final result = await showModalBottomSheet<AlarmModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AlarmEditSheet(existing: existing),
    );
    if (result == null) return;
    final (updated, error) = await _service.addOrUpdateAlarm(result);
    if (!mounted) return;
    setState(() => _alarms = updated);
    if (error != null) {
      _showScheduleFailedWarning(error);
    } else if (result.enabled) {
      _showTimeUntilAlarm(result);
    }
  }

  Future<void> _delete(AlarmModel alarm) async {
    final updated = await _service.deleteAlarm(alarm.id);
    if (!mounted) return;
    setState(() => _alarms = updated);
  }

  Future<void> _toggle(AlarmModel alarm, bool value) async {
    final (updated, error) = await _service.setEnabled(alarm.id, value);
    if (!mounted) return;
    setState(() => _alarms = updated);
    if (error != null) {
      _showScheduleFailedWarning(error);
    } else if (value) {
      _showTimeUntilAlarm(alarm.copyWith(enabled: true));
    }
  }

  void _showScheduleFailedWarning(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('알람 예약에 실패했습니다: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showTimeUntilAlarm(AlarmModel alarm) {
    final isEnglish = Provider.of<LocaleProvider>(context, listen: false).isEnglish;
    final target = nextAlarmOccurrence(alarm.hour, alarm.minute, alarm.repeatDays);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(formatTimeUntilAlarm(target, isEnglish)),
        backgroundColor: const Color(0xFF5B5FEF),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final allOff = _alarms.isNotEmpty && _alarms.every((a) => !a.enabled);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6F8),
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(isEnglish ? 'Mission Alarm' : '미션알람'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (allOff)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text(
                      isEnglish
                          ? 'All mission alarms are off'
                          : '모든 미션알람이\n꺼진 상태입니다',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5B5FEF),
                        height: 1.3,
                      ),
                    ),
                  ),
                Expanded(
                  child: _alarms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.alarm,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isEnglish
                                    ? 'No mission alarms yet. Tap + to add one.'
                                    : '등록된 미션알람이 없습니다. +를 눌러 추가하세요.',
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _alarms.length,
                          itemBuilder: (context, index) {
                            final alarm = _alarms[index];
                            return Dismissible(
                              key: ValueKey(alarm.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) => _delete(alarm),
                              child: GestureDetector(
                                onTap: () => _openEditor(existing: alarm),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    16,
                                    16,
                                    16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (alarm.qrDismissEnabled &&
                                                (alarm.qrCode?.isNotEmpty ??
                                                    false))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (alarm.enabled
                                                                ? const Color(
                                                                    0xFF5B5FEF,
                                                                  )
                                                                : Colors.grey)
                                                            .withValues(
                                                              alpha: 0.12,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.qr_code,
                                                        size: 12,
                                                        color: alarm.enabled
                                                            ? const Color(
                                                                0xFF5B5FEF,
                                                              )
                                                            : Colors.grey,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        isEnglish
                                                            ? 'Mission Alarm'
                                                            : '미션알람',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: alarm.enabled
                                                              ? const Color(
                                                                  0xFF5B5FEF,
                                                                )
                                                              : Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            if (alarm.label.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Text(
                                                  alarm.label,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: alarm.enabled
                                                        ? Colors.black54
                                                        : Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            Text(
                                              formatAlarmClock(
                                                alarm.hour,
                                                alarm.minute,
                                                isEnglish,
                                              ),
                                              style: TextStyle(
                                                fontSize: 30,
                                                fontWeight: FontWeight.bold,
                                                color: alarm.enabled
                                                    ? Colors.black
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _repeatSummary(alarm, isEnglish),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: alarm.enabled
                                                  ? Colors.black54
                                                  : Colors.grey,
                                            ),
                                          ),
                                          Switch(
                                            value: alarm.enabled,
                                            activeThumbColor: const Color(
                                              0xFF5B5FEF,
                                            ),
                                            onChanged: (value) =>
                                                _toggle(alarm, value),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _AlarmEditSheet extends StatefulWidget {
  final AlarmModel? existing;
  const _AlarmEditSheet({this.existing});

  @override
  State<_AlarmEditSheet> createState() => _AlarmEditSheetState();
}

const int _kWheelBase = 600; // 12와 60의 공배수: 휠이 처음부터 양방향으로 자연스럽게 돈다.

class _AlarmEditSheetState extends State<_AlarmEditSheet> {
  late bool _isPm;
  late int _hour12; // 1-12
  late int _minute; // 0-59
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late Set<int> _repeatDays;
  late TextEditingController _labelController;
  late bool _qrDismissEnabled;
  String? _qrCode;
  late bool _soundEnabled;
  late String _soundId;
  String? _soundUri;
  String? _soundTitle;
  late bool _vibrationEnabled;
  late bool _snoozeEnabled;
  late int _snoozeMinutes;
  late int _snoozeRepeatCount;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final initialTime = existing != null
        ? TimeOfDay(hour: existing.hour, minute: existing.minute)
        : TimeOfDay.now();
    _isPm = initialTime.period == DayPeriod.pm;
    _hour12 = initialTime.hourOfPeriod == 0 ? 12 : initialTime.hourOfPeriod;
    _minute = initialTime.minute;
    _hourController = FixedExtentScrollController(
      initialItem: _kWheelBase + (_hour12 - 1),
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _kWheelBase + _minute,
    );
    _repeatDays = {...(existing?.repeatDays ?? {})};
    _labelController = TextEditingController(text: existing?.label ?? '');
    _qrDismissEnabled = existing?.qrDismissEnabled ?? false;
    _qrCode = existing?.qrCode ?? _kDefaultMissionQrCode;
    _soundEnabled = existing?.soundEnabled ?? true;
    _soundId = existing?.soundId ?? kDefaultAlarmSoundId;
    _soundUri = existing?.soundUri;
    _soundTitle = existing?.soundTitle;
    _vibrationEnabled = existing?.vibrationEnabled ?? true;
    _snoozeEnabled = existing?.snoozeEnabled ?? false;
    _snoozeMinutes = existing?.snoozeMinutes ?? 5;
    _snoozeRepeatCount = existing?.snoozeRepeatCount ?? 3;

    // 새 알람이면 사용자가 지금 쓰고 있는 전화 벨소리를 기본값으로 쓴다.
    if (existing == null && Platform.isAndroid) {
      _loadDefaultSystemSound();
    }
  }

  Future<void> _loadDefaultSystemSound() async {
    final result = await NativeAlarmChannel.getDefaultSystemRingtone();
    if (result == null || !mounted) return;
    // 그 사이 사용자가 이미 다른 소리를 골랐으면 덮어쓰지 않는다.
    if (_soundUri != null) return;
    setState(() {
      _soundUri = result['uri'];
      _soundTitle = result['title'];
    });
  }

  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void dispose() {
    _labelController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  int get _hour24 => _isPm ? (_hour12 % 12) + 12 : (_hour12 % 12);

  String _currentSoundName(bool isEnglish) {
    if (_soundUri != null && (_soundTitle?.isNotEmpty ?? false)) {
      return _soundTitle!;
    }
    return alarmSoundById(_soundId).name(isEnglish);
  }

  Future<void> _previewSound(String soundId) async {
    try {
      await _previewPlayer.stop();
      await _previewPlayer.play(AssetSource(alarmSoundById(soundId).assetPath));
    } catch (_) {}
  }

  Future<void> _openSoundPicker() async {
    // 안드로이드는 앱 내장 목록 없이 바로 기기 알람음 선택창으로 보낸다.
    // (iOS는 시스템 알람음에 접근할 방법이 없어 앱 내장 사운드만 고를 수 있다.)
    if (Platform.isAndroid) {
      final (result, error) = await NativeAlarmChannel.pickSystemRingtone(
        currentUri: _soundUri,
      );
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _soundUri = result['uri'];
          _soundTitle = result['title'];
        });
      } else if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('기기 알람음을 열 수 없습니다: $error')));
      }
      return;
    }

    await _previewPlayer.stop();
    if (!mounted) return;
    final result = await showModalBottomSheet<AlarmSoundPick>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _SoundPickerSheet(selectedId: _soundId, onPreview: _previewSound),
    );
    await _previewPlayer.stop();
    if (result != null && mounted) {
      setState(() {
        _soundId = result.bundledId!;
        _soundUri = null;
        _soundTitle = null;
      });
    }
  }

  Future<void> _openSnoozeSettings() async {
    final result = await Navigator.of(context).push<SnoozeResult>(
      MaterialPageRoute(
        builder: (_) => AlarmSnoozeSettingsScreen(
          enabled: _snoozeEnabled,
          intervalMinutes: _snoozeMinutes,
          repeatCount: _snoozeRepeatCount,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _snoozeEnabled = result.enabled;
        _snoozeMinutes = result.intervalMinutes;
        _snoozeRepeatCount = result.repeatCount;
      });
    }
  }

  Future<void> _scanQrCode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrRegisterScanPage()),
    );
    if (scanned != null && mounted) {
      setState(() => _qrCode = scanned);
    }
  }

  void _save() {
    if (_qrDismissEnabled && (_qrCode == null || _qrCode!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR 코드로 끄기를 사용하려면 먼저 QR 코드를 등록하세요.')),
      );
      return;
    }
    final alarm = AlarmModel(
      id: widget.existing?.id ?? AlarmService().generateId(),
      label: _labelController.text.trim(),
      hour: _hour24,
      minute: _minute,
      enabled: widget.existing?.enabled ?? true,
      repeatDays: _repeatDays,
      qrDismissEnabled: _qrDismissEnabled,
      qrCode: _qrDismissEnabled ? _qrCode : null,
      soundEnabled: _soundEnabled,
      soundId: _soundId,
      soundUri: _soundUri,
      soundTitle: _soundTitle,
      vibrationEnabled: _vibrationEnabled,
      snoozeEnabled: _snoozeEnabled,
      snoozeMinutes: _snoozeMinutes,
      snoozeRepeatCount: _snoozeRepeatCount,
    );
    Navigator.pop(context, alarm);
  }

  Widget _buildAmPmToggle(bool isEnglish) {
    final amLabel = isEnglish ? 'AM' : '오전';
    final pmLabel = isEnglish ? 'PM' : '오후';
    Widget item(String text, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? const Color(0xFF5B5FEF) : Colors.grey,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(amLabel, !_isPm, () => setState(() => _isPm = false)),
        item(pmLabel, _isPm, () => setState(() => _isPm = true)),
      ],
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int modulo,
    required int selectedValue,
    required ValueChanged<int> onChanged,
    required String Function(int) labelBuilder,
  }) {
    return SizedBox(
      width: 70,
      height: 160,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 44,
        diameterRatio: 1.3,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) => onChanged(index % modulo),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            final value = index % modulo;
            final selected = value == selectedValue;
            return Center(
              child: Text(
                labelBuilder(value),
                style: TextStyle(
                  fontSize: selected ? 28 : 20,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.black : Colors.grey.shade400,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final labels = isEnglish ? _kWeekdayLabelsEn : _kWeekdayLabelsKo;
    final dateSummary = _repeatDays.isEmpty
        ? formatAlarmDate(
            nextOccurrence(_hour24, _minute),
            isEnglish,
            withRelativePrefix: true,
          )
        : (_repeatDays.length == 7
              ? (isEnglish ? 'Every day' : '매일')
              : (_repeatDays.toList()..sort())
                    .map((d) => labels[d - 1])
                    .join(', '));

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAmPmToggle(isEnglish),
                const SizedBox(width: 8),
                _buildWheel(
                  controller: _hourController,
                  modulo: 12,
                  selectedValue: _hour12 - 1,
                  onChanged: (v) => setState(() => _hour12 = v + 1),
                  labelBuilder: (v) => '${v + 1}',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ':',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildWheel(
                  controller: _minuteController,
                  modulo: 60,
                  selectedValue: _minute,
                  onChanged: (v) => setState(() => _minute = v),
                  labelBuilder: (v) => v.toString().padLeft(2, '0'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateSummary,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final weekday = i + 1;
                final selected = _repeatDays.contains(weekday);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _repeatDays.remove(weekday);
                      } else {
                        _repeatDays.add(weekday);
                      }
                    });
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: selected
                        ? const Color(0xFF5B5FEF)
                        : const Color(0xFFF0F0F3),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                hintText: isEnglish ? 'Alarm name' : '알람 이름',
                border: const UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isEnglish ? 'Alarm sound' : '알람음'),
              subtitle: Text(
                _soundEnabled
                    ? _currentSoundName(isEnglish)
                    : (isEnglish ? 'Off' : '사용 안 함'),
              ),
              activeThumbColor: const Color(0xFF5B5FEF),
              value: _soundEnabled,
              onChanged: (value) => setState(() => _soundEnabled = value),
            ),
            if (_soundEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isEnglish ? 'Choose sound' : '알람음 선택'),
                  subtitle: Text(_currentSoundName(isEnglish)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _openSoundPicker,
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isEnglish ? 'Vibration' : '진동'),
              subtitle: Text(
                _vibrationEnabled
                    ? (isEnglish ? 'Default vibration' : '기본 진동')
                    : (isEnglish ? 'Off' : '사용 안 함'),
              ),
              activeThumbColor: const Color(0xFF5B5FEF),
              value: _vibrationEnabled,
              onChanged: (value) => setState(() => _vibrationEnabled = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isEnglish ? 'Snooze' : '다시 울림'),
              subtitle: Text(
                _snoozeEnabled
                    ? (isEnglish
                          ? 'Every $_snoozeMinutes min, ${_snoozeRepeatCount == -1 ? 'repeat continuously' : '$_snoozeRepeatCount times'}'
                          : '$_snoozeMinutes분마다, ${_snoozeRepeatCount == -1 ? '계속 반복' : '$_snoozeRepeatCount회'}')
                    : (isEnglish ? 'Off' : '사용 안 함'),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: _openSnoozeSettings,
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isEnglish ? 'Turn off with QR code' : 'QR 코드로 끄기(미션알람)'),
              subtitle: Text(
                isEnglish
                    ? 'The alarm can only be stopped by scanning the registered QR code.'
                    : '등록된 QR 코드를 스캔해야만 알람을 끌 수 있습니다.',
              ),
              activeThumbColor: const Color(0xFF5B5FEF),
              value: _qrDismissEnabled,
              onChanged: (value) => setState(() => _qrDismissEnabled = value),
            ),
            if (_qrDismissEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _qrCode == null || _qrCode!.isEmpty
                            ? (isEnglish
                                  ? 'No QR code registered'
                                  : '등록된 QR 코드 없음')
                            : (isEnglish ? 'QR code registered' : 'QR 코드 등록됨'),
                        style: TextStyle(
                          color: (_qrCode == null || _qrCode!.isEmpty)
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _scanQrCode,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(isEnglish ? 'Scan' : 'QR 스캔'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isEnglish ? 'Cancel' : '취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B5FEF),
                    ),
                    onPressed: _save,
                    child: Text(isEnglish ? 'Save' : '저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 알람음 선택 결과(앱 내장 사운드 id).
class AlarmSoundPick {
  final String? bundledId;
  const AlarmSoundPick.bundled(String id) : bundledId = id;
}

/// 앱 내장 알람음을 고르는 바텀시트. iOS 전용(안드로이드는 기기 알람음 선택창으로
/// 바로 보내므로 이 화면을 거치지 않는다). 각 항목을 누르면 바로 미리듣기가 재생된다.
class _SoundPickerSheet extends StatefulWidget {
  final String selectedId;
  final Future<void> Function(String soundId) onPreview;
  const _SoundPickerSheet({required this.selectedId, required this.onPreview});

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isEnglish ? 'Choose alarm sound' : '알람음 선택',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              for (final option in kAlarmSoundOptions)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: option.id,
                  // ignore: deprecated_member_use
                  groupValue: _selected,
                  activeColor: const Color(0xFF5B5FEF),
                  title: Text(option.name(isEnglish)),
                  secondary: IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    color: const Color(0xFF5B5FEF),
                    onPressed: () => widget.onPreview(option.id),
                  ),
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selected = value);
                    widget.onPreview(value);
                  },
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF5B5FEF),
                ),
                onPressed: () =>
                    Navigator.pop(context, AlarmSoundPick.bundled(_selected)),
                child: Text(isEnglish ? 'Done' : '선택 완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 알람을 끌 때 스캔해야 할 QR 코드를 등록하기 위한 스캔 화면.
class _QrRegisterScanPage extends StatefulWidget {
  const _QrRegisterScanPage();

  @override
  State<_QrRegisterScanPage> createState() => _QrRegisterScanPageState();
}

class _QrRegisterScanPageState extends State<_QrRegisterScanPage> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR 코드 등록')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('알람을 끌 때 스캔할 QR 코드를 카메라로 비춰주세요.'),
          ),
          Expanded(child: MobileScanner(onDetect: _onDetect)),
        ],
      ),
    );
  }
}
