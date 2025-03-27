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

  Future<void> _pickAndDubAudioFile() async {
    try {
      // Pick an audio file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio, // Restrict to audio files
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedAudioFile = File(result.files.single.path!);
          _recognizedText = ""; // Reset recognized text
          _translatedText = ""; // Reset translated text
        });

        // Process the audio file (speech-to-text)
        await _processAudioFile();
      } else {
        print("No audio file selected.");
      }
    } catch (e) {
      print("Error picking audio file: $e");
    }
  }

  Future<String> _transcribeWithAzure(File audioFile) async {
  final apiKey = "YOUR_API_KEY"; // Remove key from code! Use .env
  final region = "eastus";
  
  try {
    // 1. Validate audio duration (Azure free tier has limits)
    final audioLength = await _getAudioDuration(audioFile);
    if (audioLength > 60) {
      throw Exception("Azure free tier max: 60 seconds. Your file: ${audioLength}s");
    }

    // 2. Prepare request
    final url = Uri.parse(
      'https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-US',
    );

    final response = await http.post(
      url,
      headers: {
        'Ocp-Apim-Subscription-Key': apiKey,
        'Content-Type': 'audio/wav; codec=audio/pcm; samplerate=16000',
      },
      body: await audioFile.readAsBytes(),
    );

    // 3. Enhanced response handling
    final result = jsonDecode(response.body);
    debugPrint("Azure RAW Response: $result"); // Log full response

    if (response.statusCode == 200) {
      return result['DisplayText'] ?? 
             result['RecognitionStatus'] ?? 
             "Error: No transcription (Status: ${result['RecognitionStatus']})";
    } else {
      throw Exception("Azure Error ${response.statusCode}: ${response.body}");
    }
  } catch (e) {
    debugPrint("Transcription failed: $e");
    return "Transcription Error: ${e.toString()}";
  }
}

Future<double> _getAudioDuration(File file) async {
  // Implement using flutter_ffmpeg or similar package
  return 10.0; // Placeholder - replace with actual duration check
}

  // New Function: Process Audio File for Speech Recognition
  Future<void> _processAudioFile() async {
  if (_selectedAudioFile == null) return;

  setState(() => _recognizedText = "Processing audio...");
  
  try {
    final transcription = await _transcribeWithAzure(_selectedAudioFile!);
    
    setState(() {
      _recognizedText = transcription;
      // Only proceed if we got valid text
      if (!transcription.contains("Error") && transcription.trim().isNotEmpty) {
        _translateText(); // Auto-translate
      }
    });
  } catch (e) {
    setState(() => _recognizedText = "Processing failed: ${e.toString()}");
  }
}

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
              ElevatedButton(
                onPressed: _pickAndDubAudioFile, // New button for picking audio
                child: const Text("Pick Audio File & Dub"),
              ),
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
