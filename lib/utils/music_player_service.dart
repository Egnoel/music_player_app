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
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Song &&
              runtimeType == other.runtimeType &&
              id == other.id; // Comparar por ID é geralmente suficiente

  @override
  int get hashCode => id.hashCode;
}

enum RepeatMode { off, all, one, count  }


class MusicPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Song> _originalPlaylist = []; // Lista de músicas atual
  List<Song> _shuffledPlaylist = [];
  int _currentIndex = -1;
  Song? get currentSong {
    final list = _isShuffling ? _shuffledPlaylist : _originalPlaylist;
    if (_currentIndex >= 0 && _currentIndex < list.length) {
      return list[_currentIndex];
    }
    return null;
  }
  List<Song> get _currentPlaybackList => _isShuffling ? _shuffledPlaylist : _originalPlaylist;

  ProcessingState _processingState = ProcessingState.idle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  RepeatMode _repeatMode = RepeatMode.off;
  int _repeatCount = 0; // Número de vezes que a música atual já repetiu (para modo count)
  int _targetRepeatCount = 1;
  bool _isShuffling = false;
  bool get isShuffling => _isShuffling;
  RepeatMode get repeatMode => _repeatMode;
  List<Song> get playlist => List.unmodifiable(_originalPlaylist); // Getter para a playlist (imutável para quem está fora)
  int get targetRepeatCount => _targetRepeatCount;
  int get currentIndex => _currentIndex;
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
        _isPlaying = false; // Explicitamente setar para falso
        _currentPosition = Duration.zero; // Resetar posição para futuras reproduções da mesma música

        // Lógica de conclusão da música baseada no modo de repetição
        _handleSongCompletion();
      }
      notifyListeners();
    });
  }

  Future<void> setPlaylist(List<Song> newPlaylist, {int initialIndex = 0}) async {
    _originalPlaylist = List.from(newPlaylist); // Copiar a lista para evitar modificações externas inesperadas
    _isShuffling = false; // Ao definir uma nova playlist, geralmente desativamos o shuffle.
    _shuffledPlaylist = [];

    if (_originalPlaylist.isEmpty) {
      await stop(); // Se a nova playlist estiver vazia, pare tudo
      _currentIndex = -1;
      notifyListeners();
      return;
    }

    _currentIndex = initialIndex.clamp(0, _originalPlaylist.length - 1); // Garante que o índice é válido

    if (currentSong != null) {
      await _loadAndPlaySong(currentSong!); // Carrega e toca a música no índice inicial
    } else {
      _currentIndex = -1;
      await stop(); // Caso algo dê errado e currentSong seja null
    }
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? contextPlaylist, bool startPlaying = true}) async {
    debugPrint("playSong START: Tentando tocar '${song.title}' (ID: ${song.id}). Current song (getter) ANTES de mudar índice: '${currentSong?.title}' (ID: ${currentSong?.id})");
    Song songToPlay = song; // songToPlay é a música que queremos que toque.
    bool playlistStructureChanged = false;

    // Bloco para definir _originalPlaylist e playlistStructureChanged (parece OK)
    if (contextPlaylist != null && contextPlaylist.isNotEmpty) {
      if (!listEquals(_originalPlaylist, contextPlaylist)) {
        _originalPlaylist = List.from(contextPlaylist);
        if (_isShuffling) {
          _generateShuffledPlaylist(maintainCurrentSong: false);
        }
        playlistStructureChanged = true;
        debugPrint("playSong: contextPlaylist diferente, playlistStructureChanged = true");
      }
    } else if (_originalPlaylist.isEmpty && songToPlay != null) {
      _originalPlaylist = [songToPlay];
      playlistStructureChanged = true;
      debugPrint("playSong: _originalPlaylist estava vazia, playlistStructureChanged = true");
    }

    // Encontra o índice da música desejada na _originalPlaylist
    int originalIndex = _originalPlaylist.indexWhere((s) => s.id == songToPlay.id);
    debugPrint("playSong: originalIndex para '${songToPlay.title}' é $originalIndex");

    if (originalIndex == -1) {
      if (contextPlaylist == null) { // Só adiciona se não havia um contexto de playlist estrito
        _originalPlaylist.add(songToPlay);
        originalIndex = _originalPlaylist.length - 1;
        if(_isShuffling) _generateShuffledPlaylist(maintainCurrentSong: false);
        playlistStructureChanged = true; // A estrutura mudou
        debugPrint("playSong: Música não encontrada na original, adicionada. Novo originalIndex = $originalIndex. playlistStructureChanged = true");
      } else {
        debugPrint("Erro playSong: Música '${songToPlay.title}' não encontrada na contextPlaylist fornecida.");
        return;
      }
    }

    // --- PONTO CRÍTICO: Definir _currentIndex ---
    // A música que estava tocando (currentSong via getter) ANTES DESTA SEÇÃO é importante.
    Song? songThatWasPlaying = currentSong;
    debugPrint("playSong: Música que estava tocando (antes de atualizar _currentIndex): '${songThatWasPlaying?.title}'");

    int newProspectiveIndex;
    if (_isShuffling) {
      if (playlistStructureChanged || !_shuffledPlaylist.any((s) => s.id == songToPlay.id)) {
        debugPrint("playSong: Shuffle ON - Regenerando _shuffledPlaylist para songToMakeCurrent: ${songToPlay.title}");
        _generateShuffledPlaylist(songToMakeCurrent: songToPlay);
      }
      newProspectiveIndex = _shuffledPlaylist.indexWhere((s) => s.id == songToPlay.id);
      debugPrint("playSong: Shuffle ON - Prospective _currentIndex na _shuffledPlaylist = $newProspectiveIndex para '${songToPlay.title}'");
    } else {
      newProspectiveIndex = originalIndex;
      debugPrint("playSong: Shuffle OFF - Prospective _currentIndex na _originalPlaylist = $newProspectiveIndex para '${songToPlay.title}'");
    }

    // Agora, a decisão de carregar a música deve ser baseada se a *música que queremos tocar (songToPlay)*
    // é diferente da *música que estava tocando (songThatWasPlaying)*, OU se o índice mudou, OU se a estrutura da playlist mudou.

    // Se o índice prospectivo é o mesmo que o _currentIndex ATUAL (antes de atualizá-lo),
    // E a songToPlay é a mesma que estava tocando, então só precisamos nos preocupar com o play/pause.
    // Caso contrário, provavelmente precisamos carregar.

    if (newProspectiveIndex == -1 && _currentPlaybackList.isNotEmpty) {
      debugPrint("playSong: ALERTA - newProspectiveIndex é -1, mas _currentPlaybackList não está vazia. Definindo para 0.");
      newProspectiveIndex = 0; // Tenta o primeiro como fallback
    } else if (newProspectiveIndex == -1) {
      debugPrint("playSong: ERRO CRÍTICO - newProspectiveIndex é -1 e _currentPlaybackList está vazia. Retornando.");
      return; // Não há o que fazer
    }


    // Condição principal para recarregar a música:
    // 1. A música que queremos tocar (songToPlay) é diferente da que estava tocando (songThatWasPlaying)?
    // 2. Ou a estrutura da playlist mudou (o que implica um recarregamento para garantir consistência)?
    // 3. Ou o índice prospectivo é diferente do _currentIndex atual (o que significa que estamos mudando de faixa na lista atual)?
    bool shouldLoadNewSong = (songThatWasPlaying?.id != songToPlay.id) ||
        playlistStructureChanged ||
        (newProspectiveIndex != _currentIndex);

    debugPrint("playSong: songThatWasPlaying?.id ('${songThatWasPlaying?.id}') != songToPlay.id ('${songToPlay.id}') = ${songThatWasPlaying?.id != songToPlay.id}");
    debugPrint("playSong: playlistStructureChanged = $playlistStructureChanged");
    debugPrint("playSong: newProspectiveIndex ($newProspectiveIndex) != _currentIndex ($_currentIndex) = ${newProspectiveIndex != _currentIndex}");
    debugPrint("playSong: shouldLoadNewSong = $shouldLoadNewSong");


    if (shouldLoadNewSong) {
      _currentIndex = newProspectiveIndex; // ATUALIZA O ÍNDICE GLOBAL AQUI
      _repeatCount = 0;
      debugPrint("playSong: CARREGANDO NOVA MÚSICA - _currentIndex agora é $_currentIndex. Música: '${currentSong?.title}'");
      if (startPlaying) {
        await _loadAndPlaySong(songToPlay); // Passa a songToPlay diretamente
      } else {
        // Apenas carrega informações (seu código aqui estava bom)
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        try {
          final tempPlayer = AudioPlayer();
          await tempPlayer.setAudioSource(AudioSource.uri(Uri.file(songToPlay.audioUrl)));
          _totalDuration = tempPlayer.duration ?? Duration.zero;
          await tempPlayer.dispose();
        } catch (e) {
          _totalDuration = Duration.zero;
        }
        notifyListeners();
      }
    } else if (startPlaying && !_isPlaying) {
      // Mesma música, mesmo índice, mas não estava tocando e queremos tocar
      debugPrint("playSong: Mesma música, mesmo índice. Estava pausado, chamando play(). _currentIndex = $_currentIndex. Música: '${currentSong?.title}'");
      await play();
    } else {
      debugPrint("playSong: Nenhuma ação necessária. Mesma música, mesmo índice, e ou não é para tocar ou já está tocando. _currentIndex = $_currentIndex. Música: '${currentSong?.title}'");
      // Se já está tocando a música correta, e startPlaying é true, não faz nada.
      // Se startPlaying é false, também não faz nada (não é para iniciar a reprodução).
      // Notificar de qualquer maneira pode ser útil se alguma propriedade menor mudou,
      // mas no contexto de não trocar a música, pode não ser necessário se _loadAndPlaySong ou play() não forem chamados.
      // No entanto, se o _currentIndex foi atualizado (mesmo que a música seja a mesma, mas o índice mudou),
      // o notifyListeners é implícito em _loadAndPlaySong ou play.
      // Se nenhuma dessas condições acima for atendida, _currentIndex não mudou e a música não mudou.
      // Se _currentIndex FOI atualizado para o mesmo índice da música que já estava tocando,
      // a condição shouldLoadNewSong (newProspectiveIndex != _currentIndex) seria falsa,
      // levando a este 'else'. Neste caso, se a música já está tocando, está tudo certo.
    }
    // O notifyListeners() principal deve vir de _loadAndPlaySong ou play(), que já o possuem.
    // Se você chegar ao 'else' e precisar de uma notificação por alguma outra razão, adicione-a.
  }
  Future<void> _loadAndPlaySong(Song song) async {
    if (_audioPlayer.playing || _audioPlayer.processingState != ProcessingState.idle) {
      await _audioPlayer.stop();
    }
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    _repeatCount = 0; // Resetar contagem ao carregar nova música

    notifyListeners();

    try {
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.file(song.audioUrl)));
      await play();
    } catch (e) {
      debugPrint("Erro ao carregar ou tocar música: $e");
      _currentIndex = -1;
      _processingState = ProcessingState.idle;
      notifyListeners();
    }
  }

  void _handleSongCompletion() {
    if (currentSong == null) return;
    final activePlaylist = _currentPlaybackList; // Usa a lista ativa

    switch (_repeatMode) {
      case RepeatMode.one:
        seek(Duration.zero);
        play();
        break;
      case RepeatMode.count:
        _repeatCount++;
        if (_repeatCount < _targetRepeatCount) {
          seek(Duration.zero);
          play();
        } else {
          _repeatCount = 0;
          if (_currentIndex < activePlaylist.length - 1) {
            next(autoPlay: true);
          } else if (_repeatMode == RepeatMode.all) { // Se for count E all, e chegou ao fim da lista count
            next(autoPlay: true); // que irá para o início da lista all
          } else {
            _currentPosition = _totalDuration > Duration.zero ? _totalDuration : Duration.zero;
            notifyListeners();
          }
        }
        break;
      case RepeatMode.all:
        next(autoPlay: true); // next() já lida com o loop da playlist ativa
        break;
      case RepeatMode.off:
        if (_currentIndex < activePlaylist.length - 1) {
          next(autoPlay: true);
        } else {
          _currentPosition = _totalDuration > Duration.zero ? _totalDuration : Duration.zero;
          notifyListeners();
        }
        break;
    }
  }

  // --- PLAYLIST E REPRODUÇÃO DE MÚSICA ---

  // Método para carregar a playlist inicial (geralmente as músicas do dispositivo)
  Future<void> loadDevicePlaylist(List<Song> deviceSongs) async {
    _originalPlaylist = List.from(deviceSongs);
    _shuffledPlaylist = []; // Limpar shuffled list
    _isShuffling = false; // Desligar shuffle ao carregar nova lista principal
    _currentIndex = -1;
    notifyListeners();
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


  Future<void> play() async {
    if (currentSong == null || _audioPlayer.processingState == ProcessingState.loading) return;
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
    _currentPosition = position; // Atualiza a posição imediatamente para a UI
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    // _currentSong = null; // currentSong é um getter
    _currentIndex = -1; // Indica que nenhuma música está selecionada/tocando
    _currentPosition = Duration.zero;
    _processingState = ProcessingState.idle;
    notifyListeners();
  }

  Future<void> next({bool autoPlay = false}) async {
    final activePlaylist = _currentPlaybackList;
    if (activePlaylist.isEmpty) return;
    _repeatCount = 0; // Resetar contagem ao mudar de música manualmente

    if (_repeatMode == RepeatMode.all && _currentIndex == activePlaylist.length - 1) {
      _currentIndex = 0;
    } else if (_currentIndex < activePlaylist.length - 1) {
      _currentIndex++;
    } else {
      if (_repeatMode == RepeatMode.off || _repeatMode == RepeatMode.count) { // No modo count, se chegou ao fim da playlist, para.
        if (!autoPlay){
          _currentPosition = _totalDuration;
          _isPlaying = false;
          notifyListeners();
        }
        return;
      }
      // Se for RepeatMode.one, _handleSongCompletion cuida disso, não deveria chegar aqui.
    }

    if (currentSong != null) {
      await _loadAndPlaySong(currentSong!);
      if (!autoPlay && !_isPlaying) await pause();
    }
    notifyListeners();
  }

  Future<void> previous({bool autoPlay = false}) async {
    final activePlaylist = _currentPlaybackList;
    if (activePlaylist.isEmpty) return;
    _repeatCount = 0;

    const restartThreshold = Duration(seconds: 3);
    if (_currentPosition > restartThreshold && _currentIndex >= 0) {
      await seek(Duration.zero);
      if (autoPlay && !_isPlaying) await play();
      return;
    }

    if (_repeatMode == RepeatMode.all && _currentIndex == 0) {
      _currentIndex = activePlaylist.length - 1;
    } else if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      await seek(Duration.zero);
      if (autoPlay && !_isPlaying) await play();
      return;
    }

    if (currentSong != null) {
      await _loadAndPlaySong(currentSong!);
      if (!autoPlay && !_isPlaying) await pause();
    }
    notifyListeners();
  }

  // --- LÓGICA DE REPEAT ATUALIZADA ---
  void cycleRepeatMode() {
    // Off -> All -> One -> Count -> Off
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.count;
        _repeatCount = 0; // Resetar contagem ao entrar no modo 'count'
        // _targetRepeatCount já tem um valor padrão, ou pode ser configurado pela UI
        break;
      case RepeatMode.count:
        _repeatMode = RepeatMode.off;
        _repeatCount = 0; // Resetar contagem ao sair do modo 'count'
        break;
    }
    notifyListeners();
  }

  // Novo: Definir o número de repetições para o modo 'count'
  void setTargetRepeatCount(int count) {
    if (count < 1) return; // Pelo menos 1 repetição (tocar 2x no total)
    _targetRepeatCount = count;
    if (_repeatMode == RepeatMode.count) {
      _repeatCount = 0; // Reseta a contagem atual se o alvo mudar enquanto estiver no modo
    }
    notifyListeners();
  }

  // (Opcional) Método para definir um modo de repetição específico
  void setRepeatMode(RepeatMode mode) {
    _repeatMode = mode;
    _repeatCount = 0; // Sempre resetar contagem ao mudar de modo explicitamente
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffling = !_isShuffling;
    Song? songBeforeShuffleToggle = currentSong; // Pega a música que estava tocando

    if (_isShuffling) {
      _generateShuffledPlaylist(songToMakeCurrent: songBeforeShuffleToggle);
    } else {
      // Ao desativar o shuffle, encontrar a música atual na playlist original
      if (songBeforeShuffleToggle != null) {
        _currentIndex = _originalPlaylist.indexWhere((s) => s.id == songBeforeShuffleToggle.id);
        if (_currentIndex == -1 && _originalPlaylist.isNotEmpty) _currentIndex = 0; // Fallback
      } else if (_originalPlaylist.isNotEmpty) {
        _currentIndex = 0; // Se não havia música, vai para o início da original
      } else {
        _currentIndex = -1;
      }
    }
    notifyListeners();
  }

  void _generateShuffledPlaylist({Song? songToMakeCurrent, bool maintainCurrentSong = true}) {
    if (_originalPlaylist.isEmpty) {
      _shuffledPlaylist = [];
      _currentIndex = -1;
      return;
    }

    _shuffledPlaylist = List.from(_originalPlaylist);
    _shuffledPlaylist.shuffle();

    if (songToMakeCurrent != null) {
      // Encontra a música especificada na nova lista embaralhada
      int newIndex = _shuffledPlaylist.indexWhere((s) => s.id == songToMakeCurrent.id);
      if (newIndex != -1) {
        // Move a música para o início da lista embaralhada para ser a próxima a tocar (ou a atual)
        // Isso garante que a música que o usuário "espera" que toque, ou que estava tocando,
        // continue sendo a música atual na nova ordem embaralhada.
        final song = _shuffledPlaylist.removeAt(newIndex);
        _shuffledPlaylist.insert(0, song);
        _currentIndex = 0;
      } else {
        // Se a música especificada não estiver na lista original (improvável se veio de currentSong)
        // apenas mantenha o _currentIndex como 0 para a lista embaralhada.
        _currentIndex = 0;
      }
    } else if (maintainCurrentSong && _currentIndex != -1 && _originalPlaylist.isNotEmpty) {
      // Se nenhuma música específica foi passada, mas queremos manter a música atual
      // Isso é mais complexo porque _currentIndex refere-se à lista *antes* do shuffle.
      // A melhor abordagem é pegar a currentSong antes do shuffle e chamá-la.
      // A lógica de songToMakeCurrent já cobre isso se chamada corretamente.
      // Normalmente, passaremos songToMakeCurrent.
      _currentIndex = 0; // Fallback para o início da lista embaralhada
    } else if (_shuffledPlaylist.isNotEmpty) {
      _currentIndex = 0; // Fallback
    } else {
      _currentIndex = -1;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
