import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Dubbingscreen extends StatefulWidget {
  final String videoPath;

  const Dubbingscreen({super.key, required this.videoPath});

  @override
  State<Dubbingscreen> createState() => _DubbingscreenState();
}

class _DubbingscreenState extends State<Dubbingscreen> {
  VideoPlayerController? _controller;
  String? _status;
  String? _savedAudioPath;
  String? _transcription;
  String _translatedText = "";
  String _targetLanguage = "es"; // Default language
  final String convertioApiKey =
      '114d5ec2dcebded0001f5b1dacc1d3b9'; // Convertio API key
  final String assemblyApiKey =
      "6416863f532c438fa41f80f4d8a4c868"; // AssemblyAI API key
  final GoogleTranslator _translator = GoogleTranslator();
  final FlutterTts _tts = FlutterTts();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize video controller with passed video path
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize()
          .then((_) {
            setState(() {
              _status = "Video loaded: ${widget.videoPath}";
              _controller!.setVolume(0.0); // Mute the video by default
            });
          })
          .catchError((error) {
            setState(() {
              _status = "Error loading video: $error";
            });
          });
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _tts.setLanguage(_targetLanguage);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  // Start Dubbing Process
  Future<void> _startDubbing() async {
    setState(() {
      _isLoading = true;
      _status = "Starting dubbing process...";
      _transcription = null;
      _translatedText = "";
    });

    // Step 1: Convert video to MP3
    await _convertVideoToMp3();

    if (_savedAudioPath == null) {
      setState(() => _isLoading = false);
      return; // Exit if conversion fails
    }

    // Step 2: Transcribe audio to text
    await _transcribeAudio();

    // Step 3: Play video and speak translation after transcription
    if (_transcription != null && _transcription!.isNotEmpty) {
      await _translateAndSpeak();
    }

    setState(() => _isLoading = false);
  }

