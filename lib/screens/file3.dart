import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioExtractor extends StatefulWidget {
  @override
  _AudioExtractorState createState() => _AudioExtractorState();
}

class _AudioExtractorState extends State<AudioExtractor> {
  String? _status;
  String? _selectedVideoPath; // Store the user-selected video path
  final String apiKey = '3f0c4c936d8967a82c25adb39ea47e15';

  // Request storage permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), use granular media permissions
      var videoStatus = await Permission.videos.request();
      var audioStatus = await Permission.audio.request();

      if (videoStatus.isGranted && audioStatus.isGranted) {
        print("Media permissions granted: videos=$videoStatus, audio=$audioStatus");
        return true;
      }

      // Fallback for older Android versions (API < 33)
      var storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) {
        print("Storage permission granted: $storageStatus");
        return true;
      }

      // Check if permissions are permanently denied
      if (storageStatus.isPermanentlyDenied || videoStatus.isPermanentlyDenied || audioStatus.isPermanentlyDenied) {
        setState(() => _status = "Permissions permanently denied. Please enable them in settings.");
        await openAppSettings(); // Open app settings for user to enable
        print("Permissions permanently denied. Opened settings.");
        return false;
      }

      setState(() => _status = "Storage permission denied: videos=$videoStatus, audio=$audioStatus, storage=$storageStatus");
      print("Permission denied: videos=$videoStatus, audio=$audioStatus, storage=$storageStatus");
      return false;
    } else if (Platform.isIOS) {
      // iOS typically doesn't need explicit storage permissions for app-specific directories
      print("Running on iOS, no storage permissions needed.");
      return true;
    }
    print("Running on non-Android/iOS platform, assuming permissions are granted.");
    return true;
  }

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
      print("Video selected: $_selectedVideoPath");
    } else {
      setState(() => _status = "No video selected");
      print("No video selected");
    }
  }

  // Convert video to MP3 using Convertio API
  Future<void> _convertVideoToMp3() async {
    if (_selectedVideoPath == null) {
      setState(() => _status = "Please select a video file first");
      print("No video path selected");
      return;
    }

    // Request permissions
    if (!await _requestPermissions()) {
      print("Permissions not granted, aborting conversion");
      return;
    }

    try {
      // Get temporary directory for output
      final Directory tempDir = await getTemporaryDirectory();
      print("Temporary directory: ${tempDir.path}");

      final String videoPath = _selectedVideoPath!; // Use user-selected path
      final String outputAudioPath = '${tempDir.path}/output_audio.mp3';
      final String filename = videoPath.split('/').last; // Use actual filename

      final File videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        setState(() => _status = "Video file not found at $videoPath");
        print("Video file does not exist: $videoPath");
        return;
      }

      print("Video file exists: $videoPath, size: ${await videoFile.length()} bytes");

      // Step 1: Start conversion job
      var startUrl = Uri.parse('https://api.convertio.co/convert');
      var startBody = jsonEncode({
        'apikey': apiKey,
        'input': 'upload',
        'outputformat': 'mp3',
        'filename': filename,
      });

      print("Starting conversion job with body: $startBody");
      var startResponse = await http.post(
        startUrl,
        headers: {'Content-Type': 'application/json'},
        body: startBody,
      );

      var startJson = jsonDecode(startResponse.body);
      print("Start response: $startJson");
      if (startJson['status'] != 'ok') {
        setState(() => _status = "Start failed: ${startJson['error']}");
        print("Start failed: ${startJson['error']}");
        return;
      }

      String conversionId = startJson['data']['id'];
      print("Conversion ID: $conversionId");

      // Step 2: Upload the video file
      var uploadUrl = Uri.parse('https://api.convertio.co/convert/$conversionId/$filename');
      var uploadRequest = http.Request('PUT', uploadUrl)
        ..headers['Content-Type'] = 'application/octet-stream'
        ..bodyBytes = await videoFile.readAsBytes();

      print("Uploading video to: $uploadUrl");
      var uploadResponse = await uploadRequest.send();
      var uploadBody = await uploadResponse.stream.bytesToString();
      var uploadJson = jsonDecode(uploadBody);

      print("Upload response: $uploadJson");
      if (uploadJson['status'] != 'ok') {
        setState(() => _status = "Upload failed: ${uploadJson['error']}");
        print("Upload failed: ${uploadJson['error']}");
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

        print("Status response: $statusJson");
        if (statusJson['status'] != 'ok') {
          setState(() => _status = "Status check failed: ${statusJson['error']}");
          print("Status check failed: ${statusJson['error']}");
          return;
        }

        step = statusJson['data']['step'];
        if (step == 'finish') {
          downloadUrl = statusJson['data']['output']['url'];
          print("Conversion finished, download URL: $downloadUrl");
          break;
        } else if (step == 'error') {
          setState(() => _status = "Conversion error: ${statusJson['data']['error']}");
          print("Conversion error: ${statusJson['data']['error']}");
          return;
        }
      }

      if (downloadUrl == null) {
        setState(() => _status = "Failed to retrieve download URL");
        print("Download URL is null");
        return;
      }

      // Step 4: Download the MP3 file
      var audioResponse = await http.get(Uri.parse(downloadUrl));
      final File audioFile = File(outputAudioPath);
      await audioFile.writeAsBytes(audioResponse.bodyBytes);

      print("Audio downloaded to: $outputAudioPath");
      setState(() => _status = "Audio extracted to: $outputAudioPath");
    } catch (e) {
      setState(() => _status = "Error: $e");
      print("Exception during conversion: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Extract MP3 with Convertio")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickVideoFile, // Button to select video
              child: Text("Select Video"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _convertVideoToMp3, // Button to convert
              child: Text("Convert to MP3"),
            ),
            SizedBox(height: 20),
            Text(_status ?? "Select a video and press Convert"),
          ],
        ),
      ),
    );
  }
}