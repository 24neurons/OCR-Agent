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
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
// ĐÃ XÓA: import 'package:google_mlkit_translation/google_mlkit_translation.dart';

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
          // 4. Websites Tab (Functional)
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
// TextTabContent (SỬ DỤNG translator_plus VÀ AUTO DETECT & RETRY)
// =========================================================================

class TextTabContent extends StatefulWidget {
  const TextTabContent({super.key});

  @override
  State<TextTabContent> createState() => _TextTabContentState();
}

class _TextTabContentState extends State<TextTabContent> {
  final TextEditingController _inputController = TextEditingController();
  String _translatedContent = 'Translation will appear here';
  bool _isTranslating = false;

  // Speech to text variables
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _recognizedText = '';

  final translator = GoogleTranslator();

  // Language map (Chỉ liệt kê ngôn ngữ đích)
  final Map<String, String> _languages = {
    'Vietnamese': 'vi',
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
  };

  // Nguồn sẽ được tự động phát hiện (auto-detect)
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${error.errorMsg}')),
        );
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
              _inputController.text += (_inputController.text.isEmpty ? '' : ' ') + _recognizedText;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to paste text')),
      );
    }
  }

  Future<void> _translateText() async {
    final inputText = _inputController.text;
    if (inputText.isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translatedContent = 'Translating...';
    });

    // BẮT ĐẦU CƠ CHẾ THỬ LẠI
    const int maxRetries = 3;
    const Duration delay = Duration(milliseconds: 700);

    String resultText = 'Error during translation via translator_plus.';
    bool success = false;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final translation = await translator.translate(
          inputText,
          // Bỏ qua tham số 'from' để kích hoạt Auto Detect
          to: _targetLanguageCode,
        );
        resultText = translation.text;
        success = true;
        break; // Thành công! Thoát vòng lặp thử lại
      } catch (e) {
        print(
          'Text Translation attempt ${attempt + 1} failed. Retrying in 700ms...',
        );
        await Future.delayed(delay);
      }
    }
    // KẾT THÚC CƠ CHẾ THỬ LẠI

    setState(() {
      if (success) {
        _translatedContent = resultText;
      } else {
        _translatedContent =
            'Error during translation via translator_plus. Vui lòng thử lại sau.';
      }
      _isTranslating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Helper to get the display name for the target language
    String getTargetName() {
      return _languages.entries
          .firstWhere(
            (entry) => entry.value == _targetLanguageCode,
            orElse: () => const MapEntry('Vietnamese', 'vi'),
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
                      onPressed: _pasteFromClipboard,
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
// DocumentsTabContent (ĐÃ CHUYỂN SANG translator_plus)
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

  final translator = GoogleTranslator(); // Sử dụng translator_plus
  final ChatGPTService _chatGPTService = ChatGPTService();

  // Language map
  final Map<String, String> _languages = {
    'Vietnamese': 'vi',
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Japanese': 'ja',
  };

  String _selectedTargetLanguageCode = 'vi'; // Đích mặc định: Vietnamese

  @override
  void dispose() {
    super.dispose();
  }

  // Helper function to find the language name from its code
  String _getLanguageName(String code) {
    return _languages.entries
        .firstWhere(
          (entry) => entry.value == code,
          orElse: () => const MapEntry('Unknown', ''),
        )
        .key;
  }

  // NEW: Layout processing function (ĐÃ SỬA LỖI REGEX VÀ NULL SAFETY)
  List<String> _processTextForLayout(String rawText) {
    // SỬA: Loại bỏ cú pháp \p{L} không hỗ trợ và sửa lỗi null check
    final cleanText = rawText.replaceAll(
      RegExp(r'[^\w\s\.\,;:\-?!]', unicode: true),
      ' ',
    );

    // Dùng s!.trim() để sửa lỗi null safety
    return cleanText
        .split(RegExp(r'\n\s*\n'))
        .where((s) => s!.trim().isNotEmpty)
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
      allowedExtensions: ['pdf'], // Focus only on PDF
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
      // Use the prefixed PdfDocument here
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
      print("STARTING translation to $_selectedTargetLanguageCode");
      print(textToTranslate);
    });

    try {
      // final sourceParagraphs = _processTextForLayout(textToTranslate);
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
      String Bon = "Tôi là Bon. Tôi là một con chó";
      final phan_dich = await translator.translate(Bon, from: 'auto', to: 'en');
      print(phan_dich);

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

      // ============== BẮT ĐẦU FIX FONT TIẾNG VIỆT ==============
      // 1. Khởi tạo font mặc định (Courier) để dùng làm dự phòng
      pw.Font ttf = pw.Font.courier();
      try {
        // 2. Thử tải file font Roboto.ttf từ assets/fonts/
        final fontData = await rootBundle.load("assets/fonts/Roboto.ttf");
        ttf = pw.Font.ttf(fontData);
      } catch (e) {
        // Nếu lỗi tải asset, in lỗi ra console và sử dụng font mặc định
        print(
          'FONT LOAD ERROR: Could not load Roboto.ttf. Using default Courier font. Please ensure file exists at assets/fonts/ and pubspec.yaml is correct.',
        );
      }

      // 3. Định nghĩa TextStyle tùy chỉnh sử dụng font đã tải
      final customTextStyle = pw.TextStyle(
        font: ttf,
        fontSize: 12,
        lineSpacing: 1.5,
      );
      // ================= KẾT THÚC FIX FONT ===================

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            List<pw.Widget> content = [
              pw.Text(
                'Translated Document (${_getLanguageName(langCode)})',
                // Áp dụng font tùy chỉnh cho tiêu đề
                style: pw.TextStyle(
                  font: ttf, // <-- ÁP DỤNG FONT
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
                    // Áp dụng customTextStyle cho nội dung
                    style: customTextStyle, // <-- ÁP DỤNG FONT
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

      // ... (Phần lưu file và mở file không đổi)
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

                            if (_extractedText.isNotEmpty) {
                              // Dịch lại ngay sau khi đổi ngôn ngữ
                              _translateExtractedText(_extractedText);
                            } else {
                              _documentStatus =
                                  'Target language set to ${_getLanguageName(newValue)}. Upload a file to proceed.';
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
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// WebsitesTabContent (ĐÃ CHUYỂN SANG translator_plus)
// =========================================================================

class WebsitesTabContent extends StatefulWidget {
  const WebsitesTabContent({super.key});

  @override
  State<WebsitesTabContent> createState() => _WebsitesTabContentState();
}

class _WebsitesTabContentState extends State<WebsitesTabContent> {
  final TextEditingController _urlController = TextEditingController();
  String _translatedContent = 'Translated website content will appear here.';
  bool _isTranslating = false;

  final translator = GoogleTranslator(); // Sử dụng translator_plus

  final Map<String, String> _languages = {
    'Vietnamese': 'vi',
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
  };

  // Nguồn sẽ được tự động phát hiện (auto-detect)
  String _targetLanguageCode = 'en';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndTranslateWebsite() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _translatedContent = 'Please enter a website URL.');
      return;
    }

    // Validate URL format (simple check)
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (!uri.isScheme('http') && !uri.isScheme('https'))) {
      setState(
        () => _translatedContent =
            'Invalid URL format. Please include http:// or https://',
      );
      return;
    }

    setState(() {
      _isTranslating = true;
      _translatedContent = 'Fetching content from $url...';
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load website (Status Code: ${response.statusCode})',
        );
      }

      // Parse the HTML content
      final document = parse(response.body);

      // Extract text content from the body, excluding script and style tags
      final allTextNodes =
          document.body?.nodes
              .where((node) => node.nodeType == 3) // Text nodes
              .map((node) => node.text?.trim() ?? '')
              .where((text) => text.isNotEmpty)
              .toList() ??
          [];

      String rawText = allTextNodes.join(' ');

      if (rawText.length > 5000) {
        rawText = rawText.substring(0, 5000); // Limit text length for API
        setState(() {
          _translatedContent += '\n(Warning: Text truncated for translation)';
        });
      }

      setState(() {
        _translatedContent = 'Translating content...';
      });

      // SỬ DỤNG translator_plus (Auto detect nguồn)
      final translation = await translator.translate(
        rawText,
        to: _targetLanguageCode,
      );

      setState(() {
        _translatedContent =
            '--- Translated Website Content ---\n\n${translation.text}';
        _isTranslating = false;
      });
    } catch (e) {
      print('Website Translation Error: $e');
      setState(() {
        _translatedContent =
            'Error: Could not process or translate the website. ($e)';
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Helper to get the display name for the target language
    String getTargetName() {
      return _languages.entries
          .firstWhere(
            (entry) => entry.value == _targetLanguageCode,
            orElse: () => const MapEntry('Vietnamese', 'vi'),
          )
          .key;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'Enter Website URL (e.g., https://example.com)',
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _urlController.clear(),
              ),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _fetchAndTranslateWebsite(),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Source: Auto Detect',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              DropdownButton<String>(
                value: _targetLanguageCode,
                items: _languages.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.value,
                    child: Text(entry.key),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _targetLanguageCode = newValue;
                    });
                    // Translate on change if URL is not empty
                    if (_urlController.text.isNotEmpty) {
                      _fetchAndTranslateWebsite();
                    }
                  }
                },
              ),

              ElevatedButton.icon(
                onPressed: _isTranslating ? null : _fetchAndTranslateWebsite,
                icon: _isTranslating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.language),
                label: Text(
                  'Translate to ${getTargetName()}',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                child: Text(
                  _translatedContent,
                  style: TextStyle(color: Colors.blueGrey[800], fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// MyHomePage (Images tab: Simplified - Only 3 buttons)
// =========================================================================

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.cameras});
  final String title;
  final List<CameraDescription> cameras;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isProcessing = false;

  // --- Image Picking Logic ---

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      await _processAndNavigate(File(pickedFile.path));
    }
  }

  // Function for System File Picker (restricted to images)
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
    // Check if any cameras are available
    if (widget.cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cameras available on this device.')),
      );
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
      await _processAndNavigate(File(imagePath));
    }
  }

  Future<void> _processAndNavigate(File image) async {
    setState(() {
      _isProcessing = true;
    });

    // Perform OCR
    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );
    textRecognizer.close();

    String extractedText = recognizedText.text.isEmpty
        ? 'Could not recognize any text.'
        : recognizedText.text.replaceAll('\n', ' ');

    setState(() {
      _isProcessing = false;
    });

    // Navigate to ImageResultScreen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageResultScreen(
            imageFile: image,
            extractedText: extractedText,
          ),
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
              // Icon and Title
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

              // Processing Indicator
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

              // Button 1: Gallery
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

              // Button 2: Camera
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

              // Button 3: Upload File (System Picker for Images)
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

