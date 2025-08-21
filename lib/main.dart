import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:music_player/themes/theme_provider.dart';
import 'package:music_player/utils/audio_player_handler.dart';
import 'package:music_player/utils/music_player_service.dart';
import 'package:music_player/views/home_page.dart';
import 'package:provider/provider.dart';

late MyAudioHandler _audioHandler;

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  _audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(), // Cria uma instância do seu handler
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.mycompany.myapp.channel.audio',
        androidNotificationChannelName: 'Music playback',
        androidNotificationOngoing: true, // Mantém a notificação enquanto estiver tocando
        androidStopForegroundOnPause: true, // Remove o serviço de primeiro plano se pausado (opcional)
        // ... outras configurações de notificação
      ),
  );
  runApp(
     MainApp(),

  );
}


class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    ChangeNotifierProvider(create: (context)=>ThemeProvider();
    return ChangeNotifierProvider(
        create: (_) => MusicPlayerService(),
      child: MaterialApp(
      title: "Music Player",
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      home: MyHomePage(audioHandler: _audioHandler),
      )
    );
  }
}



