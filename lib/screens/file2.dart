import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';

class SecondPage extends StatefulWidget {

  final String? initialText; // Accept text input in constructor

  SecondPage({this.initialText});
  @override
  _SecondPageState createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  static const platform =
      MethodChannel('audio_capture'); // 🔹 Connects to native Android code

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final GoogleTranslator _translator = GoogleTranslator();

  bool _isListening = false;
  String _recognizedText = "";
  String _translatedText = "";
  String _targetLanguage = "es";
  File? _selectedAudioFile;

  @override
  void initState() {
    super.initState();
        _recognizedText = widget.initialText ?? ""; // Use initialText if provided

    _initializeTts();
    _checkSpeechAvailability();
    _setupAudioCaptureListener(); // 🔹 Set up listener for system audio capture
  }

  Future<void> _initializeTts() async {
    await _tts.setLanguage(_targetLanguage);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _checkSpeechAvailability() async {
    bool available = await _speech.initialize();
    if (!available) {
      debugPrint("Speech recognition is not available on this device.");
    }
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });
      });
    } else {
      debugPrint("Speech recognition is not available.");
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _translateText() async {
    if (_recognizedText.isNotEmpty) {
      var translation =
          await _translator.translate(_recognizedText, to: _targetLanguage);
      setState(() {
        _translatedText = translation.text;
      });
      _speakTranslation();
    } else {
      debugPrint("No text available for translation.");
    }
  }

  Future<void> _speakTranslation() async {
    if (_translatedText.isNotEmpty) {
      await _tts.setLanguage(_targetLanguage);
      await _tts.speak(_translatedText);
    } else {
      debugPrint("No text to speak.");
    }
  }

  /// 🔹 New Function: Start System Audio Capture (Calls Native Android Code)
  Future<void> startCapture() async {
    try {
      final result = await platform.invokeMethod('startCapture');
      print("System Audio Capture Started: $result");
    } on PlatformException catch (e) {
      print("Failed to start capture: '${e.message}'");
    }
  }

  // 🔹 New Method to Set up Listener for Captured Audio Text from Native Side
  Future<void> _setupAudioCaptureListener() async {
    platform.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onAudioCaptured') {
        setState(() {
          _recognizedText =
              call.arguments; // Update the recognized text with captured audio
        });
      }
    });
  }

  

Future<double> _getAudioDuration(File file) async {
  // Implement using flutter_ffmpeg or similar package
  return 10.0; // Placeholder - replace with actual duration check
}

  // New Function: Process Audio File for Speech Recognition
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "Voice Translator",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text("Recognized Speech:",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text(_recognizedText,
                  style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 20),
              const Text("Translated Text:",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text(_translatedText,
                  style: const TextStyle(
                      fontSize: 16, color: Colors.yellowAccent)),
              const SizedBox(height: 20),
              DropdownButton<String>(
                value: _targetLanguage,
                dropdownColor: Colors.white,
                items: const [
                  DropdownMenuItem(value: "es", child: Text("Spanish")),
                  DropdownMenuItem(value: "fr", child: Text("French")),
                  DropdownMenuItem(value: "de", child: Text("German")),
                  DropdownMenuItem(value: "zh-cn", child: Text("Chinese")),
                  DropdownMenuItem(value: "ur", child: Text("Urdu")),
                  DropdownMenuItem(value: "ar", child: Text("Arabic")),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _targetLanguage = newValue;
                      _initializeTts();
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: startCapture,
                child: const Text("Start System Audio Capture"),
              ),
              const SizedBox(height: 20),
              
              SizedBox(height: 20,),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isListening ? _stopListening : _startListening,
                    child: Text(
                        _isListening ? "Stop Listening" : "Start Listening"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _translateText,
                    child: const Text("Translate & Speak"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
