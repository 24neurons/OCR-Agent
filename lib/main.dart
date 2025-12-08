import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:translator_plus/translator_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

// Import the service used for ChatGPT
import 'services/chatgpt_service.dart';

// IMPORT THÊM CHAT SCREEN
import 'chat_screen.dart'; // Assuming chat_screen.dart exists

// 1. GLOBAL CAMERA LIST INITIALIZATION
late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  try {
    _cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error accessing cameras: $e');
    _cameras = [];
  }

  runApp(const MyApp());

  // Example translator usage (can be removed if not needed)
  final translator = GoogleTranslator();
  final input = "Xin chao toi den tu Viet Nam";
  translator.translate(input, from: 'vi', to: 'en').then(print);
  var translation = await translator.translate(
    "Xin chào, tôi đến từ Việt Nam",
    to: 'en',
  );
  print(translation);
  print(await "example".translate(to: 'pt'));
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
      // Set MainTranslatorScreen as the home
      home: MainTranslatorScreen(cameras: _cameras),
    );
  }
}

// =========================================================================
// NEW: MainTranslatorScreen with Tabs (Google Translate Clone UI)
// =========================================================================
class MainTranslatorScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MainTranslatorScreen({super.key, required this.cameras});

  @override
  State<MainTranslatorScreen> createState() => _MainTranslatorScreenState();
}

class _MainTranslatorScreenState extends State<MainTranslatorScreen> {
  int _selectedIndex = 0;