  // Convert video to MP3
  Future<void> _convertVideoToMp3() async {
    try {
      final String videoPath = widget.videoPath;
      final String filename = videoPath.split('/').last;
      final File videoFile = File(videoPath);

      if (!await videoFile.exists()) {
        setState(() => _status = "Video file not found at $videoPath");
        return;
      }

      setState(() => _status = "Converting video to audio...");

      var startUrl = Uri.parse('https://api.convertio.co/convert');
      var startBody = jsonEncode({
        'apikey': convertioApiKey,
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

      var uploadUrl = Uri.parse(
        'https://api.convertio.co/convert/$conversionId/$filename',
      );
      var uploadRequest =
          http.Request('PUT', uploadUrl)
            ..headers['Content-Type'] = 'application/octet-stream'
            ..bodyBytes = await videoFile.readAsBytes();

      var uploadResponse = await uploadRequest.send();
      var uploadBody = await uploadResponse.stream.bytesToString();
      var uploadJson = jsonDecode(uploadBody);

      if (uploadJson['status'] != 'ok') {
        setState(() => _status = "Upload failed: ${uploadJson['error']}");
        return;
      }

      String step = 'wait';
      String? downloadUrl;
      while (step != 'finish') {
        await Future.delayed(Duration(seconds: 2));
        var statusUrl = Uri.parse(
          'https://api.convertio.co/convert/$conversionId/status',
        );
        var statusResponse = await http.get(statusUrl);
        var statusJson = jsonDecode(statusResponse.body);

        if (statusJson['status'] != 'ok') {
          setState(
            () => _status = "Status check failed: ${statusJson['error']}",
          );
          return;
        }

        step = statusJson['data']['step'];
        if (step == 'finish') {
          downloadUrl = statusJson['data']['output']['url'];
          break;
        } else if (step == 'error') {
          setState(
            () => _status = "Conversion error: ${statusJson['data']['error']}",
          );
          return;
        }
      }

      if (downloadUrl == null) {
        setState(() => _status = "Failed to retrieve download URL");
        return;
      }

      setState(() => _status = "Downloading MP3...");
      var audioResponse = await http.get(Uri.parse(downloadUrl));
      Directory tempDir = await getTemporaryDirectory();
      String localFilePath = '${tempDir.path}/converted_audio.mp3';
      File localAudioFile = File(localFilePath);
      await localAudioFile.writeAsBytes(audioResponse.bodyBytes);

      setState(() {
        _savedAudioPath = localFilePath;
        _status = "Audio conversion completed";
      });
    } catch (e) {
      setState(() => _status = "Error during conversion: $e");
    }
  }

  // Transcribe audio to text
  Future<void> _transcribeAudio() async {
    setState(() => _status = "Transcribing audio...");
    await uploadAudio(File(_savedAudioPath!));
  }

  Future<void> uploadAudio(File audioFile) async {
    String uploadUrl = "https://api.assemblyai.com/v2/upload";

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.headers.addAll({"Authorization": assemblyApiKey});
    request.files.add(
      await http.MultipartFile.fromPath('file', audioFile.path),
    );

    var response = await request.send();
    if (response.statusCode == 200) {
      String responseBody = await response.stream.bytesToString();
      String audioUrl = json.decode(responseBody)["upload_url"];
      transcribeAudio(audioUrl);
    } else {
      setState(() {
        _transcription = "Upload failed!";
        _status = "Audio upload failed";
      });
    }
  }

  Future<void> transcribeAudio(String audioUrl) async {
    String transcriptUrl = "https://api.assemblyai.com/v2/transcript";

    var response = await http.post(
      Uri.parse(transcriptUrl),
      headers: {
        "Authorization": assemblyApiKey,
        "Content-Type": "application/json",
      },
      body: jsonEncode({"audio_url": audioUrl}),
    );

    if (response.statusCode == 200) {
      String transcriptId = json.decode(response.body)["id"];
      checkTranscriptionStatus(transcriptId);
    } else {
      setState(() {
        _transcription = "Transcription request failed!";
        _status = "Transcription request failed";
      });
    }
  }

  Future<void> checkTranscriptionStatus(String transcriptId) async {
    String statusUrl = "https://api.assemblyai.com/v2/transcript/$transcriptId";

    while (mounted) {
      var response = await http.get(
        Uri.parse(statusUrl),
        headers: {"Authorization": assemblyApiKey},
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data["status"] == "completed") {
          if (mounted) {
            setState(() {
              _transcription = data["text"];
              _status = "Transcription completed";
            });
            // Play video and speak translation after transcription
            await _translateAndSpeak();
          }
          return;
        } else if (data["status"] == "failed") {
          if (mounted) {
            setState(() {
              _transcription = "Transcription failed!";
              _status = "Transcription failed";
            });
          }
          return;
        }
      }
      await Future.delayed(Duration(seconds: 5));
    }
  }

  // Translate and speak the transcription
  Future<void> _translateAndSpeak() async {
    if (_transcription != null && _transcription!.isNotEmpty) {
      setState(() => _status = "Translating and preparing to speak...");
      var translation = await _translator.translate(
        _transcription!,
        to: _targetLanguage,
      );
      setState(() {
        _translatedText = translation.text;
      });
      await _tts.setLanguage(_targetLanguage);

      // Mute video and start playing it
      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.setVolume(0.0); // Ensure video is muted
        _controller!.play();
      }

      // Speak the translated text
      await _tts.speak(_translatedText);
      setState(() {
        _status = "Dubbing completed in $_targetLanguage";
      });

      // Stop video when speech completes
      _tts.setCompletionHandler(() {
        if (_controller != null && _controller!.value.isPlaying) {
          _controller!.pause();
        }
      });
    } else {
      setState(() => _status = "No transcription available to translate");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Dubbing Screen")),
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
                        ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                        : Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: Center(child: Text("Video loading...")),
                        ),
              ),
              SizedBox(height: 20),
              // Start Dubbing Button
              ElevatedButton(
                onPressed: _isLoading ? null : _startDubbing,
                child: Text("Start Dubbing"),
              ),
              SizedBox(height: 20),
              // Language Selector
              DropdownButton<String>(
                value: _targetLanguage,
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
              SizedBox(height: 20),
              // Loading Indicator
              _isLoading ? CircularProgressIndicator() : SizedBox.shrink(),
              SizedBox(height: 10),
              Text(_status ?? "Select a language and start dubbing"),
            ],
          ),
        ),
      ),
    );
  }
}
