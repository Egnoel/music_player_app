import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player/utils/music_player_service.dart';
import 'package:music_player/views/full_player_page.dart';

// import 'package:music_player/views/full_player_page.dart'; // For navigating to a full player
import 'package:provider/provider.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicPlayerService>(
      builder: (context, playerService, child) {
        final song = playerService.currentSong;
        final isPlaying = playerService.isPlaying;
        final currentPosition = playerService.currentPosition;
        final totalDuration = playerService.totalDuration;

        // If no song is loaded or selected, don't show the mini player
        if (song == null) {
          return const SizedBox.shrink(); // Or some placeholder if you prefer
        }

        double progress = 0.0;
        if (totalDuration.inMilliseconds > 0) {
          progress = currentPosition.inMilliseconds / totalDuration.inMilliseconds;
        }

        return GestureDetector(
          onTap: () {

             Navigator.of(context).push(MaterialPageRoute(
               builder: (_) => FullPlayerPage(),
             ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.95), // M3-ish color
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            height: 70, // Adjust height as needed
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Optional: Linear progress bar for the mini player
                if (totalDuration > Duration.zero)
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                  ),
                Expanded( // Use Expanded to fill the remaining space
                  child: Row(
                    children: [
                      // Album Artwork (Optional)
                      if (song.artworkUrl != null && song.artworkUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 10.0, top: 2.0, bottom:2.0), // Added some top/bottom padding
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: Image.network(
                              song.artworkUrl!,
                              height: 50,
                              width: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note, size: 50),
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(right: 10.0, top: 2.0, bottom:2.0),
                          child: Icon(Icons.music_note, size: 50),
                        ),

                      // Song Title and Artist
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              song.artist,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),

                      // Play/Pause Button
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 32.0,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            playerService.pause();
                          } else {
                            // If the song is completed and we press play, restart it or play from beginning
                            if (playerService.processingState == ProcessingState.completed) {
                              playerService.seek(Duration.zero); // Go to beginning
                              playerService.play();
                            } else {
                              playerService.play();
                            }
                          }
                        },
                      ),
                      // Optional: Next button (if you implement queue logic)
                      // IconButton(
                      //   icon: Icon(Icons.skip_next_rounded, size: 30.0),
                      //   onPressed: () { /* playerService.next(); */ },
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
