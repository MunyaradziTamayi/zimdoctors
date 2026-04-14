import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stts/stts.dart';
import 'package:zimdoctors/services/disease_api_service.dart';
import 'package:zimdoctors/Screens/doctors_screen.dart';
import 'package:zimdoctors/utils/doctor_recommendation_utils.dart';
import 'package:zimdoctors/models/diagnosis_response.dart';

class Message {
  final String text;
  final String sender; // Changed from bool isUser to String sender
  final DateTime timestamp;

  Message({required this.text, required this.sender, required this.timestamp});
}

class ChatScreen extends StatefulWidget {
  static const String id = 'chat_screen';
  final bool recommendDoctor;

  const ChatScreen({super.key, this.recommendDoctor = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _auth = FirebaseAuth.instance;
  User? loggedInUser; // Made nullable for safety
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Stt _stt = Stt();
  final Tts _tts = Tts();
  StreamSubscription<SttRecognition>? _sttResultSub;
  StreamSubscription<SttState>? _sttStateSub;
  StreamSubscription<TtsState>? _ttsStateSub;

  String? _voiceInitError;
  String _lastRecognitionText = '';
  bool _commitRecognitionOnStop = false;
  DiseaseApiService? _diseaseApi;
  String? _diseaseApiInitError;

  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isAwaitingAi = false;
  int? _speakingMessageIndex;

  String? _selectedLanguage;

  final List<Message> _messages = [];
  String? _recommendedSearchQuery;

  @override
  void initState() {
    super.initState();
    getCurrentUser();
    _initDiseaseApi();
    _initSpeech();

    _messages.add(
      Message(
        text: widget.recommendDoctor
            ? "Hi! Describe your symptoms and I’ll suggest what kind of doctor to see. Then you can search and book."
            : "Hello! I'm your Zim Doctors AI health assistant. How can I help you today?",
        sender: 'AI',
        timestamp: DateTime.now(),
      ),
    );
  }

  void _initSpeech() {
    _ttsStateSub = _tts.onStateChanged.listen((state) {
      if (!mounted) return;
      if (state == TtsState.stop) {
        setState(() => _speakingMessageIndex = null);
      }
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _speakingMessageIndex = null);
    });

    _sttResultSub = _stt.onResultChanged.listen((result) {
      _lastRecognitionText = result.text;
    });

    _sttStateSub = _stt.onStateChanged.listen((state) {
      if (state != SttState.stop) return;
      if (!mounted) return;

      if (_isRecording) {
        setState(() => _isRecording = false);
      }

      if (_commitRecognitionOnStop) {
        _commitRecognitionOnStop = false;
        final recognized = _lastRecognitionText.trim();
        if (recognized.isNotEmpty) {
          setState(() {
            _controller.text = recognized;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        }
        if (_isTranscribing) {
          setState(() => _isTranscribing = false);
        }
      }
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _voiceInitError = 'Speech recognition error: $e';
        _isRecording = false;
        _isTranscribing = false;
      });
    });

    unawaited(_configureTtsDefaults());
    unawaited(_checkVoiceSupport());
  }

  Future<void> _configureTtsDefaults() async {
    try {
      await _tts.setRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> _checkVoiceSupport() async {
    try {
      final sttSupported = await _stt.isSupported();
      final ttsSupported = await _tts.isSupported();
      if (!mounted) return;
      if (!sttSupported) {
        setState(
          () => _voiceInitError = 'Speech-to-text is not supported on this device.',
        );
        return;
      }
      if (!ttsSupported) {
        setState(
          () => _voiceInitError = 'Text-to-speech is not supported on this device.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _voiceInitError = 'Voice features unavailable: $e');
    }
  }

  void _initDiseaseApi() {
    try {
      _diseaseApi = DiseaseApiService.fromEnv();
    } catch (e) {
      _diseaseApiInitError = e.toString();
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

  Future<void> _sendMessage() async {
    if (_isAwaitingAi) return;
    if (_controller.text.trim().isEmpty) return;

    if (_selectedLanguage == null) {
      await _openLanguagePicker();
      if (_selectedLanguage == null) return;
    }

    final userEmail = loggedInUser?.email ?? 'Anonymous';
    final text = _controller.text.trim();

    final userMessage = Message(
      text: text,
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
      _isAwaitingAi = true;
    });

    _scrollToBottom();

    final diseaseApi = _diseaseApi;
    if (diseaseApi == null) {
      setState(() => _isAwaitingAi = false);
      _showSnackBar(
        _diseaseApiInitError ??
            'Disease API not configured. Set DISEASE_API_BASE_URL in .env.',
      );
      return;
    }

    // Start session if not started
    if (diseaseApi.sessionId == null) {
      try {
        await diseaseApi.startSession(_selectedLanguage!);
      } catch (e) {
        setState(() => _isAwaitingAi = false);
        _showSnackBar('Failed to start session: $e');
        return;
      }
    }

    final placeholderIndex = _messages.length;
    setState(() {
      _messages.add(
        Message(
          text: (_selectedLanguage ?? 'english') == 'shona'
              ? 'Ndiri kufunga...'
              : 'Thinking...',
          sender: 'AI',
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();

    try {
      final reply = await diseaseApi.reply(text);
      if (!mounted) return;

      String displayReply;
      String? inferredSpecialist;

      if (reply is DiagnosisResponse) {
        displayReply = reply.displayString;
        inferredSpecialist = reply.suggestedSpecialist;
      } else {
        displayReply = reply.toString();
        inferredSpecialist = DoctorRecommendationUtils.inferSearchQuery(displayReply);
      }

      setState(() {
        _messages[placeholderIndex] = Message(
          text: displayReply,
          sender: 'AI',
          timestamp: DateTime.now(),
        );
        if (widget.recommendDoctor) {
          _recommendedSearchQuery = inferredSpecialist;
        }
        _firestore.collection('messages').add({
          'text': displayReply,
          'sender': 'AI',
          'timestamp': DateTime.now(),
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages[placeholderIndex] = Message(
          text: 'Sorry — I could not reach the diagnosis server.\n\nError: $e',
          sender: 'AI',
          timestamp: DateTime.now(),
        );
      });
    } finally {
      if (!mounted) return;
      setState(() => _isAwaitingAi = false);
      _scrollToBottom();
    }
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
    if (_isTranscribing) return;
    if (_voiceInitError != null) {
      _showSnackBar(_voiceInitError!);
      return;
    }

    if (_isRecording) {
      setState(() => _isTranscribing = true);
      _commitRecognitionOnStop = true;
      try {
        await _stt.stop();
      } catch (e) {
        _commitRecognitionOnStop = false;
        if (!mounted) return;
        setState(() => _isTranscribing = false);
        _showSnackBar('Failed to stop listening: $e');
      }
      return;
    }

    try {
      final ok = await _stt.hasPermission();
      if (!ok) {
        _showSnackBar('Microphone permission denied.');
        return;
      }
      await _setSttLanguageForSelection();
      _lastRecognitionText = '';
      _commitRecognitionOnStop = false;
      await _stt.start(
        const SttRecognitionOptions(
          punctuation: true,
          offline: true,
        ),
      );
      if (!mounted) return;
      setState(() => _isRecording = true);
    } catch (e) {
      _showSnackBar('Voice input failed: $e');
    }
  }

  Future<void> _toggleSpeakMessage(int index, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (_speakingMessageIndex == index) {
      await _tts.stop();
      if (!mounted) return;
      setState(() => _speakingMessageIndex = null);
      return;
    }

    try {
      if (_speakingMessageIndex != null) {
        await _tts.stop();
      }
      if (!mounted) return;
      setState(() => _speakingMessageIndex = index);
      await _setTtsLanguageForSelection();
      await _tts.start(
        trimmed,
        options: const TtsOptions(mode: TtsQueueMode.flush),
      );
    } catch (e) {
      _showSnackBar('Text-to-voice failed: $e');
      if (!mounted) return;
      setState(() => _speakingMessageIndex = null);
    }
  }

  Future<void> _setTtsLanguageForSelection() async {
    final selected = _selectedLanguage?.toLowerCase().trim();
    final preferred = selected == 'shona' ? 'sn-ZW' : 'en-US';
    try {
      await _tts.setLanguage(preferred);
    } catch (_) {
      // Ignore; fallback is handled by the platform TTS engine.
    }
  }

  Future<void> _setSttLanguageForSelection() async {
    final selected = _selectedLanguage?.toLowerCase().trim();
    final preferred = selected == 'shona' ? 'sn-ZW' : 'en-US';
    try {
      await _stt.setLanguage(preferred);
    } catch (_) {}
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _greetingForLanguage(String language) {
    return language == 'shona'
        ? "Mhoroi! Ndini AI yako yekubatsira nezvehutano yeZim Doctors. Ndingakubatsirei nhasi?"
        : "Hello! I'm your Zim Doctors AI health assistant. How can I help you today?";
  }

  Future<void> _setLanguage(String language) async {
    if (_isAwaitingAi) return;
    final normalized = language.toLowerCase().trim();
    if (normalized != 'english' && normalized != 'shona') return;

    if (_speakingMessageIndex != null) {
      await _tts.stop();
    }

    final prev = _selectedLanguage;
    setState(() {
      _selectedLanguage = normalized;
      _speakingMessageIndex = null;
      if (_messages.isNotEmpty) {
        _messages[0] = Message(
          text: _greetingForLanguage(normalized),
          sender: 'AI',
          timestamp: DateTime.now(),
        );
      }
    });

    // Restart backend session on language change so /ask & /predict/text resolve correctly.
    if (prev != null && prev != normalized) {
      try {
        _diseaseApi?.resetSession();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _messages.add(
          Message(
            text: normalized == 'shona'
                ? 'Mutauro wachinjwa kuShona. Bvunza mubvunzo wako.'
                : 'Language changed to English. Ask your question.',
            sender: 'AI',
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _openLanguagePicker() async {
    if (!mounted) return;
    if (_isAwaitingAi) {
      _showSnackBar('Please wait for the current reply to finish.');
      return;
    }

    final current = _selectedLanguage;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final themeText = GoogleFonts.inter(color: Colors.white);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(41),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Language / Mutauro',
                        style: themeText.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _LanguageOptionTile(
                  label: 'English',
                  subtitle: 'Standard',
                  value: 'english',
                  groupValue: current,
                  onTap: () => Navigator.pop(context, 'english'),
                ),
                const SizedBox(height: 8),
                _LanguageOptionTile(
                  label: 'Shona',
                  subtitle: 'ChiShona',
                  value: 'shona',
                  groupValue: current,
                  onTap: () => Navigator.pop(context, 'shona'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await _setLanguage(selected);
    }
  }

  Widget _buildLanguageBanner() {
    final selected = _selectedLanguage;
    final title = selected == null
        ? 'Select language / Sarudza mutauro'
        : (selected == 'shona' ? 'Mutauro: Shona' : 'Language: English');
    final helper = selected == null
        ? 'This will control how the AI replies.'
        : (selected == 'shona'
            ? 'AI ichapindura muShona.'
            : 'AI will reply in English.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.translate, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  helper,
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(179),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _openLanguagePicker,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF57E659),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              selected == null ? 'Choose' : 'Change',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
          widget.recommendDoctor ? 'Doctor Match' : 'AI Assistant',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Change language',
            onPressed: _openLanguagePicker,
            icon: const Icon(Icons.translate, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_diseaseApiInitError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1E1E1E),
              child: Text(
                'Diagnosis server not configured: $_diseaseApiInitError',
                style: GoogleFonts.inter(
                  color: Colors.orangeAccent,
                  fontSize: 12,
                ),
              ),
            ),
          if (_voiceInitError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1E1E1E),
              child: Text(
                'Voice features unavailable: $_voiceInitError',
                style: GoogleFonts.inter(
                  color: Colors.orangeAccent,
                  fontSize: 12,
                ),
                ),
              ),
          _buildLanguageBanner(),
          if (widget.recommendDoctor) _buildRecommendationCta(),
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

  Widget _buildRecommendationCta() {
    final query = _recommendedSearchQuery?.trim();
    if (query == null || query.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_hospital, color: Color(0xFF57E659), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Suggested: $query',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorsScreen(
                    initialQuery: query,
                    autofocusSearch: true,
                  ),
                ),
              );
            },
            child: Text(
              'Search',
              style: GoogleFonts.inter(
                color: const Color(0xFF57E659),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
                  hintText: (_selectedLanguage ?? 'english') == 'shona'
                      ? 'Nyora meseji...'
                      : 'Type a message...',
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
            onTap: _isAwaitingAi ? null : () => _sendMessage(),
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF57E659),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isAwaitingAi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.black, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_tts.stop());
    _sttResultSub?.cancel();
    _sttStateSub?.cancel();
    _ttsStateSub?.cancel();
    unawaited(_stt.dispose());
    unawaited(_tts.dispose());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final String value;
  final String? groupValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = groupValue == value;
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF57E659)
                      : Colors.white.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? Icons.check : Icons.language,
                  color: selected ? Colors.black : Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: Colors.white.withAlpha(179),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF57E659) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF57E659)
                        : Colors.white.withAlpha(90),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
