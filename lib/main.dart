import 'package:flutter/material.dart';
import 'package:music_player/themes/theme_provider.dart';
import 'package:music_player/utils/music_player_service.dart';
import 'package:music_player/views/home_page.dart';
import 'package:provider/provider.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return ChangeNotifierProvider(
        create: (_) => MusicPlayerService(),
      child: MaterialApp(
      title: "Music Player",
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      home: MyHomePage(),
      )
    );
  }
}



