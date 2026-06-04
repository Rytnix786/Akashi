import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../providers/offline_sync_provider.dart';

class ChatMessage {
  final String text;
  final bool isMe;
  final List<Map<String, dynamic>> citations;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.citations,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  bool _isLoading = false;
  final _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // Voice Speech State
  stt.SpeechToText? _speech;
  bool _isListening = false;
  String _speechFeedbackText = "";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    // Insert welcome greeting in Bengali
    _messages.add(ChatMessage(
      text: "আসসালামু আলাইকুম! আমি 'আকাশি' এআই সহকারী। আপনার ফসল মনিটরিং ও রোগবালাই দমনে যেকোনো প্রশ্ন আমাকে জিজ্ঞাসা করুন।",
      isMe: false,
      citations: [],
      timestamp: DateTime.now(),
    ));
  }

  // Handle Voice capture dictate in Bengali
  Future<void> _toggleSpeechListening() async {
    final connectionProvider = Provider.of<OfflineSyncProvider>(context, listen: false);
    if (!connectionProvider.isOnline) {
      _showErrorSnackBar("ভয়েস ইনপুট ব্যবহারের জন্য ইন্টারনেট সংযোগ প্রয়োজন।");
      return;
    }

    if (!_isListening) {
      bool available = await _speech!.initialize(
        onStatus: (val) => debugPrint('Speech status: $val'),
        onError: (val) => debugPrint('Speech error: $val'),
      );
      
      if (available) {
        setState(() => _isListening = true);
        _speech!.listen(
          localeId: 'bn_BD', // Enforce native Bengali voice recognition!
          onResult: (val) => setState(() {
            _messageController.text = val.recognizedWords;
            _speechFeedbackText = val.recognizedWords;
          }),
        );
      } else {
        _showErrorSnackBar("স্পিচ রিকগনিশন সেবা শুরু করা যায়নি। অনুমতি পরীক্ষা করুন।");
      }
    } else {
      setState(() => _isListening = false);
      _speech!.stop();
    }
  }

  // Query Backend REST chat endpoint
  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;

    final connectionProvider = Provider.of<OfflineSyncProvider>(context, listen: false);
    if (!connectionProvider.isOnline) {
      _showErrorSnackBar("সংযোগ নেই! চ্যাটবট ব্যবহারের জন্য ইন্টারনেট প্রয়োজন।");
      return;
    }

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isMe: true,
        citations: [],
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken ?? "mock_jwt_token_demo";
      final response = await _dio.post(
        '/chat',
        data: {'query': text},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final String botResponse = data['response'] ?? "দুঃখিত, কোনো উত্তর পাওয়া যায়নি।";
        final List citationsList = data['citations'] ?? [];

        setState(() {
          _messages.add(ChatMessage(
            text: botResponse,
            isMe: false,
            citations: citationsList.map((e) => Map<String, dynamic>.from(e)).toList(),
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      debugPrint("FastAPI chat request failed: $e");
      setState(() {
        _messages.add(ChatMessage(
          text: "দুঃখিত, সার্ভারের সাথে সংযোগ স্থাপন করা যায়নি। অনুগ্রহ করে কিছু সময় পর আবার চেষ্টা করুন।",
          isMe: false,
          citations: [],
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.red.shade800,
      content: Text(
        message,
        style: const TextStyle(fontFamily: "NotoSansBengali", color: Colors.white),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final connectionProvider = Provider.of<OfflineSyncProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "কৃষি তথ্য চ্যাটবট (Akashi Assistant)",
          style: TextStyle(fontFamily: "NotoSansBengali", fontWeight: FontWeight.w600, fontSize: 16.0),
        ),
        backgroundColor: Colors.green.shade800,
        elevation: 1.0,
      ),
      body: Column(
        children: [
          // ─── OFFLINE RESILIENCE BANNER ─────────────────────────────────────
          if (!connectionProvider.isOnline)
            Container(
              width: double.infinity,
              color: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: Colors.white, size: 18.0),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      connectionProvider.lastSyncTime != null
                          ? "সংযোগ নেই — শেষ আপডেট: ${connectionProvider.lastSyncTime!.hour}:${connectionProvider.lastSyncTime!.minute}"
                          : "সংযোগ নেই — অফলাইন মোড",
                      style: const TextStyle(
                        fontFamily: "NotoSansBengali",
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ─── MESSAGES PANEL ────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // ─── TYPING LOADER SHIMMER ─────────────────────────────────────────
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.green.shade800, strokeWidth: 2.0),
                        ),
                        const SizedBox(width: 12.0),
                        const Text(
                          "আকাশি লিখছে...",
                          style: TextStyle(fontFamily: "NotoSansBengali", color: Colors.black54, fontSize: 13.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ─── CONVERSATIONAL INPUT MATRIX ───────────────────────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  // Premium Frosted bubble templates
  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: message.isMe ? Colors.green.shade700 : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20.0),
                    topRight: const Radius.circular(20.0),
                    bottomLeft: message.isMe ? const Radius.circular(20.0) : Radius.zero,
                    bottomRight: message.isMe ? Radius.zero : const Radius.circular(20.0),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4.0, offset: Offset(0, 2))
                  ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontFamily: "NotoSansBengali",
                    color: message.isMe ? Colors.white : Colors.black87,
                    fontSize: 14.0,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          
          // Render vector matched citations directly below the bubbles
          if (!message.isMe && message.citations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "উৎস ও তথ্যসূত্র:",
                    style: TextStyle(fontFamily: "NotoSansBengali", color: Colors.grey, fontSize: 11.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: message.citations.map((cite) {
                      final name = cite['source_file'] ?? "agri_docs.pdf";
                      final double score = (cite['similarity'] ?? 0.0) * 100;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          "📖 $name (${score.toStringAsFixed(0)}%)",
                          style: TextStyle(fontFamily: "NotoSansBengali", color: Colors.green.shade900, fontSize: 11.0),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Frosted input matrix containing speech panels
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Voice Input Panel (mic button)
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.red.shade800 : Colors.green.shade800,
                size: 28.0,
              ),
              onPressed: _toggleSpeechListening,
            ),
            const SizedBox(width: 8.0),

            // Text Entry Field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  style: const TextStyle(fontFamily: "NotoSansBengali", fontSize: 14.0),
                  decoration: const InputDecoration(
                    hintText: "বাংলায় আপনার প্রশ্ন লিখুন...",
                    hintStyle: TextStyle(fontFamily: "NotoSansBengali", color: Colors.black38),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12.0),

            // Send Button
            InkWell(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.green.shade800,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
