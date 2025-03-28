import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:untitled1/screens/file4.dart';
import 'package:video_player/video_player.dart';

class AudioExtractor extends StatefulWidget {
  @override
  _AudioExtractorState createState() => _AudioExtractorState();
}

class _AudioExtractorState extends State<AudioExtractor> {
  late VideoPlayerController _controller;
  String? _status;
  String? _selectedVideoPath;
  String? _savedAudioPath;
  final String apiKey = '3f0c4c936d8967a82c25adb39ea47e15';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  // Let user pick a video file
  Future<void> _pickVideoFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedVideoPath = result.files.single.path;
        _status = "Selected video: $_selectedVideoPath";
      });
    } else {
      setState(() => _status = "No video selected");
    }
  }

  // Convert video to MP3 and play it
  Future<void> _convertVideoToMp3() async {
    if (_selectedVideoPath == null) {
      setState(() => _status = "Please select a video file first");
      return;
    }

    try {
      final String videoPath = _selectedVideoPath!;
      final String filename = videoPath.split('/').last;
      final File videoFile = File(videoPath);

      if (!await videoFile.exists()) {
        setState(() => _status = "Video file not found at $videoPath");
        return;
      }

      // Step 1: Start conversion
      var startUrl = Uri.parse('https://api.convertio.co/convert');
      var startBody = jsonEncode({
        'apikey': apiKey,
        'input': 'upload',
        'outputformat': 'mp3',
        'filename': filename,
      });

      var startResponse = await http.post(
        startUrl,
        headers: {'Content-Type': 'application/json'},
        body: startBody,
      );

      var startJson = jsonDecode(startResponse.body);
      if (startJson['status'] != 'ok') {
        setState(() => _status = "Start failed: ${startJson['error']}");
        return;
      }

      String conversionId = startJson['data']['id'];

      // Step 2: Upload video
      var uploadUrl = Uri.parse('https://api.convertio.co/convert/$conversionId/$filename');
      var uploadRequest = http.Request('PUT', uploadUrl)
        ..headers['Content-Type'] = 'application/octet-stream'
        ..bodyBytes = await videoFile.readAsBytes();

      var uploadResponse = await uploadRequest.send();
      var uploadBody = await uploadResponse.stream.bytesToString();
      var uploadJson = jsonDecode(uploadBody);

      if (uploadJson['status'] != 'ok') {
        setState(() => _status = "Upload failed: ${uploadJson['error']}");
        return;
      }

      // Step 3: Poll conversion status
      String step = 'wait';
      String? downloadUrl;
      while (step != 'finish') {
        await Future.delayed(Duration(seconds: 2));
        var statusUrl = Uri.parse('https://api.convertio.co/convert/$conversionId/status');
        var statusResponse = await http.get(statusUrl);
        var statusJson = jsonDecode(statusResponse.body);

        if (statusJson['status'] != 'ok') {
          setState(() => _status = "Status check failed: ${statusJson['error']}");
          return;
        }

        step = statusJson['data']['step'];
        if (step == 'finish') {
          downloadUrl = statusJson['data']['output']['url'];
          break;
        } else if (step == 'error') {
          setState(() => _status = "Conversion error: ${statusJson['data']['error']}");
          return;
        }
      }

      if (downloadUrl == null) {
        setState(() => _status = "Failed to retrieve download URL");
        return;
      }

      // Step 4: Download MP3 and save locally
      setState(() => _status = "Downloading MP3...");
      var audioResponse = await http.get(Uri.parse(downloadUrl));
      Directory tempDir = await getTemporaryDirectory();
      String localFilePath = '${tempDir.path}/converted_audio.mp3';
      File localAudioFile = File(localFilePath);
      await localAudioFile.writeAsBytes(audioResponse.bodyBytes);

      setState(() {
        _savedAudioPath = localFilePath;
        _status = "Audio saved: $_savedAudioPath";
      });

      // Play the audio
      await _audioPlayer.play(BytesSource(audioResponse.bodyBytes));
      setState(() {
        _isPlaying = true;
        _status = "Playing audio";
      });

      // Listen for when audio finishes
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed) {
          setState(() {
            _isPlaying = false;
            _status = "Audio finished playing";
          });
        }
      });

    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  // Stop audio playback
  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _status = "Audio stopped";
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Extract and Play MP3")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickVideoFile,
              child: Text("Select Video"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isPlaying ? null : _convertVideoToMp3,
              child: Text("Convert and Play"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isPlaying ? _stopAudio : null,
              child: Text("Stop Playback"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: (){
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SpeechToTextScreen(audioFilePath: _savedAudioPath.toString())),
                );
              },
              child: Text("Convert to Text"),
            ),
            Text(_status ?? "Select a video to convert and play"),
          ],
        ),
      ),
    );
  }
}