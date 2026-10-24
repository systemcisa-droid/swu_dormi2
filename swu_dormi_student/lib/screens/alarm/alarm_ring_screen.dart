import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/locale_provider.dart';
import '../../models/alarm_model.dart';
import '../../services/alarm_service.dart';
import '../../utils/alarm_format.dart';

/// 알람이 울릴 때 띄우는 화면. QR 코드 해제가 설정된 알람은
/// 등록된 코드를 스캔해야만 알람을 끌 수 있다.
class AlarmRingScreen extends StatefulWidget {
  final AlarmModel alarm;
  final int snoozeCount; // 지금까지 다시 울림을 사용한 횟수
  const AlarmRingScreen({super.key, required this.alarm, this.snoozeCount = 0});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  AudioPlayer? _audioPlayer;
  MobileScannerController? _scannerController;
  bool _isProcessingScan = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startRinging();
    if (widget.alarm.qrDismissEnabled && (widget.alarm.qrCode?.isNotEmpty ?? false)) {
      _scannerController = MobileScannerController();
    }
  }

  void _startRinging() {
    if (widget.alarm.vibrationEnabled) {
      _startVibration();
    }
    if (widget.alarm.soundEnabled) {
      _startSound();
    }
  }

  Future<void> _startVibration() async {
    try {
      if (await Vibration.hasVibrator()) {
        // repeat: 0 → 패턴을 처음부터 계속 반복. OS(Vibrator 서비스)가 직접 반복을
        // 처리하므로, 앱이 백그라운드로 가더라도 Dart 타이머에 의존하는 방식보다
        // 훨씬 안정적으로 끄기 전까지 계속 진동한다.
        Vibration.vibrate(pattern: [0, 500, 500], repeat: 0);
      }
    } catch (_) {}
  }

  Future<void> _startSound() async {
    final player = AudioPlayer();
    _audioPlayer = player;
    try {
      await player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ));
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('sounds/alarm_ring.wav'));
    } catch (_) {}
  }

  Future<void> _stopSound() async {
    try {
      await _audioPlayer?.stop();
    } catch (_) {}
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  bool get _canSnooze {
    if (!widget.alarm.snoozeEnabled) return false;
    final limit = widget.alarm.snoozeRepeatCount;
    if (limit < 0) return true; // 계속 반복
    return widget.snoozeCount < limit;
  }

  Future<void> _snooze() async {
    Vibration.cancel();
    await _stopSound();
    await AlarmService().scheduleSnooze(widget.alarm, widget.snoozeCount + 1);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    Vibration.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _dismiss() {
    Vibration.cancel();
    _stopSound();
    if (mounted) Navigator.of(context).pop();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessingScan) return;
    final value = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (value == null) return;
    _isProcessingScan = true;
    if (value == widget.alarm.qrCode) {
      _dismiss();
    } else {
      setState(() => _errorMessage = '등록된 QR 코드와 일치하지 않습니다.');
      Future.delayed(const Duration(milliseconds: 800), () {
        _isProcessingScan = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final alarm = widget.alarm;
    final timeLabel = formatAlarmClock(alarm.hour, alarm.minute, isEnglish);
    final requiresQr = alarm.qrDismissEnabled && (alarm.qrCode?.isNotEmpty ?? false);

    // 뒤로가기로 소리 없이 빠져나가는 것을 막는다. 끄기/QR 스캔/다시 울림
    // 버튼으로만 알람을 멈출 수 있어야 "끌 때까지 계속 울림" 요구에 맞는다.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                timeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (alarm.label.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    alarm.label,
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                ),
              const SizedBox(height: 24),
              if (requiresQr) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    isEnglish
                        ? 'Scan the registered QR code to stop the alarm.'
                        : '등록된 QR 코드를 스캔하면 알람이 꺼집니다.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetect,
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                if (_canSnooze)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: _snooze,
                      child: Text(
                        isEnglish ? 'Snooze' : '다시 울림',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ] else ...[
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        onPressed: _dismiss,
                        child: Text(isEnglish ? 'Stop' : '알람 끄기'),
                      ),
                      if (_canSnooze) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: _snooze,
                          child: Text(
                            isEnglish ? 'Snooze' : '다시 울림',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
