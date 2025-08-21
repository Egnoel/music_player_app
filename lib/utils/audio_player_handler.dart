import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class Song {
  final String id; // Seu ID original (pode ser o filePath ou um ID do banco de dados)
  final String title;
  final String artist;
  final String audioUrl; // O path do arquivo local ou URL da web para tocar
  final String? artworkUrl; // URL ou path para a imagem da capa

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.artworkUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Song &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  // --- Conversão para MediaItem ---
  MediaItem toMediaItem() {
    return MediaItem(
      // ID para o audio_service:
      // Pode ser o mesmo que o seu 'id', ou o 'audioUrl' se for único e usável para tocar.
      // É importante que este 'id' seja o que o AudioHandler usará para carregar a fonte de áudio.
      // Se 'audioUrl' for sempre um path/URL único e tocável, usá-lo é uma boa escolha.
      id: audioUrl, // <---- MAIS COMUM USAR A URL/PATH TOCÁVEL AQUI

      // Título do álbum (se você tiver essa informação)
      album: "Desconhecido", // Você pode adicionar um campo 'album' à sua classe Song

      title: title,
      artist: artist,

      // Duração (opcional, mas bom para a UI da notificação)
      // Se você não tiver a duração aqui, o audio_service tentará obtê-la
      // quando a música for carregada.
      // duration: Duration(milliseconds: /* sua duração em ms se souber */),

      // URI da arte do álbum
      artUri: artworkUrl != null && artworkUrl!.isNotEmpty
          ? Uri.tryParse(artworkUrl!) // Use tryParse para evitar erros com URLs malformadas
          : null,

      // Extras: um mapa para quaisquer dados adicionais que você queira associar
      // e que não se encaixam nos campos padrão do MediaItem.
      // Útil para converter de volta para Song.
      extras: <String, dynamic>{
        'originalId': this.id, // Armazena seu ID original se for diferente do MediaItem.id
        // 'audioFilePath': this.audioUrl, // Se MediaItem.id for algo diferente e você precisar do path
      },
    );
  }

  // --- (Opcional) Construtor Factory para criar Song a partir de MediaItem ---
  factory Song.fromMediaItem(MediaItem mediaItem) {
    // Para reconstruir sua classe Song, você precisará dos dados.
    // O 'extras' é um bom lugar para buscar dados que não estão nos campos padrão.

    String originalSongId;
    String songAudioUrl;

    // Decida como você armazenou as informações no MediaItem:
    // Cenário 1: MediaItem.id É o audioUrl E você armazenou o id original em extras
    if (mediaItem.extras?['originalId'] != null) {
      originalSongId = mediaItem.extras!['originalId'] as String;
      songAudioUrl = mediaItem.id; // MediaItem.id é a URL/path tocável
    }
    // Cenário 2: MediaItem.id É o seu id original E você armazenou o audioUrl em extras
    // else if (mediaItem.extras?['audioFilePath'] != null) {
    //   originalSongId = mediaItem.id;
    //   songAudioUrl = mediaItem.extras!['audioFilePath'] as String;
    // }
    // Cenário 3: MediaItem.id é o seu id original E é também a URL tocável
    else {
      originalSongId = mediaItem.id;
      songAudioUrl = mediaItem.id;
    }


    return Song(
      id: originalSongId,
      title: mediaItem.title ?? "Título Desconhecido",
      artist: mediaItem.artist ?? "Artista Desconhecido",
      audioUrl: songAudioUrl,
      artworkUrl: mediaItem.artUri?.toString(),
    );
  }
}

