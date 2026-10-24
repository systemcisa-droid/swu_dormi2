import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';

const _kAccentColor = Color(0xFF5B5FEF);
const List<int> _kIntervalPresets = [5, 10, 15, 30];
const int _kUnlimitedRepeat = -1;

class SnoozeResult {
  final bool enabled;
  final int intervalMinutes;
  final int repeatCount;
  const SnoozeResult({
    required this.enabled,
    required this.intervalMinutes,
    required this.repeatCount,
  });
}

/// 네이티브 시계 앱의 "다시 울림" 설정 화면을 참고하여 만든 전체 화면 설정.
class AlarmSnoozeSettingsScreen extends StatefulWidget {
  final bool enabled;
  final int intervalMinutes;
  final int repeatCount;
  const AlarmSnoozeSettingsScreen({
    super.key,
    required this.enabled,
    required this.intervalMinutes,
    required this.repeatCount,
  });

  @override
  State<AlarmSnoozeSettingsScreen> createState() => _AlarmSnoozeSettingsScreenState();
}

class _AlarmSnoozeSettingsScreenState extends State<AlarmSnoozeSettingsScreen> {
  late bool _enabled;
  late int _interval;
  late bool _isCustomInterval;
  late int _repeatCount;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    _interval = widget.intervalMinutes;
    _isCustomInterval = !_kIntervalPresets.contains(widget.intervalMinutes);
    _repeatCount = widget.repeatCount;
  }

  SnoozeResult _result() => SnoozeResult(
        enabled: _enabled,
        intervalMinutes: _interval,
        repeatCount: _repeatCount,
      );

  void _pop() => Navigator.pop(context, _result());

  Future<void> _editCustomInterval() async {
    final controller = TextEditingController(
      text: _isCustomInterval ? _interval.toString() : '',
    );
    final isEnglish = Provider.of<LocaleProvider>(context, listen: false).isEnglish;
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Custom interval (minutes)' : '간격 직접 설정 (분)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnglish ? 'Cancel' : '취소'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed > 0) {
                Navigator.pop(context, parsed);
              }
            },
            child: Text(isEnglish ? 'OK' : '확인'),
          ),
        ],
      ),
    );
    if (value != null) {
      setState(() {
        _interval = value;
        _isCustomInterval = true;
      });
    }
  }

  Widget _radioRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? _kAccentColor : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 48),
            rows[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _result());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F6F8),
          elevation: 0,
          foregroundColor: Colors.black87,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _pop,
          ),
          title: Text(isEnglish ? 'Snooze' : '다시 울림'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _enabled
                      ? (isEnglish
                          ? 'Every $_interval min, $_repeatCountLabel'
                          : '$_interval분마다, $_repeatCountLabel')
                      : (isEnglish ? 'Off' : '사용 안 함'),
                  style: const TextStyle(fontSize: 15),
                ),
                activeThumbColor: _kAccentColor,
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ),
            const SizedBox(height: 20),
            Opacity(
              opacity: _enabled ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !_enabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        isEnglish ? 'Interval' : '간격',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    _groupCard([
                      for (final preset in _kIntervalPresets)
                        _radioRow(
                          label: isEnglish ? '$preset min' : '$preset분',
                          selected: !_isCustomInterval && _interval == preset,
                          onTap: () => setState(() {
                            _interval = preset;
                            _isCustomInterval = false;
                          }),
                        ),
                      _radioRow(
                        label: _isCustomInterval
                            ? (isEnglish
                                ? 'Custom ($_interval min)'
                                : '직접 설정 ($_interval분)')
                            : (isEnglish ? 'Custom' : '직접 설정'),
                        selected: _isCustomInterval,
                        onTap: _editCustomInterval,
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        isEnglish ? 'Repeat' : '반복',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    _groupCard([
                      _radioRow(
                        label: isEnglish ? '3 times' : '3회',
                        selected: _repeatCount == 3,
                        onTap: () => setState(() => _repeatCount = 3),
                      ),
                      _radioRow(
                        label: isEnglish ? '5 times' : '5회',
                        selected: _repeatCount == 5,
                        onTap: () => setState(() => _repeatCount = 5),
                      ),
                      _radioRow(
                        label: isEnglish ? 'Repeat continuously' : '계속 반복',
                        selected: _repeatCount == _kUnlimitedRepeat,
                        onTap: () => setState(() => _repeatCount = _kUnlimitedRepeat),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _repeatCountLabel => _repeatCount == _kUnlimitedRepeat ? '계속 반복' : '$_repeatCount회';
}
