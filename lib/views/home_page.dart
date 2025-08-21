import 'package:flutter/material.dart';
import 'package:music_player/utils/audio_list_screen.dart';
import 'package:music_player/utils/audio_player_handler.dart';
import 'package:music_player/utils/mini_player.dart';
import 'package:music_player/views/SettingsPage.dart';


class MyHomePage extends StatefulWidget {
  final MyAudioHandler audioHandler;
  const MyHomePage({super.key,
    required this.audioHandler,});

  @override
  State<MyHomePage> createState() {
    return _MyHomePage();
  }
}

class _MyHomePage extends State<MyHomePage>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Music Player"),
        actions: [
          SearchAnchor(
            builder: (context, controller) {
              return IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  controller.openView();
                },
              );
            },
            suggestionsBuilder: (context, controller) {
              return List<ListTile>.generate(5, (index) {
                final item = 'Suggestion $index';
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    controller.closeView(item);
                    //print('Selected: $item');
                  },
                );
              });
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Settingspage()),
              );
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(child: Stack(
        children: <Widget>[
          AudioListScreen(),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(widget.audioHandler),

          ),
        ],
      ),)
    );
  }
}

