import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:doctor_computer/services/review_media_service.dart';

/// Membuka foto/video ulasan layar penuh (geser untuk berpindah).
void showReviewMediaViewer(
  BuildContext context,
  List<String> urls,
  int initialIndex,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          ReviewMediaViewer(urls: urls, initialIndex: initialIndex),
    ),
  );
}

class ReviewMediaViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const ReviewMediaViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  @override
  State<ReviewMediaViewer> createState() => _ReviewMediaViewerState();
}

class _ReviewMediaViewerState extends State<ReviewMediaViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _controller = PageController(initialPage: _index);
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
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_index + 1} / ${widget.urls.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final url = widget.urls[i];
          if (ReviewMediaService.isVideoUrl(url)) {
            return _VideoPage(key: ValueKey(url), url: url);
          }
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final String url;
  const _VideoPage({super.key, required this.url});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final VideoPlayerController _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _video.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'Video tidak dapat diputar.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    if (!_video.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final playing = _video.value.isPlaying;
    return GestureDetector(
      onTap: () => playing ? _video.pause() : _video.play(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _video.value.aspectRatio,
              child: VideoPlayer(_video),
            ),
          ),
          if (!playing)
            const Icon(Icons.play_circle_fill, color: Colors.white70, size: 72),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: VideoProgressIndicator(
              _video,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
