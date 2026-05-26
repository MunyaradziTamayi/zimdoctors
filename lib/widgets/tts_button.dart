import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/tts_service.dart';

class TtsButton extends StatefulWidget {
  final String text;
  final String baseUrl;

  const TtsButton({
    super.key,
    required this.text,
    required this.baseUrl,
  });

  @override
  State<TtsButton> createState() => _TtsButtonState();
}

class _TtsButtonState extends State<TtsButton> {
  late final TtsService _tts;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tts = TtsService(baseUrl: widget.baseUrl);
  }

  Future<void> _speak() async {
    setState(() => _loading = true);
    try {
      await _tts.speak(widget.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: _tts.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;

        return IconButton(
          onPressed: _loading ? null : (playing ? _tts.stop : _speak),
          icon: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(playing ? Icons.stop : Icons.volume_up),
          tooltip: playing ? 'Stop' : 'Listen',
        );
      },
    );
  }
}

