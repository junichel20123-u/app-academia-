import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays a locally cached exercise video. Initialization failures (e.g. a
/// placeholder file that isn't a real decodable video, as the Mock provider
/// produces) are shown as a friendly fallback instead of crashing — with a
/// real provider's output this plays normally.
class ExerciseVideoPlayer extends StatefulWidget {
  const ExerciseVideoPlayer({super.key, required this.filePath});

  final String filePath;

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.file(File(widget.filePath));
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: false,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Não foi possível carregar a prévia do vídeo.'),
      );
    }
    final chewie = _chewieController;
    if (chewie == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final aspectRatio = _controller!.value.aspectRatio;
    return AspectRatio(
      aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
      child: Chewie(controller: chewie),
    );
  }
}
