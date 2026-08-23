import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 단톡방 첨부 이미지/영상을 보여주는 공용 위젯 모음.

/// 말풍선 안에 들어가는 첨부 미리보기.
class ChatMediaBubble extends StatelessWidget {
  final String url;
  final bool isVideo;
  final double maxWidth;

  const ChatMediaBubble({
    super.key,
    required this.url,
    required this.isVideo,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isVideo
                ? ChatVideoPlayerScreen(url: url)
                : ChatImageViewerScreen(url: url),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 260),
              child: isVideo
                  ? Container(
                      width: maxWidth,
                      height: 160,
                      color: Colors.black87,
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: maxWidth,
                          height: 160,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, _, __) => Container(
                        width: maxWidth,
                        height: 120,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.broken_image,
                            color: Colors.grey.shade400, size: 32),
                      ),
                    ),
            ),
            if (isVideo)
              const Icon(Icons.play_circle_filled,
                  color: Colors.white, size: 48),
          ],
        ),
      ),
    );
  }
}

/// 이미지 원본 보기 (핀치 줌 지원)
class ChatImageViewerScreen extends StatelessWidget {
  final String url;
  const ChatImageViewerScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, _, __) => const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

/// 영상 재생 화면
class ChatVideoPlayerScreen extends StatefulWidget {
  final String url;
  final bool isLocal;

  const ChatVideoPlayerScreen({
    super.key,
    required this.url,
    this.isLocal = false,
  });

  @override
  State<ChatVideoPlayerScreen> createState() => _ChatVideoPlayerScreenState();
}

class _ChatVideoPlayerScreenState extends State<ChatVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.isLocal
        ? VideoPlayerController.file(File(widget.url))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    });
    _controller.setLooping(false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _initialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        return AnimatedOpacity(
                          opacity: value.isPlaying ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: const Icon(Icons.play_circle_filled,
                              color: Colors.white, size: 64),
                        );
                      },
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      bottomNavigationBar: _initialized
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white10,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
