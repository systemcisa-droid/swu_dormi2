import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _urlPattern = RegExp(r'(https?://[^\s]+)');

/// 본문에 포함된 http(s):// URL만 자동으로 감지해 클릭 가능한 링크로 표시한다.
/// 마크다운 등 별도 문법 없이, 공지사항 작성자가 URL을 그대로 붙여넣으면 바로 동작한다.
class LinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Color linkColor;

  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.linkColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _urlPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      // 문장 끝 구두점이 URL에 붙어오는 경우(예: "...하세요.")는 링크에서 제외한다.
      var url = match.group(0)!;
      var trailing = '';
      while (url.isNotEmpty && '.,)!?'.contains(url[url.length - 1])) {
        trailing = url[url.length - 1] + trailing;
        url = url.substring(0, url.length - 1);
      }
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(color: linkColor, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
      );
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: textAlign,
    );
  }
}
