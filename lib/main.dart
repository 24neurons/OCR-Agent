import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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

class _MainTranslatorScreenState extends State<MainTranslatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Text', 'Images', 'Documents', 'Websites'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Translate Clone'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _tabs.map((tabText) {
            IconData icon;
            switch (tabText) {
              case 'Text':
                icon = Icons.text_fields;
                break;
              case 'Images':
                icon = Icons.image;
                break;
              case 'Documents':
                icon = Icons.description;
                break;
              case 'Websites':
                icon = Icons.language;
                break;
              default:
                icon = Icons.error;
            }
            return Tab(icon: Icon(icon), text: tabText);
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
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

  final translator = GoogleTranslator(); // KHÔI PHỤC translator_plus

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
  void dispose() {
    _inputController.dispose();
    super.dispose();
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
          // Language Selectors (Top Row)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // NGUỒN: HIỂN THỊ CỐ ĐỊNH AUTO DETECT
              const Text(
                'Source: Auto Detect',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              const Icon(Icons.arrow_forward_ios),

              // Target Language Dropdown
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
                    // Tùy chọn: gọi _translateText() nếu input không rỗng
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Input/Output Boxes
          Expanded(
            child: Row(
              children: [
                // Input Box (Left)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _inputController,
                      maxLines: null, // Allows multiline input
                      expands: true,
                      decoration: const InputDecoration(
                        hintText: 'Enter text (Source auto-detected)',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Output Box (Right)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50, // Light blue background
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.all(10.0),
                    alignment: Alignment.topLeft,
                    child: _isTranslating
                        ? const Center(child: CircularProgressIndicator())
                        : SelectableText(
                            _translatedContent,
                            style: TextStyle(
                              color: Colors.blueGrey[800],
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Bar with Microphone and Translation Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Microphone/Input Info
              Row(
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.mic)),
                  const Text('0 / 5,000'),
                ],
              ),

              // Translation Button (The missing piece!)
              ElevatedButton.icon(
                onPressed: _isTranslating || _inputController.text.isEmpty
                    ? null
                    : _translateText,
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
                    : const Icon(Icons.translate, size: 20),
                label: Text(
                  getTargetName(),
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
// MyHomePage (Images Tab - OCR) (ĐÃ CHUYỂN SANG translator_plus cho phần dịch)
// =========================================================================

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.cameras});
  final String title;
  final List<CameraDescription> cameras;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _extractedText = '';
  String _translatedText = '';
  bool _isTranslating = false;
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final translator = GoogleTranslator(); // Sử dụng translator_plus

  // Language map
  final Map<String, String> _languages = {
    'Vietnamese': 'vi',
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
  };

  String _targetLanguageCode = 'vi'; // Mặc định dịch sang tiếng Việt

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // Chức năng OCR (Không liên quan đến Google ML Kit Translation, nên giữ lại)
  Future<void> _processImage(InputImage inputImage) async {
    setState(() {
      _extractedText = 'Processing image for text...';
      _translatedText = '';
    });

    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );

    if (mounted) {
      setState(() {
        _extractedText = recognizedText.text.isNotEmpty
            ? recognizedText.text
            : 'No text found in the image.';
      });

      // Tự động dịch sau khi OCR
      if (_extractedText.isNotEmpty &&
          _extractedText != 'No text found in the image.') {
        await _translateExtractedText(_extractedText);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final inputImage = InputImage.fromFilePath(image.path);
        await _processImage(inputImage);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _extractedText = 'Error picking/processing image: $e';
        });
      }
    }
  }

  // HÀM DỊCH SỬ DỤNG translator_plus
  Future<void> _translateExtractedText(String textToTranslate) async {
    if (textToTranslate.isEmpty) return;

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
    }
  }

  // Helper function to get the language name from its code
  String _getLanguageName(String code) {
    return _languages.entries
        .firstWhere(
          (entry) => entry.value == code,
          orElse: () => const MapEntry('Unknown', ''),
        )
        .key;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 20),
          const Text(
            'OCR & Translate from Image',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Buttons for Image Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Language Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _targetLanguageCode,
                icon: const Icon(Icons.arrow_drop_down),
                elevation: 16,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _targetLanguageCode = newValue;
                    });
                    // Tự động dịch lại nếu đã có văn bản
                    if (_extractedText.isNotEmpty &&
                        _extractedText != 'No text found in the image.') {
                      _translateExtractedText(_extractedText);
                    }
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
          const SizedBox(height: 20),

          // Extracted Text Display
          const Text(
            'Extracted Text (Source Auto-Detected):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(5.0),
            ),
            constraints: const BoxConstraints(minHeight: 100),
            child: SelectableText(_extractedText),
          ),

          const SizedBox(height: 20),

          // Translated Text Display
          Text(
            'Translated Text (${_getLanguageName(_targetLanguageCode)}):',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.shade700, width: 2),
              borderRadius: BorderRadius.circular(5.0),
              color: Colors.blue.shade50,
            ),
            constraints: const BoxConstraints(minHeight: 100),
            child: _isTranslating
                ? const Center(child: CircularProgressIndicator())
                : SelectableText(_translatedText),
          ),
        ],
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