// =========================================================================
// ImageResultScreen (Shows OCR results, translation, AI actions)
// =========================================================================

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

  @override
  void initState() {
    super.initState();
    _extractedText = widget.extractedText;
  }

  // Helper function to find the language name from its code
  String _getLanguageName(String code) {
    return _languages.entries
        .firstWhere(
          (entry) => entry.value == code,
          orElse: () => const MapEntry('Unknown', ''),
        )
        .key;
  }

  // --- Translation Logic ---
  Future<void> _translateText(String extractedText) async {
    if (extractedText.isEmpty ||
        extractedText.contains('Could not recognize')) {
      setState(() {
        _translatedText = "No valid text to translate.";
      });
      return;
    }

    setState(() {
      _isTranslating = true;
      _translatedText =
          'Translating to ${_getLanguageName(_targetLanguageCode)}...';
    });

    // BẮT ĐẦU CƠ CHẾ THỬ LẠI
    const int maxRetries = 3;
    const Duration delay = Duration(milliseconds: 700);

    String resultText = 'Error during translation via translator_plus.';
    bool success = false;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // SỬ DỤNG translator_plus (Auto detect nguồn)
        final translation = await translator.translate(
          textToTranslate,
          to: _targetLanguageCode,
        );
        resultText = translation.text;
        success = true;
        break;
      } catch (e) {
        print(
          'Image Translation attempt ${attempt + 1} failed. Retrying in 700ms...',
        );
        await Future.delayed(delay);
      }
    }
    // KẾT THÚC CƠ CHẾ THỬ LẠI

    if (mounted) {
      setState(() {
        if (success) {
          _translatedText = resultText;
        } else {
          _translatedText =
              'Error during translation via translator_plus. Vui lòng thử lại sau.';
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

  // --- Summarization Logic ---
  Future<void> _summarizeText() async {
    if (_extractedText.isEmpty || _extractedText.contains('Could not recognize')) {
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
    bool aiActionsDisabled = _isTranslating ||
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
            // Image Display
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
                // Translate Button
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

            const SizedBox(height: 30),

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
              child: SelectableText(
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

            // --- AI AGENT BUTTONS ---
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
            const SizedBox(height: 20),
          ],
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