enum RepeatMode { off, all, one, count }

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  List<MediaItem> _queue = [];
  int _currentIndex = -1; // Índice na _queue

  // Seus estados de repetição e shuffle
  RepeatMode _repeatMode = RepeatMode.off;
  // bool _isShuffling = false; // audio_service já tem um ShuffleMode

  MyAudioHandler() {
    // Escute as mudanças de estado do player para atualizar o playbackState do audio_service
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Carregar a playlist inicial (se houver)
    // _loadPlaylist(); // Você precisaria de um método para carregar sua lista de músicas

    // Configurar o modo de repetição e shuffle do just_audio
    // para sincronizar com o audio_service (ou controlar manualmente)
    _player.setLoopMode(LoopMode.off); // Começa com off
    // _player.setShuffleModeEnabled(false);
  }

  // --- Mapeando o estado do JustAudio para o PlaybackState do AudioService ---
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3], // Índices para controles na notificação compacta
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
      // Para repeat e shuffle, audio_service tem seus próprios estados
      // que você pode querer sincronizar com os do just_audio ou controlar
      // diretamente através das sobrescritas de setRepeatMode e setShuffleMode
    );
  }

  // --- Implementação do QueueHandler (gerenciamento da lista de reprodução) ---
  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    _queue.addAll(mediaItems);
    queue.add(_queue); // Notifica o audio_service sobre a mudança na fila
  }

  Future<void> setQueue(List<Song> songs) async {
    _queue = songs.map((s) => s.toMediaItem()).toList();
    queue.add(List.from(_queue)); // Atualiza o audio_service
    // Se quiser começar a tocar a primeira música automaticamente:
    // if (_queue.isNotEmpty) {
    //   await skipToQueueItem(0);
    //   await play();
    // }
  }


  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    mediaItem.add(_queue[_currentIndex]); // Informa qual item está ativo
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(_queue[index].id))); // Assumindo que MediaItem.id é a URL
      // Não chame play() aqui automaticamente, a menos que seja o comportamento desejado.
      // O play() será chamado pelo botão de play da notificação ou da UI.
    } catch (e) {
      print("Error setting audio source: $e");
    }
  }

  // --- Implementação do controle de reprodução ---
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    // Lógica de próximo, considerando repeat e shuffle (audio_service pode ajudar com isso)
    // Este é um exemplo simples:
    if (_currentIndex < _queue.length - 1) {
      await skipToQueueItem(_currentIndex + 1);
    } else if (playbackState.value.repeatMode == AudioServiceRepeatMode.all) {
      await skipToQueueItem(0); // Volta para o início se repetir todos
    }
    // Chame play se a intenção for tocar automaticamente a próxima
    if (_player.processingState != ProcessingState.idle && playbackState.value.playing) {
      play();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // Lógica de anterior
    if (_currentIndex > 0) {
      await skipToQueueItem(_currentIndex - 1);
    } else if (playbackState.value.repeatMode == AudioServiceRepeatMode.all) {
      await skipToQueueItem(_queue.length - 1); // Vai para o fim se repetir todos
    }
    if (_player.processingState != ProcessingState.idle && playbackState.value.playing) {
      play();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await playbackState.firstWhere((state) => state.processingState == AudioProcessingState.idle);
  }

  // --- Custom Actions (para funcionalidades não padrão como seu RepeatMode.count) ---
  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'setTargetRepeatCount') {
      // Lógica para seu _targetRepeatCount
      // _targetRepeatCount = extras?['count'] ?? 1;
      // Você precisará gerenciar o _repeatCount e a lógica de conclusão para RepeatMode.count aqui
      // ou dentro do listener de _player.processingStateStream se ProcessingState.completed.
      print("Custom Action: setTargetRepeatCount com $extras");
      return null;
    }
    // Lógica para alternar seu RepeatMode (off, all, one, count)
    if (name == 'cycleCustomRepeatMode') {
      // Implemente a lógica de ciclo do seu RepeatMode (off, all, one, count)
      // e atualize o playbackState se necessário para refletir na UI.
      // Ex: _cycleInternalRepeatMode();
      // broadcastState(); // Para forçar uma atualização do playbackState
      return null;
    }
    return super.customAction(name, extras);
  }


  // --- Gerenciando Repeat e Shuffle (mais alinhado com audio_service) ---
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group: // Tratar group como all para just_audio
        _player.setLoopMode(LoopMode.all); // Ou LoopMode.off e gerenciar manualmente o loop da playlist
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
    final enabled = shuffleMode == AudioServiceShuffleMode.all || shuffleMode == AudioServiceShuffleMode.group;
    _player.setShuffleModeEnabled(enabled);
    if (enabled) {
      await _player.shuffle();
    }
  }

  // Você pode precisar de uma maneira de carregar sua playlist inicial
  // void _loadPlaylist() async {
  //   final songs = await getSongsFromDevice(); // Sua lógica para pegar músicas
  //   final mediaItems = songs.map((s) => s.toMediaItem()).toList();
  //   await addQueueItems(mediaItems);
  // }

  @override
  Future<void> onTaskRemoved() {
    // Chamado quando o app é removido das recentes
    stop(); // Pare a reprodução
    return super.onTaskRemoved();
  }

  // Limpeza
  Future<void> customDispose() async {
    await _player.dispose();
  }
}