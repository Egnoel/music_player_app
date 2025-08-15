import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_player/themes/theme_provider.dart';
import 'package:provider/provider.dart';

class Settingspage extends StatefulWidget {
  const Settingspage({super.key});

  @override
  State<Settingspage> createState() {
    return _Settingspage();
  }
}

class _Settingspage extends State<Settingspage>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Container(
        decoration: BoxDecoration(
          color:Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.all(25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.bold),),
            CupertinoSwitch(
              value: Provider.of<ThemeProvider>(context, listen:false).isDarkMode,
              onChanged: (value)=>Provider.of<ThemeProvider>(context, listen:false).toogleTheme(),
            )
          ],
        )
      ),
    );
  }
}