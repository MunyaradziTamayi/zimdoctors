import 'package:just_audio/just_audio.dart';

class AudioPlaybackService {
  AudioPlaybackService._internal();
  static final AudioPlaybackService _instance =
      AudioPlaybackService._internal();
  static AudioPlaybackService get instance => _instance;

  late final AudioPlayer _audioPlayer;
  Stream<PlayerState>? _playerStateStream;

  Future<void> init() async {
    _audioPlayer = AudioPlayer();
    _playerStateStream = _audioPlayer.playerStateStream;
  }

  Future<void> playFile(String filePath) async {
    try {
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
    } catch (e) {
      throw Exception('Error playing audio: $e');
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Stream<PlayerState> get playerStateStream =>
      _playerStateStream ??
      Stream.value(PlayerState(false, ProcessingState.idle));

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
