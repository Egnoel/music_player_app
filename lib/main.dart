import 'package:flutter/material.dart';
import 'package:music_player/themes/light_mode.dart';
import 'package:music_player/themes/theme_provider.dart';
import 'package:music_player/views/SettingsPage.dart';
import 'package:provider/provider.dart';


void main() {
  runApp(
      ChangeNotifierProvider(create: (context)=>ThemeProvider(),
      child: const MainApp(),
      )
  );
}


class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Music Player",
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

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
      body: Center(
        child: Text("Main Content Area"),
      ),
    );
  }
}


