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
  VideoPlayerController? _controller; // Made nullable
  String? _status;
  String? _selectedVideoPath;
  String? _savedAudioPath;
  final String apiKey = '114d5ec2dcebded0001f5b1dacc1d3b9';
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Controller will be initialized when a video is selected
  }

  // Let user pick a video file
  Future<void> _pickVideoFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      _selectedVideoPath = result.files.single.path;

      // Dispose of previous controller if it exists
      _controller?.dispose();

      // Initialize new video controller
      _controller = VideoPlayerController.file(File(_selectedVideoPath!))
        ..initialize()
            .then((_) {
              setState(() {
                _status = "Selected video: $_selectedVideoPath";
              });
            })
            .catchError((error) {
              setState(() {
                _status = "Error loading video: $error";
              });
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
    // ... (rest of the _convertVideoToMp3 method remains unchanged)
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
    _controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Extract and Play MP3")),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Video Player Widget
              Container(
                padding: EdgeInsets.all(16),
                child:
                    _controller != null && _controller!.value.isInitialized
                        ? Column(
                          children: [
                            AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: VideoPlayer(_controller!),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _controller!.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _controller!.value.isPlaying
                                          ? _controller!.pause()
                                          : _controller!.play();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        )
                        : Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: Center(child: Text("No video selected")),
                        ),
              ),
              // Buttons
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => SpeechToTextScreen(
                            audioFilePath: _savedAudioPath.toString(),
                          ),
                    ),
                  );
                },
                child: Text("Convert to Text"),
              ),
              SizedBox(height: 10),
              Text(_status ?? "Select a video to convert and play"),
            ],
          ),
        ),
      ),
    );
  }
}
