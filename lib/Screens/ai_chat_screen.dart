import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:zimdoctors/services/elevenlabs_service.dart';

class Message {
  final String text;
  final String sender; // Changed from bool isUser to String sender
  final DateTime timestamp;

  Message({required this.text, required this.sender, required this.timestamp});
}

class ChatScreen extends StatefulWidget {
  static const String id = 'chat_screen';

  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _auth = FirebaseAuth.instance;
  User? loggedInUser; // Made nullable for safety
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _playerCompleteSub;
  File? _currentTtsFile;
  ElevenLabsService? _elevenLabs;
  String? _elevenLabsInitError;

  bool _isRecording = false;
  bool _isTranscribing = false;
  int? _speakingMessageIndex;

  final List<Message> _messages = [
    Message(
      text:
          "Hello! I'm your Zim Doctors AI health assistant. How can I help you today?",
      sender: 'AI', // Mock sender
      timestamp: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    getCurrentUser();
    _initElevenLabs();

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) async {
      final fileToDelete = _currentTtsFile;
      _currentTtsFile = null;
      if (fileToDelete != null) {
        try {
          if (await fileToDelete.exists()) await fileToDelete.delete();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _speakingMessageIndex = null);
    });
  }

  void _initElevenLabs() {
    try {
      _elevenLabs = ElevenLabsService.fromEnv();
    } catch (e) {
      _elevenLabsInitError = e.toString();
    }
  }

  void getCurrentUser() {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        setState(() {
          loggedInUser = user;
        });
      }
    } catch (e) {
      print('Error retrieving user: $e');
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final userEmail = loggedInUser?.email ?? 'Anonymous';

    final userMessage = Message(
      text: _controller.text.trim(),
      sender: userEmail,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _firestore.collection('messages').add({
        'text': userMessage.text,
        'sender': userMessage.sender,
        'timestamp': userMessage.timestamp,
      });

      _controller.clear();
    });

    _scrollToBottom();

    // Mock AI Response
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add(
            Message(
              text: "I'm a demo AI. I received: \"${userMessage.text}\"",
              sender: 'AI',
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (_elevenLabs == null) {
      _showSnackBar(
        'ElevenLabs not configured. Add ELEVENLABS_API_KEY to .env.',
      );
      return;
    }

    if (_isTranscribing) return;

    if (_isRecording) {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);

      if (path == null) return;
      await _transcribeAudioFile(File(path));
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnackBar('Microphone permission denied.');
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/elevenlabs_stt_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      ),
      path: path,
    );

    if (!mounted) return;
    setState(() => _isRecording = true);
  }

  Future<void> _transcribeAudioFile(File audioFile) async {
    final elevenLabs = _elevenLabs;
    if (elevenLabs == null) return;

    setState(() => _isTranscribing = true);
    try {
      final text = await elevenLabs.speechToText(audioFile);
      if (!mounted) return;
      setState(() {
        _controller.text = text;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      });
    } catch (e) {
      _showSnackBar('Voice-to-text failed: $e');
    } finally {
      try {
        if (await audioFile.exists()) await audioFile.delete();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _isTranscribing = false);
    }
  }

  Future<void> _toggleSpeakMessage(int index, String text) async {
    final elevenLabs = _elevenLabs;
    if (elevenLabs == null) {
      _showSnackBar(
        'ElevenLabs not configured. Add ELEVENLABS_API_KEY to .env.',
      );
      return;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (_speakingMessageIndex == index) {
      await _audioPlayer.stop();
      final fileToDelete = _currentTtsFile;
      _currentTtsFile = null;
      if (fileToDelete != null) {
        try {
          if (await fileToDelete.exists()) await fileToDelete.delete();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _speakingMessageIndex = null);
      return;
    }

    setState(() => _speakingMessageIndex = index);
    try {
      await _audioPlayer.stop();
      final previousFile = _currentTtsFile;
      _currentTtsFile = null;
      if (previousFile != null) {
        try {
          if (await previousFile.exists()) await previousFile.delete();
        } catch (_) {}
      }

      final ttsFile = await elevenLabs.textToSpeechToFile(trimmed);
      _currentTtsFile = ttsFile;
      await _audioPlayer.play(DeviceFileSource(ttsFile.path));
    } catch (e) {
      _showSnackBar('Text-to-voice failed: $e');
      if (!mounted) return;
      setState(() => _speakingMessageIndex = null);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // App Theme Background
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: Builder(
          builder: (context) {
            return GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            );
          },
        ),
        title: Text(
          'AI Assistant',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_elevenLabsInitError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1E1E1E),
              child: Text(
                'Voice features disabled: $_elevenLabsInitError',
                style: GoogleFonts.inter(
                  color: Colors.orangeAccent,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message, index);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, int index) {
    final isUser = message.sender == (loggedInUser?.email ?? 'Anonymous');
    final isSpeaking = _speakingMessageIndex == index;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF57E659) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message.text,
                style: GoogleFonts.inter(
                  color: isUser ? Colors.black : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _toggleSpeakMessage(index, message.text),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isUser
                      ? Colors.black.withOpacity(0.15)
                      : Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isSpeaking
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isUser ? Colors.black : Colors.white,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.volume_up,
                          size: 18,
                          color: isUser ? Colors.black : Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        32,
      ), // ample bottom padding for safe area
      decoration: const BoxDecoration(
        color: Colors.black, // Match background
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.redAccent
                    : const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isTranscribing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF57E659),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.black, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    final sub = _playerCompleteSub;
    _playerCompleteSub = null;
    if (sub != null) unawaited(sub.cancel());
    unawaited(_audioPlayer.dispose());
    unawaited(_recorder.dispose());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
