import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:untitled1/screens/file2.dart';

class SpeechToTextScreen extends StatefulWidget {
  final String? audioFilePath; // Nullable to handle optional input

  SpeechToTextScreen({this.audioFilePath});

  @override
  _SpeechToTextScreenState createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  String? _audioFilePath;
  String? _transcription;
  bool _isLoading = false;
  String apiKey = "6416863f532c438fa41f80f4d8a4c868"; // Replace with actual API key

  @override
  void initState() {
    super.initState();
    _audioFilePath = widget.audioFilePath; // Initialize with provided path
    if(_audioFilePath!=null){
      uploadAudio(File(_audioFilePath!));
      _isLoading = true;
    }
  }

  Future<void> pickAndTranscribeAudio() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);

  if (result != null) {
    setState(() {
      _audioFilePath = result.files.single.path;
      _transcription = null; // Reset transcription before new one starts
      _isLoading = true;
    });

    if (_audioFilePath != null) {
      await uploadAudio(File(_audioFilePath!));
    }
  }
}


  Future<void> uploadAudio(File audioFile) async {
    String uploadUrl = "https://api.assemblyai.com/v2/upload";

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.headers.addAll({"Authorization": apiKey});
    request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      String responseBody = await response.stream.bytesToString();
      String audioUrl = json.decode(responseBody)["upload_url"];
      transcribeAudio(audioUrl);
    } else {
      setState(() {
        _isLoading = false;
        _transcription = "Upload failed!";
      });
    }
  }

  Future<void> transcribeAudio(String audioUrl) async {
    String transcriptUrl = "https://api.assemblyai.com/v2/transcript";

    var response = await http.post(
      Uri.parse(transcriptUrl),
      headers: {
        "Authorization": apiKey,
        "Content-Type": "application/json"
      },
      body: jsonEncode({"audio_url": audioUrl}),
    );

    if (response.statusCode == 200) {
      String transcriptId = json.decode(response.body)["id"];
      checkTranscriptionStatus(transcriptId);
    } else {
      setState(() {
        _isLoading = false;
        _transcription = "Transcription request failed!";
      });
    }
  }

  Future<void> checkTranscriptionStatus(String transcriptId) async {
  String statusUrl = "https://api.assemblyai.com/v2/transcript/$transcriptId";

  while (mounted) { // Check if the widget is still in the tree
    var response = await http.get(Uri.parse(statusUrl), headers: {
      "Authorization": apiKey,
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      if (data["status"] == "completed") {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _transcription = data["text"];
          });
        }
        return;
      } else if (data["status"] == "failed") {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _transcription = "Transcription failed!";
          });
        }
        return;
      }
    }

    await Future.delayed(Duration(seconds: 5));
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Speech to Text")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _audioFilePath != null
                  ? "Selected File: ${_audioFilePath!.split('/').last}"
                  : "No file selected",
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: pickAndTranscribeAudio,
              child: Text("Select and Transcribe Audio"),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : _transcription != null
                    ? Expanded(child: SingleChildScrollView(child: Text(_transcription!)))
                    : Text("Transcription will appear here."),
            ElevatedButton(onPressed: (){
              Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SecondPage(initialText: _transcription,),
  ),
);
            }, child: Text("To Dubbing")),
          ],
        ),
      ),
    );
  }
}
