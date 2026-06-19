import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/config.dart';
import '../widgets/spiritual_nourishment_section.dart';
import '../core/app_colors.dart';
import '../walk_together_screen.dart';
import '../my_history_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:html' as html; // experimental approach
import 'dart:io' show Platform;   // For native
import 'package:flutter/foundation.dart' show kIsWeb;   // For web

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Shared journeys for Walk Together (persisted in memory for now)
  final List<Map<String, dynamic>> _sharedJourneys = [];
  static final List<_ChatMessage> _sessionHistory = [];
  final GlobalKey _latestMessageKey = GlobalKey();
  final SpeechToText speech = SpeechToText();
  final FlutterTts flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isMockMode = false;
  bool _isSending = false;
  bool isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  bool isWeb = kIsWeb;
  bool isIOS = !kIsWeb && Platform.isIOS;
  String? _selectedSpiritualTopic;

  static const double kDesktopBreakpoint = 900.0;
  static const double kSendButtonSize = 48.0;
  static const double kEmptyStateIconSize = 96.0;
  static const double kMessageMaxWidthUser = 0.78;
  static const double kMessageMaxWidthAssistant = 0.92;
  static const String _delveDeeperResponse = '''
  static const double kSidebarWidth = 290.0;
Delve Deeper – Additional Light from the Church’s Treasury
... [your full delve deeper text]
''';

   @override
  void initState() {
    super.initState();
    _loadSeekingGodsWisdomScreen();
  }

  void _loadSeekingGodsWisdomScreen() {
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(
        isUser: false,
        text: "Welcome to Seeking God's Wisdom.\n\nBring any question, struggle, or decision.",
      ));
      _sessionHistory.clear();
      _sessionHistory.addAll(List.from(_messages));
    });
    _scrollToTop();
  }

  void _showSeekingGodsWisdom() {
    print("DEBUG: Returning to Seeking God's Wisdom. History size: ${_sessionHistory.length}");
    setState(() {
      _messages.clear();
      _messages.addAll(_sessionHistory);
      if (_messages.isEmpty) {
        _messages.add(_ChatMessage(
          isUser: false,
          text: "Welcome to Seeking God's Wisdom.\n\nBring any question, struggle, or decision.",
        ));
      }
    });
    _scrollToTop();
  }

  void _showUsingMyGifts() {
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(
        isUser: false,
        text: "**Using My Gifts for the Kingdom**\n\n"
            "Every baptized Catholic has received unique gifts from the Holy Spirit for the building up of the Church and the glory of God.\n\n"
            "Discovering and using your gifts is one of the most fulfilling parts of the Christian life.",
      ));
    });
    _scrollToTop();
  }

  void _showMyMoralDilemmas() {
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(
        isUser: false,
        text: "**My Moral Dilemmas**\n\n"
            "This is the heart of our shared journey. Bring any moral question, ethical dilemma, or difficult decision here.\n\n"
            "WWJD will help you discern with clarity according to Church teaching.",
      ));
    });
    _scrollToTop();
  }

  void _showMyHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyHistoryScreen(savedMessages: _sessionHistory),
      ),
    );
  }

  void _shareToWalkTogether(_ChatMessage msg) {
    // Find the correct user question for this specific response
    String userQuestion = "No specific question found";
    bool foundResponse = false;

    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i] == msg) {
        foundResponse = true;
        continue;
      }
      if (foundResponse && _messages[i].isUser) {
        userQuestion = _messages[i].text;
        break;
      }
    }

    String fullResponse = msg.text;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share to Walk Together'),
        content: const Text(
          'This will share an anonymized version of your question and the WWJD response.\n\n'
          'Caution: Ensure no personal or confidential information is being shared.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);

              final journey = {
                'id': DateTime.now().millisecondsSinceEpoch,
                'title': 'Shared Ethical Journey',
                'question': userQuestion,
                'response': fullResponse,
                'upvotes': 0,
                'timestamp': DateTime.now(),
              };

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WalkTogetherScreen(sharedJourney: journey),
                ),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Shared anonymously to Walk Together!')),
              );
            },
            child: const Text('Share Anonymously', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showWalkTogether() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WalkTogetherScreen(),
      ),
    );
  }

  void _showTermsAndPrivacy() {
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(
        isUser: false,
        text: "**Terms & Privacy**\n\n"
            "This app is a formation aid aligned with the Magisterium of the Catholic Church.\n\n"
            "It is not a substitute for the Sacraments or spiritual direction. For serious matters, consult your priest.",
      ));
    });
    _scrollToTop();
  }

  void _showSpiritualNourishment([String? topic]) {
    _selectedSpiritualTopic = topic;

    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(
        isUser: false,
        text: '',
        isSpiritualNourishment: true,
      ));
    });

    _scrollToTop();
  }

  void _scrollToTop() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    });
  }

  void _scrollToLoading() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(max - 100);   // Loading image above the very bottom
      }
    });
  }

  void _scrollToNewResponse() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          max,   // Absolute bottom for new response
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _removeLoadingMessageIfPresent() {
    _messages.removeWhere((m) => m.isLoading);
  }

  void _toggleListening() async {
    if (isWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input available on iPhone app')),
      );
      return;
    }

    if (_isListening) {
      await speech.stop();
      setState(() => _isListening = false);
      print("DEBUG: Stopped listening");
    } else {
      bool available = await speech.initialize(
        onStatus: (status) => print("DEBUG: Speech status: $status"),
      );
      print("DEBUG: Speech available: $available");
      if (available) {
        setState(() => _isListening = true);
        speech.listen(
          onResult: (result) {
            print("DEBUG: Recognized: ${result.recognizedWords}");
            setState(() {
              _controller.text = result.recognizedWords;
            });
          },
          localeId: "en_US",
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    }
  }
  
  void _speak(String text) async {
    // Remove URLs and links
    String cleanText = text.replaceAll(RegExp(r'http[s]?://[^\s]+'), '');
    cleanText = cleanText.replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '');   // Remove Markdown links

    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(0.75);     // Deeper pitch
    await flutterTts.setSpeechRate(0.8);   // Slower for natural sound
    await flutterTts.setVolume(1.0);
    
    // Try deep male voices
    await flutterTts.setVoice({"name": "Daniel", "locale": "en-US"});   // Deep option
    // Or try "Tom", "Fred", "Alex"

    await flutterTts.speak(cleanText);
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _messages.add(_ChatMessage(isUser: false, text: '', isLoading: true));
      _isSending = true;
    });
    _controller.clear();
        _controller.clear();
    print("DEBUG: Scrolling to loading for question: $text");
    _scrollToLoading();
    _scrollToNewResponse();   // Scroll to bottom so loading image is visible

    try {
      if (_isMockMode) {
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        await _callLiveGrokAPI(text);
        return;
      }
    } catch (e) {
      // error handling
    }

    setState(() {
      _removeLoadingMessageIfPresent();
      _isSending = false;
    });
    _scrollToNewResponse();
  }

  Future<void> _callLiveGrokAPI(String userMessage) async {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? "Good morning" : now.hour < 17 ? "Good afternoon" : "Good evening";
    _scrollToLoading();   // Match Delve Deeper: scroll to loading image at top

    try {
      final response = await http.post(
        Uri.parse('https://api.x.ai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.xaiApiKey}',
        },
        body: jsonEncode({
          "model": "grok-3",
          "messages": [
            {
              "role": "system",
              "content": """You are WWJD, a warm, faithful Catholic spiritual advisor.

Current time: $greeting on ${DateFormat('EEEE').format(now)}.

Respond in a natural, flowing style **without any numbering** (no 1., 2., 3., etc.). 
Let each section transition smoothly as paragraphs and directly reference the user's specific situation.
Do not use the language that makes the application respond as a person.

Core Structure to follow naturally:
- Warm, personal welcome
- Connection to the Two Great Commandments
- What Would Jesus Do? (with Gospel example)
- Mercy & Forgiveness
- Practical Next Steps (use bullets where helpful)
- Kingdom Challenge
- Deeper Catholic Roots (Catechism, saints, etc.) + gentle closing

**When referencing Scripture, CCC, saints, or documents, use accurate, direct URLs in Markdown format [Text](url) that point to the specific paragraph or section, not the home page. 
Prefer Vatican.va or USCCB.org links with the exact reference.**


Stay reverent, encouraging, and fully aligned with Catholic teaching."""
            },
            {"role": "user", "content": userMessage}
          ],
          "temperature": 0.78,
          "max_tokens": 1200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String liveResponse = data['choices'][0]['message']['content'] ?? 'No response received.';

      setState(() {
          _removeLoadingMessageIfPresent();
          _messages.add(_ChatMessage(isUser: false, text: liveResponse));
          _isSending = false;
        });
        _scrollToNewResponse();

        // ←←← ADD THIS LINE TO SAVE TO HISTORY
        _sessionHistory.clear();
        _sessionHistory.addAll(List.from(_messages));
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('API Error: $e');
      setState(() {
        _removeLoadingMessageIfPresent();
        _messages.add(_ChatMessage(
          isUser: false,
          text: '⚠️ Live API Error:\n$e\n\nPlease check your xAI key in config.dart',
        ));
        _isSending = false;
      });
      _scrollToNewResponse();

      // ←←← ADD THIS LINE TO SAVE TO HISTORY (even on error)
      _sessionHistory.clear();
      _sessionHistory.addAll(List.from(_messages));
    }
  }

  void _handleDelveDeeper() {
    _removeLoadingMessageIfPresent();

    setState(() {
      _messages.add(_ChatMessage(isUser: false, text: '', isLoading: true));
      _isSending = true;
    });
    _scrollToNewResponse();   // Scroll to bottom so loading image is visible

    final lastUserMessage = _messages.lastWhere(
      (m) => m.isUser,
      orElse: () => _ChatMessage(isUser: true, text: "the current topic"),
    );

    final delvePrompt = """Delve much deeper into: ${lastUserMessage.text}

Please provide a much deeper, richer Catholic exploration of this specific question. 
Expand with more Scripture, CCC references, saints, and practical applications.
State areas being expanded upon and make the response flow as an extension of the original response. Be warm and pastoral. 
Avoid duplications of the initial response unless providing significant expansion of the specific point. 
Use hyperlinks to recommend additional resources where appropriate.
""";

    _callLiveGrokAPI(delvePrompt);
  }

  // Sidebar and other methods remain unchanged
  Widget _buildSidebar({bool isInDrawer = false}) {
    return Container(
      width: isInDrawer ? null : 290.0,
      color: AppColors.sidebarBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tools for the Journey
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text('Tools for the Journey', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _sidebarTile(Icons.balance, "Seeking God's Wisdom", _showSeekingGodsWisdom),
              _sidebarTile(Icons.card_giftcard, 'Using My Gifts for the Kingdom', _showUsingMyGifts),
              _sidebarTile(Icons.history, 'My History', _showMyHistory),
              _sidebarTile(Icons.people_outline, 'Walk Together', _showWalkTogether),
              _sidebarTile(Icons.policy_outlined, 'Terms & Privacy', _showTermsAndPrivacy),

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Divider(),
              ),

              // Spiritual Nourishment
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text('Spiritual Nourishment', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _sidebarTile(Icons.church_outlined, 'Attend Mass', () => _showSpiritualNourishment('mass')),
              _sidebarTile(Icons.refresh, 'Go to Confession', () => _showSpiritualNourishment('confession')),
              _sidebarTile(Icons.favorite_border, 'Eucharistic Adoration', () => _showSpiritualNourishment('adoration')),
              _sidebarTile(Icons.assignment_outlined, 'Examination of Conscience', () => _showSpiritualNourishment('examination')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebarTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryMaroon),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      onTap: onTap,
      dense: true,
    );
  }

  void _simpleDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  void _shareMessage(String text) {
    Share.share(text);
  }

    @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    return Scaffold(
      appBar: _buildAppBar(isWide),
      drawer: isWide ? null : Drawer(child: _buildSidebar(isInDrawer: true)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              if (isWide) _buildSidebar(),
      Expanded(
                      child: Column(
                        children: [
                          // Sticky Latest Question
                          if (_messages.any((m) => m.isUser))
                            Builder(
                              builder: (context) {
                                final latestUserMessage = _messages.lastWhere(
                                  (m) => m.isUser,
                                  orElse: () => _ChatMessage(isUser: true, text: ''),
                                );
                                if (latestUserMessage.text.isNotEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.userBubble,
                                      border: Border(bottom: BorderSide(color: AppColors.primaryMaroon.withValues(alpha: 0.1))),
                                    ),
                                    child: SelectableText(
                                      latestUserMessage.text,
                                      style: const TextStyle(fontSize: 16, height: 1.55, color: Colors.black87),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),

                          // Reversed ListView - Newest at top
                          Expanded(
                          child: _messages.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              controller: _scrollController,
                              reverse: false,   // Standard chat: newest at bottom
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                return _buildMessageBubble(msg, index);
                              },
                            ),
                          ),

                          _buildInputBar(),
                        ],
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isWide) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(90),
      child: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Color(0xFF8B1E1E),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.church, size: 36, color: Colors.white),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppConfig.appName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(AppConfig.tagline, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
              const SizedBox(width: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/wwjd_header.jpg',
                  height: 58,
                  width: 58,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.church, size: kEmptyStateIconSize, color: AppColors.primaryMaroon),
          SizedBox(height: 24),
          Text('Peace be with you.', style: TextStyle(fontSize: 22)),
          Text('What is weighing on your heart today?', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

 Widget _buildMessageBubble(_ChatMessage msg, int index) {
    final isUser = msg.isUser;
    final isLatestAI = !isUser && index == _messages.length - 1;   // Add this line

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: isLatestAI ? _latestMessageKey : null,   // Add this line
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isUser ? kMessageMaxWidthUser : kMessageMaxWidthAssistant),
        ),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? AppColors.userBubble : AppColors.assistantBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isLoading)
              _buildLoadingIndicator()
            else if (msg.isStructuredSample)
              _StructuredWWJDResponse(text: msg.text, onDelveDeeper: _handleDelveDeeper)
            else if (msg.isSpiritualNourishment)
              SpiritualNourishmentSection(initialTopic: _selectedSpiritualTopic)
            else
              MarkdownBody(
              data: msg.text,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 16, height: 1.55),
                a: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
              ),
              onTapLink: (text, url, title) async {
                if (url != null) {
                  final Uri uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open link: $url')),
                    );
                  }
                }
              },
            ),

            // Action buttons for AI responses only
            if (!isUser && !msg.isLoading && !msg.isSpiritualNourishment && !msg.isStructuredSample) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _handleDelveDeeper,
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: const Text('Delve Deeper'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryMaroon),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 19),
                    onPressed: () => _copyToClipboard(msg.text),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, size: 19),
                    onPressed: () => _shareMessage(msg.text),
                  ),
                                    IconButton(
                    icon: const Icon(Icons.volume_up, size: 19),
                    onPressed: () => _speak(msg.text),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share Anonymously'),
                    onPressed: () => _shareToWalkTogether(msg),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryMaroon),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        border: Border(top: BorderSide(color: AppColors.primaryMaroon.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
            onPressed: _toggleListening,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: const InputDecoration(
                hintText: 'Bring your question or struggle… we walk together',
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _isSending ? null : _handleSend,
            child: Container(
              width: kSendButtonSize,
              height: kSendButtonSize,
              decoration: BoxDecoration(
                color: AppColors.primaryMaroon,
                borderRadius: BorderRadius.circular(28),
              ),
              child: _isSending
                  ? const CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/wwjd_header.jpg',
            height: 52,
            width: 52,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 16),
          const Text(
            "Seeking God's Wisdom...",
            style: TextStyle(fontSize: 14.5, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 28,
            child: LinearProgressIndicator(
              color: AppColors.primaryMaroon,
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== MODELS DEFINED OUTSIDE THE STATE CLASS ====================

class _ChatMessage {
  final bool isUser;
  final String text;
  final bool isStructuredSample;
  final bool isLoading;
  final bool isSpiritualNourishment;
  bool isShared;                    // ← Add this
  DateTime? sharedAt;               // ← Add this (optional timestamp)

  _ChatMessage({
    required this.isUser,
    required this.text,
    this.isStructuredSample = false,
    this.isLoading = false,
    this.isSpiritualNourishment = false,
    this.isShared = false,          // default false
    this.sharedAt,
  });
}

class _StructuredWWJDResponse extends StatelessWidget {
  final String text;
  final VoidCallback onDelveDeeper;

  const _StructuredWWJDResponse({
    required this.text,
    required this.onDelveDeeper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'EXAMPLE • WWJD RESPONSE',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primaryMaroon),
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(text, style: const TextStyle(fontSize: 16.2, height: 1.58)),
        const SizedBox(height: 14),
        const Divider(),
        TextButton.icon(
          onPressed: onDelveDeeper,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Delve Deeper'),
        ),
      ],
    );
  }
}