import 'package:fluent_ui/fluent_ui.dart';

/// 로딩 인디케이터 위젯
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const ProgressRing(),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 작은 로딩 인디케이터
class SmallLoadingIndicator extends StatelessWidget {
  const SmallLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: ProgressRing(),
    );
  }
}

/// 버튼용 로딩 인디케이터
class ButtonLoadingIndicator extends StatelessWidget {
  final Color? color;

  const ButtonLoadingIndicator({
    super.key,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: ProgressRing(
        strokeWidth: 2,
        activeColor: color ?? Colors.white,
      ),
    );
  }
}

/// 오버레이 로딩 인디케이터
class OverlayLoadingIndicator extends StatelessWidget {
  final String? message;

  const OverlayLoadingIndicator({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: LoadingIndicator(message: message),
    );
  }

  /// 로딩 오버레이 표시
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OverlayLoadingIndicator(message: message),
    );
  }

  /// 로딩 오버레이 숨기기
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}