  // Tab names for AppBar
  final List<String> _tabNames = [
    'Text Translation',
    'Image OCR',
    'Document Translation',
    'Website Translation',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabNames[_selectedIndex],
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onPrimary,
          ),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // 1. Text Tab (Functional)
          const TextTabContent(),
          // 2. Images Tab (Your existing MyHomePage for OCR)
          MyHomePage(title: 'OCR Scanner', cameras: widget.cameras),
          // 3. Documents Tab (Now functional with PDF extraction)
          const DocumentsTabContent(),
          // 4. Websites Tab (Placeholder)
          const WebsitesTabContent(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.text_fields),
            label: 'Text',
          ),
          NavigationDestination(
            icon: const Icon(Icons.image),
            label: 'Images',
          ),
          NavigationDestination(
            icon: const Icon(Icons.description),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: const Icon(Icons.language),
            label: 'Websites',
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// TextTabContent (FUNCTIONAL)
// =========================================================================

class TextTabContent extends StatefulWidget {
  const TextTabContent({super.key});

  @override
  State<TextTabContent> createState() => _TextTabContentState();
}

class _TextTabContentState extends State<TextTabContent> {
  final TextEditingController _inputController = TextEditingController();
  String _translatedText = 'Translation will appear here';
  bool _isTranslating = false;

  final translator = GoogleTranslator();

  // Language map (used to determine source/target languages)
  final Map<String, String> _languages = {
    'Detect language': 'auto', // Special code for auto-detection
    'English': 'en',
    'Vietnamese': 'vi',
    'Spanish': 'es',
    'French': 'fr',
  };

  String _sourceLanguageCode = 'auto';
  String _targetLanguageCode = 'en';

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _translateText() async {
    final inputText = _inputController.text;
    if (inputText.isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translatedText = 'Translating...';
    });

    try {
      final translation = await translator.translate(
        inputText,
        from: _sourceLanguageCode,
        to: _targetLanguageCode,
      );

      setState(() {
        _translatedText = translation.text;
        _isTranslating = false;
      });
    } catch (e) {
      print('Text Tab Translation Error: $e');
      setState(() {
        _translatedText = 'Error during translation. Check network/API status.';
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Helper to get the display name for the target language
    String getTargetName() {
      return _languages.entries
          .firstWhere(
            (e) => e.value == _targetLanguageCode,
            orElse: () => const MapEntry('Unknown', ''),
          )
          .key;
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // ...existing code...
                Card(
                  elevation: 0,
                  color: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Language Selectors (Top Row)
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Source Language Dropdown (Material 3 Style)
                              Flexible(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colorScheme.outline, width: 1),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                                    child: DropdownButton<String>(
                                      value: _sourceLanguageCode,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      icon: Icon(Icons.expand_more, size: 20, color: colorScheme.onSurfaceVariant),
                                      items: _languages.entries.map((entry) {
                                        return DropdownMenuItem<String>(
                                          value: entry.value,
                                          child: Text(
                                            entry.key,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _sourceLanguageCode = newValue!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Icon(Icons.arrow_forward_ios, size: 18, color: colorScheme.primary),
                              ),

                              // Target Language Dropdown (Material 3 Style)
                              Flexible(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colorScheme.primary, width: 1.5),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                                    child: DropdownButton<String>(
                                      value: _targetLanguageCode,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      icon: Icon(Icons.expand_more, size: 20, color: colorScheme.primary),
                                      items: _languages.entries
                                          .where((e) => e.key != 'Detect language')
                                          .map((entry) {
                                            return DropdownMenuItem<String>(
                                              value: entry.value,
                                              child: Text(
                                                entry.key,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: colorScheme.primary,
                                                ),
                                              ),
                                            );
                                          })
                                          .toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _targetLanguageCode = newValue!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Divider
                        // Divider(color: colorScheme.outlineVariant, height: 1, thickness: 1),

                        // Input Box with SingleChildScrollView
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            height: 180,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.outlineVariant, width: 1),
                                borderRadius: BorderRadius.circular(10),
                                color: colorScheme.surface,
                              ),
                              padding: const EdgeInsets.all(12.0),
                              child: SingleChildScrollView(
                                child: TextField(
                                  controller: _inputController,
                                  maxLines: null,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onSurface,
                                    height: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Nhập văn bản để dịch...',
                                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ===== BUTTON ROW: PASTE, MICROPHONE, TRANSLATE =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Paste Button (Material 3 OutlinedButton)
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement paste functionality
                      },
                      icon: Icon(Icons.content_paste, size: 20, color: colorScheme.onSurfaceVariant),
                      label: Text(
                        'Paste',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    // Microphone Button (Material 3 Style - Circular)
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          // TODO: Implement microphone functionality
                        },
                        icon: Icon(Icons.mic, size: 24, color: colorScheme.primary),
                        constraints: const BoxConstraints(
                          minWidth: 60,
                          minHeight: 60,
                        ),
                        padding: const EdgeInsets.all(0),
                      ),
                    ),

                    // Translation Button (Material 3 FilledButton)
                    FilledButton.icon(
                      onPressed: _isTranslating || _inputController.text.isEmpty
                          ? null
                          : _translateText,
                      icon: _isTranslating
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : Icon(Icons.translate, size: 20),
                      label: Text(
                        'Translate',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ===== OUTPUT TEXT BOX (OUTSIDE CARD) =====
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outlineVariant, width: 1),
                        borderRadius: BorderRadius.circular(10),
                        color: colorScheme.surface,
                      ),
                      padding: const EdgeInsets.all(12.0),
                      child: _isTranslating
                          ? Center(
                              child: CircularProgressIndicator(
                                color: colorScheme.primary,
                              ),
                            )
                          : SingleChildScrollView(
                              child: SelectableText(
                                _translatedText,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.onSurface,
                                  height: 1.5,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

    );
  }
}

// =========================================================================
// DocumentsTabContent (Functional with PDF extraction and PDF creation)
// =========================================================================
class DocumentsTabContent extends StatefulWidget {
  const DocumentsTabContent({super.key});

  @override
  State<DocumentsTabContent> createState() => _DocumentsTabContentState();
}

class _DocumentsTabContentState extends State<DocumentsTabContent> {
  String _documentStatus = 'Upload a document for translation (e.g., PDF).';
  String _extractedText = '';
  String _sourceFileName = '';
  bool _isProcessing = false;
  bool _isTranslating = false;
  final translator = GoogleTranslator();
  final ChatGPTService _chatGPTService =
      ChatGPTService(); // NEW: For summarization

  // Language map
  final Map<String, String> _languages = {
    'Vietnamese': 'vi',
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Japanese': 'ja',
  };

  String _selectedTargetLanguageCode = 'en'; // Default target

  // Helper function to find the language name from its code
  String _getLanguageName(String code) {
    return _languages.entries
        .firstWhere(
          (entry) => entry.value == code,
          orElse: () => const MapEntry('Unknown', ''),
        )
        .key;
  }

  // NEW: Layout processing function
  List<String> _processTextForLayout(String rawText) {
    return rawText
        .split(RegExp(r'\n\s*\n'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  Future<void> _pickDocumentFile() async {
    setState(() {
      _documentStatus = 'Opening file picker...';
      _isProcessing = true;
      _extractedText = '';
      _sourceFileName = '';
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      final fileName = result.files.single.name;

      if (fileName.toLowerCase().endsWith('.pdf')) {
        setState(() {
          _sourceFileName = fileName;
          _documentStatus = 'Extracting text from PDF: $fileName';
        });
        await _extractTextFromPdf(pickedFile);
      } else {
        setState(() {
          _documentStatus = 'Please select a PDF file.';
          _isProcessing = false;
        });
      }
    } else {
      setState(() {
        _documentStatus = 'File selection canceled.';
        _isProcessing = false;
      });
    }
  }

  // --- Core PDF Text Extraction Function ---
  Future<void> _extractTextFromPdf(File pdfFile) async {
    try {
      final List<int> bytes = await pdfFile.readAsBytes();
      final syncfusion.PdfDocument document = syncfusion.PdfDocument(
        inputBytes: bytes,
      );
      final syncfusion.PdfTextExtractor extractor = syncfusion.PdfTextExtractor(
        document,
      );
      final String text = extractor.extractText();
      document.dispose();

      setState(() {
        _extractedText = text.isEmpty ? '' : text;
        _isProcessing = false;
      });

      if (!text.isEmpty) {
        await _translateExtractedText(text);
      } else {
        setState(() {
          _documentStatus = 'No readable text found in the PDF.';
        });
      }
    } catch (e) {
      print('PDF Extraction Error: $e');
      setState(() {
        _documentStatus = 'Error processing PDF.';
        _isProcessing = false;
      });
    }
  }

  // --- Translation and PDF Creation Logic ---
  Future<void> _translateExtractedText(String textToTranslate) async {
    setState(() {
      _documentStatus =
          'Translating content to ${_getLanguageName(_selectedTargetLanguageCode)}...';
      _isTranslating = true;
    });

    try {
      final sourceParagraphs = _processTextForLayout(textToTranslate);

      final List<String> translatedParagraphs = [];
      for (final paragraph in sourceParagraphs) {
        final translation = await translator.translate(
          paragraph,
          to: _selectedTargetLanguageCode,
        );
        translatedParagraphs.add(translation.text);
      }

      await _createAndSaveTranslatedPdf(
        translatedParagraphs,
        _selectedTargetLanguageCode,
      );

      setState(() {
        _isTranslating = false;
      });
    } catch (e) {
      print('Document Translation error: $e');
      setState(() {
        _documentStatus = "Error during translation.";
        _isTranslating = false;
      });
    }
  }

  // --- Function to Create and Save the Translated PDF (SIMPLIFIED) ---
  Future<void> _createAndSaveTranslatedPdf(
    List<String> translatedParagraphs,
    String langCode,
  ) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            List<pw.Widget> content = [
              pw.Text(
                'Translated Document (${_getLanguageName(langCode)})',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
            ];

            for (final paragraph in translatedParagraphs) {
              content.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Text(
                    paragraph,
                    style: const pw.TextStyle(fontSize: 12),
                    textAlign: pw.TextAlign.justify,
                  ),
                ),
              );
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: content,
            );
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${_sourceFileName}_translated_${langCode}.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        setState(() {
          _documentStatus = 'Translation Complete! File saved to: ${file.path}';
        });

        await OpenFilex.open(file.path);
      }
    } catch (e) {
      print('PDF Creation/Save Error: $e');
      if (mounted) {
        setState(() {
          _documentStatus = 'Error saving the translated file.';
        });
      }
    }
  }

  // --- NEW: Summarization Logic ---
  Future<void> _summarizeText() async {
    if (_extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload and extract text from a document first.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _documentStatus = 'Requesting summary from AI...';
      _isTranslating = true;
    });

    try {
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content':
              'You are an expert summarization bot. Provide a concise, three-sentence summary of the user\'s input text.',
        },
        {'role': 'user', 'content': _extractedText},
      ];

      final summary = await _chatGPTService.sendChat(messages);

      if (mounted) {
        setState(() {
          _documentStatus = 'Summary Complete.';
          _isTranslating = false;
        });

        // Display summary in an alert dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Document Summary (AI)'),
            content: SingleChildScrollView(child: Text(summary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Summarization Error: $e');
      if (mounted) {
        setState(() {
          _documentStatus = 'Error generating summary.';
          _isTranslating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get summary. Check your API key.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool aiActionsDisabled =
        _isProcessing || _isTranslating || _extractedText.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 50),
          const Icon(Icons.description, size: 80, color: Colors.blueGrey),
          const SizedBox(height: 20),

          // Source File Name Display
          if (_sourceFileName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(
                _sourceFileName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Status Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              _documentStatus,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 20),

          // Browse Button
          ElevatedButton(
            onPressed: _isProcessing || _isTranslating
                ? null
                : _pickDocumentFile,
            child: Text(
              _isProcessing ? 'Processing...' : 'Browse your computer',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              foregroundColor: Colors.black54,
              backgroundColor: Colors.grey.shade200,
            ),
          ),

          const SizedBox(height: 40),

          // Language Selector and Translate Button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedTargetLanguageCode,
                      icon: const Icon(Icons.arrow_drop_down),
                      elevation: 16,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedTargetLanguageCode = newValue;
                            if (_extractedText.isNotEmpty &&
                                !aiActionsDisabled) {
                              _translateExtractedText(_extractedText);
                            } else {
                              _documentStatus =
                                  'Target language set to ${_getLanguageName(newValue)}.';
                            }
                          });
                        }
                      },
                      items: _languages.entries.map<DropdownMenuItem<String>>((
                        MapEntry<String, String> entry,
                      ) {
                        return DropdownMenuItem<String>(
                          value: entry.value,
                          child: Text(
                            'Translate to: ${entry.key}',
                            style: const TextStyle(color: Colors.black),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Translate Button
              ElevatedButton.icon(
                onPressed: aiActionsDisabled
                    ? null
                    : () {
                        _translateExtractedText(_extractedText);
                      },
                icon: _isTranslating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.translate),
                label: Text(_isTranslating ? 'Translating...' : 'Translate'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 15,
                  ),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // --- NEW AI AGENT BUTTONS ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Summarize Button
              ElevatedButton.icon(
                onPressed: aiActionsDisabled ? null : _summarizeText,
                icon: const Icon(Icons.notes),
                label: const Text('Summarize'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),

              // Chat with AI (Contextual Chat) Button
              ElevatedButton.icon(
                onPressed: aiActionsDisabled
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ChatScreen(documentContext: _extractedText),
                          ),
                        );
                      },
                icon: const Icon(Icons.smart_toy),
                label: const Text('Chat with AI'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}

class WebsitesTabContent extends StatelessWidget {
  const WebsitesTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.language, size: 80, color: Colors.blueGrey),
          const SizedBox(height: 20),
          const Text(
            'Translate an entire webpage.',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
              hintText: 'Enter URL',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.translate),
                onPressed: () {
                  // Implement website translation logic
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButton<String>(
            value: 'en', // Default value
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'vi', child: Text('Vietnamese')),
            ],
            onChanged: (value) {},
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// MyHomePage (Images tab: OCR, Translation, File Picker)
// =========================================================================

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
  final translator = GoogleTranslator();
  final ChatGPTService _chatGPTService =
      ChatGPTService(); // NEW: For summarization

  // --- Language Selection Variables ---
  final Map<String, String> _languages = {
    'Vietnamese': 'vi',
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Japanese': 'ja',
  };

  String _selectedTargetLanguageCode = 'vi';

  // Helper function to find the language name from its code
  String _getLanguageName(String code) {
    return _languages.entries
        .firstWhere(
          (entry) => entry.value == code,
          orElse: () => const MapEntry('Unknown', ''),
        )
        .key;
  }

  // --- Image Picking and Processing Logic ---

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      await _processImage(File(pickedFile.path));
    }
  }

  // Function for System File Picker (restricted to images)
  Future<void> _pickFileFromSystem() async {
    final result = await FilePicker.platform.pickFiles(
      // CRITICAL: We restrict to image files for OCR functionality
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'tiff'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      await _processImage(pickedFile);
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
      _translatedText = "Translation"; // Reset translation
    });

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );
    textRecognizer.close();

    setState(() {
      _extractedText = recognizedText.text.isEmpty
          ? 'Could not recognize any text.'
          : recognizedText.text;
      print("OCR Raw Output: $_extractedText");
      _extractedText = _extractedText.replaceAll('\n', ' ');
      print("OCR Processed Output: $_extractedText");
      _isProcessing = false;
    });
  }

  // --- Translation Logic (WITH DEBUGGING PRINTS) ---
  Future<void> _translateText(String extractedText) async {
    // 1. Input Validation Check
    if (extractedText.isEmpty ||
        extractedText.contains('Select an image') ||
        extractedText.contains('Could not recognize')) {
      setState(() {
        _translatedText = "No valid text to translate (Validation failed).";
      });
      print("DEBUG: Translation skipped due to invalid input.");
      return;
    }

    // 2. Start Translation State
    setState(() {
      _translatedText =
          "Translating to ${_getLanguageName(_selectedTargetLanguageCode)}...";
      _isTranslating = true;
    });

    print('DEBUG: Input Text for Translation: $extractedText');
    print('DEBUG: Target Language Code: $_selectedTargetLanguageCode');

    try {
      // 3. Perform Translation
      var google_translation = await translator.translate(
        extractedText,
        to: _selectedTargetLanguageCode,
      );

      String resultText = google_translation.text;

      print('DEBUG: Translation API Result: $resultText');

      // 4. Update State with Result
      setState(() {
        if (resultText.isEmpty) {
          _translatedText = "Translation failed: API returned empty string.";
        } else {
          _translatedText = resultText;
        }
        _isTranslating = false;
      });
    } catch (e) {
      // 5. Handle Network/API Error
      print('ERROR: Translation error caught: $e');
      setState(() {
        _translatedText =
            "Error during translation. Check console for details (Network/API issue).";
        _isTranslating = false;
      });
    }
  }

  // --- NEW: Summarization Logic ---
  Future<void> _summarizeText() async {
    if (_extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please perform OCR or upload an image first.'),
        ),
      );
      return;
    }

    setState(() {
      _translatedText =
          'Requesting summary from AI...'; // Using translation box for status
      _isTranslating = true;
    });

    try {
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content':
              'You are an expert summarization bot. Provide a concise, three-sentence summary of the user\'s input text.',
        },
        {'role': 'user', 'content': _extractedText},
      ];

      final summary = await _chatGPTService.sendChat(messages);

      if (mounted) {
        setState(() {
          _translatedText = summary;
          _isTranslating = false;
        });

        // Display summary in an alert dialog (more appropriate for a separate action)
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Image Text Summary (AI)'),
            content: SingleChildScrollView(child: Text(summary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Summarization Error: $e');
      if (mounted) {
        setState(() {
          _translatedText =
              'Error generating summary. Check your API key or network.';
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool aiActionsDisabled =
        _isProcessing || _isTranslating || _extractedText.isEmpty;

    return Scaffold(
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

              const SizedBox(height: 15),

              // NEW BUTTON: Upload File (System Picker for Images)
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickFileFromSystem,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Image File (System Picker)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 15),

              // Language Selector and Translate Button in a Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedTargetLanguageCode,
                          icon: const Icon(Icons.arrow_drop_down),
                          elevation: 16,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedTargetLanguageCode = newValue;
                                _translatedText = "Translation target changed.";
                              });
                            }
                          },
                          items: _languages.entries
                              .map<DropdownMenuItem<String>>((
                                MapEntry<String, String> entry,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: entry.value,
                                  child: Text(
                                    'Translate to: ${entry.key}',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Button 3: Translate
                  ElevatedButton.icon(
                    onPressed: _isProcessing || _isTranslating
                        ? null
                        : () {
                            _translateText(_extractedText);
                          },
                    icon: _isTranslating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.translate),
                    label: Text(
                      _isTranslating ? 'Translating...' : 'Translate',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 15,
                      ),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
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

              const SizedBox(height: 20),

              // Translated Text Display
              const Text(
                'Translated Text:',
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
                child: _isTranslating
                    ? const Center(child: CircularProgressIndicator())
                    : SelectableText(
                        _translatedText,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),

              const SizedBox(height: 30),

              // --- NEW AI AGENT BUTTONS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Summarize Button
                  ElevatedButton.icon(
                    onPressed: aiActionsDisabled ? null : _summarizeText,
                    icon: const Icon(Icons.notes),
                    label: const Text('Summarize'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),

                  // Chat with AI (Contextual Chat) Button
                  ElevatedButton.icon(
                    onPressed: aiActionsDisabled
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ChatScreen(documentContext: _extractedText),
                              ),
                            );
                          },
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('Chat with AI'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              // --- END NEW AI AGENT BUTTONS ---
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// CAMERA PREVIEW VIEW (Unchanged)
// =========================================================================

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
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      if (!context.mounted) return;
      Navigator.pop(context, image.path);
    } catch (e) {
      print('Error taking picture: $e');
      if (context.mounted) {
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
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
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
