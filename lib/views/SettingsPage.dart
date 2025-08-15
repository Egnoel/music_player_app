import 'package:flutter/material.dart';

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
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Go back to the previous screen
          },
          child: Text('Go Back'),
        ),
      ),
    );
  }
}