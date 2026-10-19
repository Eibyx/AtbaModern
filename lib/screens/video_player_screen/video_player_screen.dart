import 'dart:async';
import 'dart:io';

import 'package:atba/screens/video_player_screen/desktop_video_player.dart';
import 'package:atba/screens/video_player_screen/mobile_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String url;

  const VideoPlayerScreen({super.key, required this.url});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  StreamSubscription<String>? _playerErrors;
  late final player = Player(configuration: PlayerConfiguration(libass: true));
  late final controller = VideoController(player);
  late final GlobalKey<VideoState> key = GlobalKey<VideoState>();

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.url));
    _playerErrors = player.stream.error.listen((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo reproducir el archivo. Comprueba el enlace y el formato.',
            ),
          ),
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        key.currentState?.enterFullscreen();
      }
    });
  }

  @override
  void dispose() {
    _playerErrors?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return mobileVideoPlayer(context, controller, key);
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return desktopVideoPlayer(context, controller, key);
      default:
        return Scaffold(
          body: Video(controller: controller, key: key),
        );
    }
  }
}
