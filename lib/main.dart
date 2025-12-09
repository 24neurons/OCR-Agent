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
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

import 'services/chatgpt_service.dart';
import 'chat_screen.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    _cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error accessing cameras: $e');
    _cameras = [];
  }

  runApp(const MyApp());

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
      home: MainTranslatorScreen(cameras: _cameras),
    );
  }
}

// ===================================================================
// MAIN SCREEN WITH 4 TABS
// ===================================================================

class MainTranslatorScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MainTranslatorScreen({super.key, required this.cameras});

  @override
  State<MainTranslatorScreen> createState() => _MainTranslatorScreenState();
}

class _MainTranslatorScreenState extends State<MainTranslatorScreen> {
  int _selectedIndex = 0;

  final List<String> _tabNames = [
    'Text Translation',
    'Image OCR',
    'Document Translation',
    'Scan to PDF',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabNames[_selectedIndex],
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const TextTabContent(), // 1. Text
          MyHomePage(title: 'OCR Scanner', cameras: widget.cameras), // 2. Images
          const DocumentsTabContent(), // 3. Documents
          const ScanPdfTabContent(), // 4. Scan to PDF (mới)
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.text_fields),
            label: 'Text',
          ),
          NavigationDestination(icon: Icon(Icons.image), label: 'Images'),
          NavigationDestination(
            icon: Icon(Icons.description),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: Icon(Icons.picture_as_pdf),
            label: 'Scan PDF',
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// TEXT TAB
// ===================================================================

class TextTabContent extends StatefulWidget {
  const TextTabContent({super.key});

  @override
  State<TextTabContent> createState() => _TextTabContentState();
}

class _TextTabContentState extends State<TextTabContent> {
  final TextEditingController _inputController = TextEditingController();
  String _translatedText = 'Translation will appear here';
  bool _isTranslating = false;

  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _recognizedText = '';

  final translator = GoogleTranslator();

  final Map<String, String> _languages = {
    'Detect language': 'auto',
    'English': 'en',
    'Vietnamese': 'vi',
    'Spanish': 'es',
    'French': 'fr',
  };

  String _sourceLanguageCode = 'auto';
  String _targetLanguageCode = 'en';

  @override
  void initState() {
    super.initState();
    _initSpeechToText();
  }

  Future<void> _initSpeechToText() async {
    _speechToText = stt.SpeechToText();
    bool available = await _speechToText.initialize(
      onError: (error) {
        print('Speech to text error: $error');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${error.errorMsg}')));
      },
      onStatus: (status) {
        print('Speech to text status: $status');
      },
    );
    if (!available) {
      print('Speech to text not available');
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    super.dispose();
  }

  void _startListening() async {
    if (!_isListening && _speechToText.isAvailable) {
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });

      _speechToText.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
            if (result.finalResult) {
              _inputController.text +=
                  (_inputController.text.isEmpty ? '' : ' ') + _recognizedText;
              _isListening = false;
              _recognizedText = '';
            }
          });
        },
        localeId: _sourceLanguageCode == 'auto' ? 'en_US' : _sourceLanguageCode,
      );
    }
  }

  void _stopListening() async {
    if (_isListening) {
      _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  void _pasteFromClipboard() async {
    try {
      final ClipboardData? data = await Clipboard.getData('text/plain');
      if (data != null && data.text != null) {
        setState(() {
          _inputController.text = data.text!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text pasted successfully')),
        );
      }
    } catch (e) {
      print('Paste error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to paste text')));
    }
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 14.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colorScheme.outline,
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 4.0,
                                  ),
                                  child: DropdownButton<String>(
                                    value: _sourceLanguageCode,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    icon: Icon(
                                      Icons.expand_more,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                            ),
                            Flexible(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 4.0,
                                  ),
                                  child: DropdownButton<String>(
                                    value: _targetLanguageCode,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    icon: Icon(
                                      Icons.expand_more,
                                      size: 20,
                                      color: colorScheme.primary,
                                    ),
                                    items: _languages.entries
                                        .where(
                                          (e) => e.key != 'Detect language',
                                    )
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
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          height: 180,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                                width: 1,
                              ),
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
                                  hintStyle: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: Icon(
                      Icons.content_paste,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
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
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        if (_isListening) {
                          _stopListening();
                        } else {
                          _startListening();
                        }
                      },
                      icon: Icon(
                        _isListening ? Icons.mic_off : Icons.mic,
                        size: 24,
                        color: colorScheme.primary,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 60,
                        minHeight: 60,
                      ),
                      padding: const EdgeInsets.all(0),
                    ),
                  ),
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
                        : const Icon(Icons.translate, size: 20),
                    label: const Text(
                      'Translate',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
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

// ===================================================================
// DOCUMENTS TAB (NGUYÊN BẢN – GIỮ NGUYÊN CODE CỦA BẠN)
// ===================================================================

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
  final ChatGPTService _chatGPTService = ChatGPTService();

  final Map<String, String> _languages = {
    'Vietnamese': 'vi',
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Japanese': 'ja',
  };

  String _selectedTargetLanguageCode = 'en';

  String _getLanguageName(String code) {
    return _languages.entries
        .firstWhere(
          (entry) => entry.value == code,
      orElse: () => const MapEntry('Unknown', ''),
    )
        .key;
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

  Future<void> _extractTextFromPdf(File pdfFile) async {
    try {
      final List<int> bytes = await pdfFile.readAsBytes();
      final syncfusion.PdfDocument document = syncfusion.PdfDocument(
        inputBytes: bytes,
      );
      final syncfusion.PdfTextExtractor extractor =
      syncfusion.PdfTextExtractor(document);
      final String text = extractor.extractText();
      document.dispose();

      setState(() {
        _extractedText = text.isEmpty ? '' : text;
        _isProcessing = false;
      });

      if (text.isNotEmpty) {
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

  Future<void> _translateExtractedText(String textToTranslate) async {
    setState(() {
      _documentStatus =
      'Translating content to ${_getLanguageName(_selectedTargetLanguageCode)}...';
      _isTranslating = true;
    });

    try {
      final sourceParagraphs = textToTranslate
          .split(RegExp(r'\n\s*\n'))
          .where((s) => s.trim().isNotEmpty)
          .toList();

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

  Future<void> _createAndSaveTranslatedPdf(
      List<String> translatedParagraphs,
      String langCode,
      ) async {
    try {
      final pdf = pw.Document();

      pw.Font ttf = pw.Font.courier();
      try {
        final fontData = await rootBundle.load("assets/fonts/Roboto.ttf");
        ttf = pw.Font.ttf(fontData);
      } catch (e) {
        print(
          'FONT LOAD ERROR: Could not load Roboto.ttf. Using default Courier font.',
        );
      }

      final customTextStyle = pw.TextStyle(
        font: ttf,
        fontSize: 12,
        lineSpacing: 1.5,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            List<pw.Widget> content = [
              pw.Text(
                'Translated Document (${_getLanguageName(langCode)})',
                style: pw.TextStyle(
                  font: ttf,
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
                    style: customTextStyle,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              _documentStatus,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed:
            _isProcessing || _isTranslating ? null : _pickDocumentFile,
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
                      items: _languages.entries.map<DropdownMenuItem<String>>(
                            (MapEntry<String, String> entry) {
                          return DropdownMenuItem<String>(
                            value: entry.value,
                            child: Text(
                              'Translate to: ${entry.key}',
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
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

// ===================================================================
// NEW TAB: SCAN TO PDF (THAY CHO WEBSITE)
// ===================================================================

class ScanPdfTabContent extends StatefulWidget {
  const ScanPdfTabContent({super.key});

  @override
  State<ScanPdfTabContent> createState() => _ScanPdfTabContentState();
}

class _ScanPdfTabContentState extends State<ScanPdfTabContent> {
  dynamic _scannedDocuments;
  bool _isScanning = false;
  String _status = 'Scan documents to create a PDF.';

  Future<void> _scanDocumentAsPdf() async {
    setState(() {
      _isScanning = true;
      _status = 'Opening scanner...';
    });

    dynamic scannedDocuments;

    try {
      scannedDocuments =
      await FlutterDocScanner().getScannedDocumentAsPdf(page: 4);

      if (!mounted) return;

      if (scannedDocuments == null) {
        setState(() {
          _isScanning = false;
          _status = 'Scan was cancelled.';
          _scannedDocuments = null;
        });
        return;
      }

      String? pdfUri;
      int? pageCount;

      if (scannedDocuments is Map) {
        pdfUri = scannedDocuments['pdfUri'] as String?;
        pageCount = scannedDocuments['pageCount'] as int?;
      }

      if (pdfUri == null) {
        setState(() {
          _isScanning = false;
          _status = 'Scan finished but no pdfUri was returned.';
          _scannedDocuments = scannedDocuments;
        });
        return;
      }

      final pdfPath = Uri.parse(pdfUri).path;

      await OpenFilex.open(pdfPath);

      setState(() {
        _isScanning = false;
        _scannedDocuments = scannedDocuments;
        _status = 'Scan complete';
      });
    } on PlatformException catch (e) {
      setState(() {
        _isScanning = false;
        _status = 'Failed to scan: ${e.message ?? e.code}';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _status = 'Unexpected error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.picture_as_pdf, size: 80, color: Colors.blueGrey),
          const SizedBox(height: 20),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _scanDocumentAsPdf,
            icon: _isScanning
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.document_scanner),
            label: Text(_isScanning ? 'Scanning...' : 'Scan Documents As PDF'),
            style: ElevatedButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// IMAGES TAB (MyHomePage) – GIỮ NGUYÊN
// ===================================================================

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.cameras});

  final String title;
  final List<CameraDescription> cameras;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isProcessing = false;

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      await _processAndNavigate(File(pickedFile.path));
    }
  }

  Future<void> _pickFileFromSystem() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'tiff'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      await _processAndNavigate(pickedFile);
    }
  }

  Future<void> _takePicture() async {
    if (widget.cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cameras available on this device.')),
      );
      return;
    }

    final String? imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CameraScreen(camera: widget.cameras.first),
      ),
    );

    if (imagePath != null) {
      await _processAndNavigate(File(imagePath));
    }
  }

  Future<void> _processAndNavigate(File image) async {
    setState(() {
      _isProcessing = true;
    });

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText =
    await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    String extractedText = recognizedText.text.isEmpty
        ? 'Could not recognize any text.'
        : recognizedText.text.replaceAll('\n', ' ');

    setState(() {
      _isProcessing = false;
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ImageResultScreen(imageFile: image, extractedText: extractedText),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                Icons.image_search,
                size: 100,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 20),
              Text(
                'Image OCR Scanner',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Select an image or take a picture to extract text',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('Processing image...'),
                    ],
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickImageFromGallery,
                icon: const Icon(Icons.photo_library, size: 24),
                label: const Text(
                  'Select from Gallery',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _takePicture,
                icon: const Icon(Icons.camera_alt, size: 24),
                label: const Text(
                  'Take Picture',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickFileFromSystem,
                icon: const Icon(Icons.upload_file, size: 24),
                label: const Text(
                  'Upload Image File',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

// ===================================================================
// IMAGE RESULT SCREEN
// ===================================================================

class ImageResultScreen extends StatefulWidget {
  final File imageFile;
  final String extractedText;

  const ImageResultScreen({
    super.key,
    required this.imageFile,
    required this.extractedText,
  });

  @override
  State<ImageResultScreen> createState() => _ImageResultScreenState();
}

class _ImageResultScreenState extends State<ImageResultScreen> {
  late String _extractedText;
  String _translatedText = "Translation";
  bool _isTranslating = false;
  final translator = GoogleTranslator();
  final ChatGPTService _chatGPTService = ChatGPTService();

  final Map<String, String> _languages = {
    'Vietnamese': 'vi',
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Japanese': 'ja',
  };

  String _selectedTargetLanguageCode = 'vi';

  @override
  void initState() {
    super.initState();
    _extractedText = widget.extractedText;
  }

  String _getLanguageName(String code) {
    return _languages.entries
        .firstWhere(
          (entry) => entry.value == code,
      orElse: () => const MapEntry('Unknown', ''),
    )
        .key;
  }

  Future<void> _translateText(String extractedText) async {
    if (extractedText.isEmpty ||
        extractedText.contains('Could not recognize')) {
      setState(() {
        _translatedText = "No valid text to translate.";
      });
      return;
    }

    setState(() {
      _translatedText =
      "Translating to ${_getLanguageName(_selectedTargetLanguageCode)}...";
      _isTranslating = true;
    });

    try {
      var googleTranslation = await translator.translate(
        extractedText,
        to: _selectedTargetLanguageCode,
      );

      String resultText = googleTranslation.text;

      setState(() {
        if (resultText.isEmpty) {
          _translatedText = "Translation failed: API returned empty string.";
        } else {
          _translatedText = resultText;
        }
        _isTranslating = false;
      });
    } catch (e) {
      print('ERROR: Translation error caught: $e');
      setState(() {
        _translatedText = "Error during translation. Please try again.";
        _isTranslating = false;
      });
    }
  }

  Future<void> _summarizeText() async {
    if (_extractedText.isEmpty ||
        _extractedText.contains('Could not recognize')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid text to summarize.')),
      );
      return;
    }

    setState(() {
      _translatedText = 'Requesting summary from AI...';
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
          _translatedText = 'Error generating summary. Check your API key.';
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool aiActionsDisabled =
        _isTranslating ||
            _extractedText.isEmpty ||
            _extractedText.contains('Could not recognize');

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Result'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(widget.imageFile, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),
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
                        style: TextStyle(color: Theme.of(context).primaryColor),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedTargetLanguageCode = newValue;
                              _translatedText = "Translation target changed.";
                            });
                          }
                        },
                        items: _languages.entries
                            .map<DropdownMenuItem<String>>(
                              (MapEntry<String, String> entry) {
                            return DropdownMenuItem<String>(
                              value: entry.value,
                              child: Text(
                                'Translate to: ${entry.key}',
                                style: const TextStyle(color: Colors.black),
                              ),
                            );
                          },
                        ).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isTranslating
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
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
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
            const SizedBox(height: 30),
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
              child: SelectableText(
                _extractedText,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// CAMERA SCREEN
// ===================================================================

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
