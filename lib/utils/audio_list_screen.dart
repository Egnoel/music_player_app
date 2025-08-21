import 'package:device_media_finder/models/media_file.dart';
import 'package:flutter/material.dart';
import 'package:device_media_finder/device_media_finder.dart';
import 'package:music_player/utils/music_player_service.dart';
import 'package:provider/provider.dart';

class AudioListScreen extends StatefulWidget {
  @override
  _AudioListScreenState createState() => _AudioListScreenState();
}

class _AudioListScreenState extends State<AudioListScreen> {
  final deviceMediaFinder = DeviceMediaFinder();
  List<AudioFile> audios = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAudios();
  }

  Future<void> _loadAudios() async {
    setState(() {
      isLoading = true;
    });

    try {

    final result = await deviceMediaFinder.getAudios();

    if (result.isNotEmpty) {

    } else {
      print("Nenhum áudio foi retornado pela biblioteca."); // LOG
    }
      setState(() {
        audios = result;
        isLoading = false;
      });
    if (audios.isNotEmpty && mounted) {
      final playerService = Provider.of<MusicPlayerService>(context, listen: false);
      final deviceSongs = audios.map((audioInfo) => Song(
        id: audioInfo.path,
        title: audioInfo.name ?? 'Desconhecido',
        artist: audioInfo.artist ?? 'Desconhecido',
        audioUrl: audioInfo.path,
      )).toList();
      await playerService.loadDevicePlaylist(deviceSongs); // <--- CARREGA A PLAYLIST
    }
    } catch (e, stackTrace) {
      print("Erro ao carregar arquivos de áudio: $e"); // LOG DE ERRO
      print("StackTrace do erro: $stackTrace");
      setState(() {
        isLoading = false;
      });
      if (mounted) { // Verifique se o widget ainda está montado antes de usar o context
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar arquivos de áudio: $e')),
        );
      }
    }
  }

  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final hours = (minutes / 60).floor();

    final remainingMinutes = minutes % 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerService = Provider.of<MusicPlayerService>(context, listen: false);
    return Container(

      child: isLoading
          ? Center(child: CircularProgressIndicator())
          : audios.isEmpty
          ? const Center(child: Text('Nenhuma música encontrada.'))
          : ListView.builder(
        itemCount: audios.length,
        itemBuilder: (context, index) {
          final audio = audios[index];
          return ListTile(
            leading: CircleAvatar(child: Icon(Icons.music_note)),
            title: Text(audio.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Artist: ${audio.artist}'),
                Text('Album: ${audio.album}'),
              ],
            ),
            onTap: () {
              // --- AÇÃO AO TOCAR NA MÚSICA ---
            
                // Crie um objeto Song a partir do AudioInfo
              final selectedSong = playerService.playlist[index]; // Assume que a playlist no service é a mesma que está sendo exibida
              // ou use o map como antes se 'audios' for a fonte da verdade para esta tela

              // playerService.playSong(selectedSong); // Não precisa mais de contextPlaylist se já foi carregada
              // OU, para garantir que estamos usando a música correta da lista atual do serviço:

                playerService.playSong(selectedSong);


                // Opcional: Se o MiniPlayer estiver em outra aba/tela e você quiser
                // navegar para a tela principal onde o MiniPlayer é visível:
                // Navigator.of(context).pop(); // Se AudioListScreen for um modal
                // Ou use seu sistema de navegação para ir para a tela principal
               
            },
            trailing: Text(_formatDuration(audio.duration)),
          );
        },
        padding: EdgeInsets.only(bottom: 70),
      ),
    );
  }
}