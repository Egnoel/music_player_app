import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? artworkUrl;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.artworkUrl,
  });
}

class MusicPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Song? _currentSong;
  ProcessingState _processingState = ProcessingState.idle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  ProcessingState get processingState => _processingState;

  MusicPlayerService() {
    _initAudioSession();
    _listenToPlayerState();
    _listenToPosition();
    _listenToBufferedPosition(); // You might want this for buffering indication
    _listenToTotalDuration();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // Listen to interruptions (e.g., calls), and pause/resume accordingly
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (_isPlaying) pause();
      } else {
        // Handle resumption if needed, e.g., based on event.type
      }
    });
  }

  void _listenToPlayerState() {
    _audioPlayer.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      _processingState = playerState.processingState;
      if (_processingState == ProcessingState.completed) {
        // Handle song completion: play next, repeat, etc.
        _isPlaying = false; // Explicitly set to false on completion
        _currentPosition = Duration.zero; // Reset position
      }
      notifyListeners();
    });
  }

  void _listenToPosition() {
    _audioPlayer.positionStream.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });
  }

  void _listenToBufferedPosition() {
    _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      // You can use this to show buffering progress
      notifyListeners();
    });
  }

  void _listenToTotalDuration() {
    _audioPlayer.durationStream.listen((duration) {
      _totalDuration = duration ?? Duration.zero;
      notifyListeners();
    });
  }

  Future<void> playSong(Song song) async {
    if (_currentSong?.id == song.id && _processingState != ProcessingState.idle && _processingState != ProcessingState.completed) {
      // If it's the same song and it's already loaded/playing/paused, just play
      if (!_isPlaying) await play();
      return;
    }
    _currentSong = song;
    notifyListeners(); // Notify UI about the new song immediately
    try {
      // Consider adding headers if your audio URLs require them
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.file(song.audioUrl)));
      await play();
    } catch (e) {
      debugPrint("Error loading song: $e");
      _currentSong = null; // Clear current song on error
      _processingState = ProcessingState.idle;
      notifyListeners();
    }
  }

  Future<void> play() async {
    if (_currentSong == null || _audioPlayer.processingState == ProcessingState.loading) return;
    try {
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Erro ao dar play: $e");
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentSong = null;
    _currentPosition = Duration.zero;
    _processingState = ProcessingState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
