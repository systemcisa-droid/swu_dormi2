import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/locale_provider.dart';
import '../../models/alarm_model.dart';
import '../../services/alarm_service.dart';
import '../../utils/alarm_format.dart';
import '../../utils/alarm_sounds.dart';
import '../../services/native_alarm_channel.dart';

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
  bool _isSoundMuted = false;
  bool _missionSucceeded = false;
  String? _errorMessage;
  Timer? _autoCloseTimer;
  String? _bannerImageUrl;

  @override
  void initState() {
    super.initState();
    _startRinging();
    _loadBannerImage();
    if (widget.alarm.qrDismissEnabled &&
        (widget.alarm.qrCode?.isNotEmpty ?? false)) {
      _scannerController = MobileScannerController();
    }
  }

  /// 홈 화면과 같은 배너 이미지를 배경으로 쓴다(settings/home.bannerImageUrl).
  Future<void> _loadBannerImage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('home')
          .get();
      final url = doc.data()?['bannerImageUrl'] as String?;
      if (url != null && url.isNotEmpty && mounted) {
        setState(() => _bannerImageUrl = url);
      }
    } catch (_) {}
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

  bool get _usesSystemRingtone => widget.alarm.soundUri?.isNotEmpty ?? false;

  Future<void> _startSound() async {
    // 기기(안드로이드) 알람음을 골랐으면 네이티브 쪽에서 반복 재생한다.
    if (_usesSystemRingtone) {
      await NativeAlarmChannel.playSystemRingtoneLoop(widget.alarm.soundUri!);
      return;
    }
    final player = AudioPlayer();
    _audioPlayer = player;
    try {
      await player.setAudioContext(
        AudioContext(
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
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource(alarmSoundById(widget.alarm.soundId).assetPath));
    } catch (_) {}
  }

  Future<void> _stopSound() async {
    if (_usesSystemRingtone) {
      await NativeAlarmChannel.stopSystemRingtoneLoop();
      return;
    }
    try {
      await _audioPlayer?.stop();
    } catch (_) {}
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  /// 소리만 끄고 진동은 계속 울리게 한다. 알람 자체는 끄기/QR 스캔으로만 멈춘다.
  Future<void> _muteSound() async {
    await _stopSound();
    if (mounted) setState(() => _isSoundMuted = true);
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
    _autoCloseTimer?.cancel();
    Vibration.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    if (_usesSystemRingtone) NativeAlarmChannel.stopSystemRingtoneLoop();
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
    final value = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (value == null) return;
    _isProcessingScan = true;
    if (value == widget.alarm.qrCode) {
      _handleQrSuccess();
    } else {
      setState(() => _errorMessage = '등록된 QR 코드와 일치하지 않습니다.');
      Future.delayed(const Duration(milliseconds: 800), () {
        _isProcessingScan = false;
      });
    }
  }

  /// QR 미션 성공: 소리/진동은 바로 멈추고, 성공 화면을 보여준다.
  /// 확인 버튼을 누르거나, 누르지 않으면 일정 시간 뒤 자동으로 닫힌다.
  void _handleQrSuccess() {
    Vibration.cancel();
    _stopSound();
    setState(() => _missionSucceeded = true);
    _autoCloseTimer = Timer(const Duration(seconds: 4), _closeAfterSuccess);
  }

  void _closeAfterSuccess() {
    _autoCloseTimer?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final alarm = widget.alarm;
    final timeLabel = formatAlarmClock(alarm.hour, alarm.minute, isEnglish);
    final requiresQr =
        alarm.qrDismissEnabled && (alarm.qrCode?.isNotEmpty ?? false);

    // 뒤로가기로 소리 없이 빠져나가는 것을 막는다. 끄기/QR 스캔/다시 울림
    // 버튼으로만 알람을 멈출 수 있어야 "끌 때까지 계속 울림" 요구에 맞는다.
    final showBanner = _bannerImageUrl != null && !_missionSucceeded;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (showBanner) Image.network(_bannerImageUrl!, fit: BoxFit.cover),
            // 배경 사진 위에서도 흰 글씨가 잘 보이도록 어둡게 덮는다.
            if (showBanner)
              Container(color: Colors.black.withValues(alpha: 0.55)),
            SafeArea(
              child: _missionSucceeded
                  ? _MissionSuccessView(
                      isEnglish: isEnglish,
                      onConfirm: _closeAfterSuccess,
                    )
                  : Column(
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
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        if (alarm.soundEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _isSoundMuted
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.volume_off,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isEnglish ? 'Sound off' : '소리 꺼짐',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  )
                                : OutlinedButton.icon(
                                    onPressed: _muteSound,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.white38,
                                      ),
                                      foregroundColor: Colors.white70,
                                    ),
                                    icon: const Icon(
                                      Icons.volume_off,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isEnglish ? 'Sound off' : '소리만 끄기',
                                    ),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
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
                                    minimumSize: const Size(
                                      double.infinity,
                                      56,
                                    ),
                                  ),
                                  onPressed: _dismiss,
                                  child: Text(isEnglish ? 'Stop' : '알람 끄기'),
                                ),
                                if (_canSnooze) ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        48,
                                      ),
                                      side: const BorderSide(
                                        color: Colors.white54,
                                      ),
                                    ),
                                    onPressed: _snooze,
                                    child: Text(
                                      isEnglish ? 'Snooze' : '다시 울림',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
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
          ],
        ),
      ),
    );
  }
}

/// QR 미션 성공 시 보여주는 축하 화면. 확인 버튼을 누르거나 일정 시간이
/// 지나면 닫힌다.
class _MissionSuccessView extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onConfirm;
  const _MissionSuccessView({required this.isEnglish, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF00C853), Color(0xFF009624)],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 16),
                    Text(
                      isEnglish ? 'MISSION SUCCESS!' : '미션 성공!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEnglish ? 'Great job waking up!' : '힘차게 하루를 시작해봐요!',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF009624),
              ),
              onPressed: onConfirm,
              child: Text(
                isEnglish ? 'OK' : '확인',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
