import 'package:flutter/material.dart';
import 'services/chatgpt_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart'; // Added for image picking
import 'dart:io';
import 'dart:convert'; // Added for Base64 encoding
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;

class ChatScreen extends StatefulWidget {
  // ADDED: Optional document context field
  final String? documentContext;

  const ChatScreen({super.key, this.documentContext});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_Message> _messages = [];
  late final ChatGPTService _chatService;
  bool _isSending = false;

  // NEW STATE: For image handling
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // 2. DEFINE THE DYNAMIC SYSTEM PROMPT
  String get _systemPrompt {
    String basePrompt = 'You are a helpful and knowledgeable AI assistant.';

    if (widget.documentContext != null && widget.documentContext!.isNotEmpty) {
      // Priming the AI with the document content
      return "You are an AI assistant specialized in analyzing documents. Answer the user's questions based ONLY on the following document context. Do not use outside knowledge unless necessary for clarification. \n\nDOCUMENT CONTEXT: ${widget.documentContext!}";
    }
    return basePrompt;
  }

  @override
  void initState() {
    super.initState();
    _chatService = ChatGPTService();

    String initialMessage;
    if (widget.documentContext != null && widget.documentContext!.isNotEmpty) {
      initialMessage =
          'Hello! I have loaded the document content. How can I assist you with this document?';
    } else {
      initialMessage = 'Hello, how can I help you?';
    }

    _messages.add(_Message(text: initialMessage, isUser: false));
  }

  // NEW: Image Picker Function
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // NEW: Image Removal Function
  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  // EXISTING: Function to pick and extract document content
  Future<void> _pickDocumentFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      final fileName = result.files.single.name;
      String fileContent = '';

      setState(() {
        _isSending = true;
      });

      try {
        if (fileName.toLowerCase().endsWith('.pdf')) {
          // --- PDF Text Extraction ---
          final List<int> bytes = await pickedFile.readAsBytes();
          final syncfusion.PdfDocument document = syncfusion.PdfDocument(
            inputBytes: bytes,
          );
          final syncfusion.PdfTextExtractor extractor =
              syncfusion.PdfTextExtractor(document);
          fileContent = extractor.extractText();
          document.dispose();
        } else {
          // --- Simple Text Extraction (.txt, etc.) ---
          fileContent = await pickedFile.readAsString();
        }

        if (fileContent.isEmpty) {
          throw Exception("Could not extract any content from $fileName.");
        }

        // Navigate/Reload with Context
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ChatScreen(documentContext: fileContent),
            ),
          );
        }
      } catch (e) {
        // Show error in the chat feed
        setState(() {
          _messages.add(
            _Message(text: 'Error loading file: $fileName. $e', isUser: false),
          );
        });
      } finally {
        setState(() {
          _isSending = false;
          _scrollToBottom();
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final image = _selectedImage;

    // Must have text OR an image to send
    if (text.isEmpty && image == null || _isSending) return;

    // 1. Prepare image payload and user's multimodal message content
    String? imageBase64;
    final List<Map<String, dynamic>> userMessageContent = [];

    if (image != null) {
      imageBase64 = base64Encode(await image.readAsBytes());
      // Add image part
      userMessageContent.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/jpeg;base64,$imageBase64',
          'detail': 'low',
        },
      });
    }

    // Add the text part
    if (text.isNotEmpty) {
      userMessageContent.add({'type': 'text', 'text': text});
    }

    // 2. Update UI state for sending and clear inputs
    setState(() {
      // Create display message for user history
      String displayMessage = text;
      if (image != null) {
        displayMessage += (text.isNotEmpty ? ' ' : '') + '[Image attached]';
      }
      _messages.add(_Message(text: displayMessage, isUser: true));

      _controller.clear();
      _selectedImage = null; // Clear image after preparing to send
      _isSending = true;
    });

    // 3. Construct the full API messages list
    final apiMessages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': _systemPrompt, // Includes document context if active
      },
    ];

    // Add previous messages (simplified history handling)
    for (final m in _messages.where(
      (m) => !m.text.contains('[Image attached]'),
    )) {
      apiMessages.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      });
    }

    // Add the current multimodal user message
    apiMessages.add({
      'role': 'user',
      'content': userMessageContent, // LIST OF OBJECTS
    });

    // 4. API Call and Error Handling
    try {
      final reply = await _chatService.sendChat(apiMessages);

      setState(() {
        _messages.add(_Message(text: reply, isUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(_Message(text: 'Error: $e', isUser: false));
      });
    } finally {
      setState(() {
        _isSending = false;
      });
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color purple = Colors.deepPurple;
    const Color lightPurple = Color(0xFFEDE7F6);
    final hasDocumentContext =
        widget.documentContext != null && widget.documentContext!.isNotEmpty;
    final isInputEmpty = _controller.text.trim().isEmpty;
    final isSendingDisabled =
        _isSending || (isInputEmpty && _selectedImage == null);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: purple,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'Chat with AI Assistant',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            // UI INDICATOR FOR DOCUMENT CONTEXT
            if (hasDocumentContext)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  'Document Context Active',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.lightGreenAccent,
                  ),
                ),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.isUser;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      if (!isUser) const _Avatar(isUser: false),
                      if (!isUser) const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? purple : lightPurple,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      if (isUser) const SizedBox(width: 8),
                      if (isUser) const _Avatar(isUser: true),
                    ],
                  ),
                );
              },
            ),
          ),

          // --- Image Preview Area ---
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: purple.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Image attached and ready to send.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: _removeImage,
                    ),
                  ],
                ),
              ),
            ),

          // --- End Image Preview Area ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  // 1. Attach Document Button
                  GestureDetector(
                    onTap: _isSending ? null : _pickDocumentFile,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: purple.withOpacity(0.4)),
                      ),
                      child: Icon(Icons.attach_file, color: purple),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 2. NEW: Attach Image Button
                  GestureDetector(
                    onTap: _isSending ? null : _pickImage,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: purple.withOpacity(0.4)),
                      ),
                      child: Icon(Icons.image, color: purple),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 3. Text Input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: purple.withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: (_selectedImage != null)
                              ? 'Add a question about the image...'
                              : 'Ask me anything you want...',
                          hintStyle: const TextStyle(color: Colors.black38),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 4. Send Button
                  GestureDetector(
                    onTap: isSendingDisabled ? null : _sendMessage,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: purple,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;

  _Message({required this.text, required this.isUser});
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({super.key, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: isUser ? Colors.grey[400] : Colors.deepPurple,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
