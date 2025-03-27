import 'dart:io';
import 'dart:developer' as devtools;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? filePath;
  String label = '';
  double confidence = 0.0;
  Interpreter? _interpreter;



  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      var inputShape = _interpreter!.getInputTensor(0).shape;
      devtools.log("Model Input Shape: $inputShape"); // Print expected shape
    } catch (e) {
      devtools.log("Error loading model: $e");
    }
  }


  Future<void> _runModel(File imageFile) async {
    if (_interpreter == null) return;

    const inputSize = 224;
    const numChannels = 3;
    final classLabels = await _loadLabels();

    try {
      final image = img.decodeImage(await imageFile.readAsBytes())!;
      final resizedImage = img.copyResize(image, width: inputSize, height: inputSize);

      final inputBuffer = Float32List(1 * inputSize * inputSize * numChannels);

      var pixelIndex = 0;
      for (var y = 0; y < inputSize; y++) {
        for (var x = 0; x < inputSize; x++) {
          final pixel = resizedImage.getPixel(x, y);
          inputBuffer[pixelIndex++] = (pixel.r / 127.5) - 1.0;
          inputBuffer[pixelIndex++] = (pixel.g / 127.5) - 1.0;
          inputBuffer[pixelIndex++] = (pixel.b / 127.5) - 1.0;
        }
      }

      final input = inputBuffer.reshape([1, inputSize, inputSize, numChannels]);

      // Fixed output buffer initialization
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final outputBuffer = List<double>.filled(
        outputShape[0] * outputShape[1],
        0.0,
      ).reshape(outputShape);

      _interpreter!.run(input, outputBuffer);

      // Type-annotated processing
      final predictions = outputBuffer[0] as List<double>;
      final maxConfidence = predictions.reduce((double a, double b) => a > b ? a : b);
      final predictedIndex = predictions.indexOf(maxConfidence);

      setState(() {
        confidence = maxConfidence * 100;
        label = classLabels[predictedIndex];
      });

    } catch (e) {
      print('Error during inference: $e');
      setState(() {
        label = 'Prediction failed';
        confidence = 0.0;
      });
    }
  }
// Load labels from assets
  Future<List<String>> _loadLabels() async {
    try {
      return await rootBundle.loadString('assets/labels.txt')
          .then((text) => text.split('\n'));
    } catch (e) {
      return List.generate(7, (i) => 'Class $i'); // Fallback
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    var imageMap = File(image.path);
    setState(() {
      filePath = imageMap;
    });

    await _runModel(imageMap);
  }

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mango Dresses Detection")),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Card(
                elevation: 20,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      Container(
                        height: 280,
                        width: 280,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          image: const DecorationImage(
                            image: AssetImage('assets/upload.png'),
                          ),
                        ),
                        child: filePath == null
                            ? const Text('')
                            : Image.file(
                          filePath!,
                          fit: BoxFit.fill,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "The Accuracy is ${confidence.toStringAsFixed(0)}%",
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _pickImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  foregroundColor: Colors.black,
                ),
                child: const Text("Take a Photo"),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _pickImage(ImageSource.gallery),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  foregroundColor: Colors.black,
                ),
                child: const Text("Pick from gallery"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
