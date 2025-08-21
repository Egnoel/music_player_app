import 'package:flutter/material.dart';
import 'package:music_player/utils/music_player_service.dart';
import 'package:music_player/views/SettingsPage.dart';
import 'package:provider/provider.dart';

class FullPlayerPage extends StatefulWidget {
  @override
  _FullPlayerPageState createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends State<FullPlayerPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<MusicPlayerService>(
      builder: (context, playerService, child) {
        final song = playerService.currentSong;
        final isPlaying = playerService.isPlaying;
        final currentPosition = playerService.currentPosition;
        final totalDuration = playerService.totalDuration;

        if (song == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_downward),
              ),
              title: const Text("Player"), // Título genérico
            ),
            body: const Center(
              child: Text("Nenhuma música selecionada."),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_downward),
            ),
            title: Text(song.title), // Mostrar o título da música atual
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Settingspage()), // Adicionar const
                  );
                },
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding( // Adicionar um pouco de padding geral
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Artwork da Música (usar song.artworkUrl se disponível)
                  Expanded(
                    flex: 3, // Dar mais espaço para a imagem
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.network(
                        "https://www.kennedy-center.org/globalassets/education/resources-for-educators/classroom-resources/artsedge/media/connections/science-and-music/music-science169.jpg",
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Título e Artista
                  Text(
                    song.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),

                  // Barra de Progresso e Tempos
                  _buildProgressBar(context, playerService), // Extrair para um método ou widget
                  const SizedBox(height: 20),

                  // Controles (Play/Pause, Próxima, Anterior)
                  _buildControls(context,playerService), // Extrair para um método ou widget
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _buildProgressBar(context, MusicPlayerService playerService) {
  // Você precisará converter currentPosition e totalDuration para strings formatadas
  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$minutes:$seconds".replaceFirst("00:", ""); // Remove horas se for 00
  }

  return Column(
    children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
          trackHeight: 2.0,
        ),
        child: Slider(
          value: playerService.currentPosition.inMilliseconds.toDouble().clamp(0.0, playerService.totalDuration.inMilliseconds.toDouble()),
          min: 0.0,
          max: playerService.totalDuration.inMilliseconds.toDouble() > 0 ? playerService.totalDuration.inMilliseconds.toDouble() : 1.0, // Evita divisão por zero
          onChanged: (value) {
            playerService.seek(Duration(milliseconds: value.toInt()));
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDuration(playerService.currentPosition)),
            Text(formatDuration(playerService.totalDuration)),
          ],
        ),
      ),
    ],
  );
}

// Método auxiliar para os botões de controle
Widget _buildControls(context,MusicPlayerService playerService) {
  IconData _getRepeatIcon(RepeatMode mode, int targetCount) {
    switch (mode) {
      case RepeatMode.off: return Icons.repeat;
      case RepeatMode.all: return Icons.repeat_on;
      case RepeatMode.one: return Icons.repeat_one_on;
      case RepeatMode.count: return Icons.looks_two_outlined; // Exemplo, ou use um Text com targetCount
    }
  }
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      IconButton(
        icon:  Icon(Icons.shuffle, size: 40.0,
        color: playerService.isShuffling ? Theme.of(context).primaryColor : Colors.grey,
        ),
        onPressed: playerService.playlist.isEmpty  ? null:() {
          playerService.toggleShuffle();
        },
      ),
      IconButton(
        icon: const Icon(Icons.skip_previous_rounded, size: 40.0),
        onPressed: playerService.playlist.isEmpty ? null : () => playerService.previous(autoPlay: true),
      ),
      IconButton(
        icon: Icon(
          playerService.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
          size: 64.0, // Botão de play maior
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          if (playerService.isPlaying) {
            playerService.pause();
          } else {
            playerService.play();
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.skip_next_rounded, size: 40.0),
        onPressed: playerService.playlist.isEmpty ? null : () => playerService.next(autoPlay: true),
      ),
      IconButton(
        icon: Icon(_getRepeatIcon(playerService.repeatMode, playerService.targetRepeatCount)),
        onPressed: () {
          playerService.cycleRepeatMode();
          // Se você quiser que o usuário defina a contagem ao entrar no modo 'count':
          if (playerService.repeatMode == RepeatMode.count) {
            _showSetRepeatCountDialog(context, playerService);
          }
        },
      )
    ],
  );
}
Future<void> _showSetRepeatCountDialog(BuildContext context, MusicPlayerService playerService) async {
  int currentTarget = playerService.targetRepeatCount;
  final result = await showDialog<int>(
    context: context,
    builder: (BuildContext context) {
      TextEditingController controller = TextEditingController(text: currentTarget.toString());
      return AlertDialog(
        title: Text('Repetir Música N Vezes'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'Número de repetições'),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Definir'),
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 1) { // Mínimo 1 repetição (tocar 2x)
                Navigator.of(context).pop(val);
              } else {
                // Mostrar erro ou ignorar
              }
            },
          ),
        ],
      );
    },
  );

  if (result != null) {
    playerService.setTargetRepeatCount(result);
  }
}

