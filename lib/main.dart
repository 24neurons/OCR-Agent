import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

// 1. GLOBAL CAMERA LIST INITIALIZATION
// This list holds the available cameras on the device.
late List<CameraDescription> _cameras;

Future<void> main() async {
  // Ensure that plugin services are initialized before using them.
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  try {
    _cameras = await availableCameras();
  } on CameraException catch (e) {
    // Handle error if no cameras are found or permissions are denied
    print('Error accessing cameras: $e');
    _cameras = []; // Set to empty if error occurs
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCR Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Pass the list of cameras to the home screen
      home: MyHomePage(title: 'OCR Scanner', cameras: _cameras),
    );
  }
}

// 2. MAIN OCR VIEW
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.cameras});

  final String title;
  final List<CameraDescription> cameras;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _imageFile;
  String _extractedText = 'Select an image or take a picture to begin OCR.';
  bool _isProcessing = false;
  String _translatedText = "Translation";
  bool _isTranslating = false;

  // --- Image Picking and Processing Logic ---

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      await _processImage(File(pickedFile.path));
    }
  }

  Future<void> _takePicture() async {
    // Check if any cameras are available
    if (widget.cameras.isEmpty) {
      setState(() {
        _extractedText = 'Error: No cameras available on this device.';
      });
      return;
    }

    // Navigate to the CameraScreen to capture the image
    final String? imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CameraScreen(camera: widget.cameras.first),
      ),
    );

    // If an image path is returned, process it
    if (imagePath != null) {
      await _processImage(File(imagePath));
    }
  }

  Future<void> _processImage(File image) async {
    setState(() {
      _imageFile = image;
      _extractedText = 'Processing image...';
      _isProcessing = true;
    });

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );
    // Dispose the recognizer to free up resources
    textRecognizer.close();

    setState(() {
      _extractedText = recognizedText.text.isEmpty
          ? 'Could not recognize any text.'
          : recognizedText.text;
      _isProcessing = false;
    });
  }

  Future<void> _translateText(String _extractedText) async {
    // Placeholder for future translation functionality
    setState(() {
      _translatedText = "Translated Text";
      _isTranslating = true;
    });

    // var _sourceLanguage = TranslateLanguage.english;
    // var _targetLanguage = TranslateLanguage.spanish;
    final TranslateLanguage sourceLanguage = TranslateLanguage.english;

    final TranslateLanguage targetLanguage = TranslateLanguage.spanish;

    final onDeviceTranslator = OnDeviceTranslator(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
    final String response = await onDeviceTranslator.translateText(
      _extractedText,
    );
    print(response);
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Image Display
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                height: 200,
                child: _imageFile == null
                    ? Center(
                        child: Text(
                          'No image selected.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(height: 30),

              // Button 1: Gallery
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Select from Gallery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 15),

              // Button 2: Camera
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Picture'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),

              // Button 3: Translate (Placeholder)
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () {
                        _translateText(_extractedText);
                      },
                icon: const Icon(Icons.translate),
                label: const Text('Translate Text'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 40),

              // Extracted Text Display
              const Text(
                'Extracted Text:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                constraints: const BoxConstraints(minHeight: 100),
                child: _isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : SelectableText(
                        _extractedText,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. SEPARATE CAMERA PREVIEW VIEW
class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the controller.
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    try {
      // Ensure the camera is initialized.
      await _initializeControllerFuture;

      // Attempt to take a picture.
      final image = await _controller.takePicture();

      if (!context.mounted) return;

      // Pop back to MyHomePage, passing the image path back as the result.
      Navigator.pop(context, image.path);
    } catch (e) {
      print('Error taking picture: $e');
      if (context.mounted) {
        // Show an error message before popping
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to take picture.')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a Picture')),
      // Use FutureBuilder to display the camera preview once initialized.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureImage,
        child: const Icon(Icons.camera),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
