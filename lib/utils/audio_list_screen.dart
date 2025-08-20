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
    print("Iniciando _loadAudios...");
    setState(() {
      isLoading = true;
    });

    try {
      print("Chamando deviceMediaFinder.getAudios()..."); // LOG
    final result = await deviceMediaFinder.getAudios();
    print("deviceMediaFinder.getAudios() retornou. Número de áudios: ${result.length}"); // LOG
    if (result.isNotEmpty) {
      print("Primeiro áudio encontrado: Nome - ${result.first.name}, Artista - ${result.first.artist}, Duração - ${result.first.duration}"); // LOG DETALHADO
    } else {
      print("Nenhum áudio foi retornado pela biblioteca."); // LOG
    }
      setState(() {
        audios = result;
        isLoading = false;
      });
      print("_loadAudios concluído com sucesso.");
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
                final songToPlay = Song(
                  id: audio.path, // Usar filePath como ID único
                  title: audio.name ?? 'Título Desconhecido',
                  artist: audio.artist ?? 'Artista Desconhecido',
                  audioUrl: audio.path, // filePath é o caminho para o áudio local
                );
                playerService.playSong(songToPlay);

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