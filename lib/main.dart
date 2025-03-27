import 'package:flutter/material.dart';
import 'package:untitled1/screens/file1.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Page App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(), // Set HomePage as the initial screen
    );
  }
}
