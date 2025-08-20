import 'package:flutter/material.dart';
import 'package:music_player/views/SettingsPage.dart';

class FullPlayerPage extends StatefulWidget{
  @override
  _FullPlayerPageState createState() => _FullPlayerPageState();

}

class _FullPlayerPageState extends State<FullPlayerPage>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () {
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_downward)),
        actions: [
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
      body: SafeArea(child: Column(
        children: [

        ]
      )
      ),
    );
  }
}