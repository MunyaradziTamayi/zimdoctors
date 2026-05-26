import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:io';

class AudioPlaybackService {
  AudioPlaybackService._internal();
  static final AudioPlaybackService _instance =
      AudioPlaybackService._internal();
  static AudioPlaybackService get instance => _instance;

  AudioPlayer? _audioPlayer;
  Stream<PlayerState>? _playerStateStream;

  Future<void> init() async {
    if (_audioPlayer != null) return;
    final player = AudioPlayer();
    _audioPlayer = player;
    _playerStateStream = player.playerStateStream;
  }

  Future<void> playFile(String filePath) async {
    try {
      await init();
      final player = _audioPlayer!;

      final file = File(filePath);
      final exists = await file.exists();
      if (!exists) {
        throw Exception('Audio file not found: $filePath');
      }
      final length = await file.length();
      if (length == 0) {
        throw Exception('Audio file is empty: $filePath');
      }

      // `just_audio` can occasionally hang on some devices when preparing a
      // source; enforce timeouts so we never end up with an uncompleted Future.
      await player
          .setFilePath(filePath)
          .timeout(const Duration(seconds: 30));
      await player.play().timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Error playing audio: $e');
    }
  }

  Future<void> stop() async {
    final player = _audioPlayer;
    if (player == null) return;
    await player.stop();
  }

  Future<void> pause() async {
    final player = _audioPlayer;
    if (player == null) return;
    await player.pause();
  }

  Future<void> resume() async {
    final player = _audioPlayer;
    if (player == null) return;
    await player.play();
  }

  Stream<PlayerState> get playerStateStream =>
      _playerStateStream ??
      Stream.value(PlayerState(false, ProcessingState.idle));

  Future<void> dispose() async {
    final player = _audioPlayer;
    if (player == null) return;
    await player.dispose();
    if (identical(_audioPlayer, player)) {
      _audioPlayer = null;
      _playerStateStream = null;
    }
  }
}
