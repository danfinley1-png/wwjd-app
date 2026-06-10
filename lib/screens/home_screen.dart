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
  final List<_ChatMessage> _savedSeekingWisdomMessages = [];
  final GlobalKey _latestMessageKey = GlobalKey();

  bool _isMockMode = false;
  bool _isSending = false;

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
      // Only show welcome if no user messages yet
      if (_messages.isEmpty || !_messages.any((m) => m.isUser)) {
        _messages.add(_ChatMessage(
          isUser: false,
          text: "Welcome to Seeking God's Wisdom.\n\n"
              "Bring any question, struggle, or decision.",
        ));
      }
      _savedSeekingWisdomMessages.clear();
      _savedSeekingWisdomMessages.addAll(List.from(_messages));
    });
    _scrollToTop();
  }
  void _showSeekingGodsWisdom() {
    setState(() {
      if (_savedSeekingWisdomMessages.isEmpty) {
        _savedSeekingWisdomMessages.addAll(List.from(_messages));
      } else {
        _messages.clear();
        _messages.addAll(_savedSeekingWisdomMessages);
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
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(
        isUser: false,
        text: "**My History**\n\n"
            "Saved conversations and past reflections will appear here in a future update.",
      ));
    });
    _scrollToTop();
  }
  void _shareToWalkTogether(_ChatMessage msg) {
    // Find most recent user question
    String userQuestion = "No specific question found";
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        userQuestion = _messages[i].text;
        break;
      }
    }

    // Build full response by collecting the latest AI response + any Delve Deeper
    String fullResponse = msg.text;

    // Look for Delve Deeper in recent messages
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].text.contains("Delve Deeper") || 
          (_messages[i].text.length > 300 && !fullResponse.contains(_messages[i].text))) {
        fullResponse += "\n\n--- Delve Deeper ---\n${_messages[i].text}";
        break;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share to Walk Together'),
        content: const Text(
          'This will share your question + the complete WWJD response (including Delve Deeper if available).',
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

    _scrollToTop();   // Scroll to top so content is visible
  }

  void _scrollToTop() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    });
  }

  void _removeLoadingMessageIfPresent() {
    _messages.removeWhere((m) => m.isLoading);
  }

  void _scrollToNewResponse() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_latestMessageKey.currentContext != null) {
        final RenderBox? renderBox = _latestMessageKey.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          final scrollOffset = _scrollController.offset + position.dy - 100; // 100px padding from top

          _scrollController.animateTo(
            scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _messages.add(_ChatMessage(isUser: false, text: '', isLoading: true)); // Show image
      _isSending = true;
    });
    _controller.clear();
    _scrollToNewResponse();

    try {
      if (_isMockMode) {
        await Future.delayed(const Duration(milliseconds: 800));
        _removeLoadingMessageIfPresent();   // ← Clean first
        setState(() {
          _messages.add(_ChatMessage(isUser: false, text: 'Thank you for trusting our community...'));
          _isSending = false;
        });
      } else {
        await _callLiveGrokAPI(text);
      }
    } catch (e) {
      _removeLoadingMessageIfPresent();
      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: '⚠️ Connection error...'));
        _isSending = false;
      });
    }
    _scrollToNewResponse();
  }

  Future<void> _callLiveGrokAPI(String userMessage) async {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? "Good morning" : now.hour < 17 ? "Good afternoon" : "Good evening";

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
Let each section transition smoothly as paragraphs and directly reference USer's specific situation.
Do not use the language that makes the application respond as a person.

Core Structure to follow naturally:
- Warm, personal welcome
- Connection to the Two Great Commandments
- What Would Jesus Do? (with Gospel example)
- Mercy & Forgiveness
- Practical Next Steps (use bullets where helpful)
- Kingdom Challenge
- Deeper Catholic Roots (Catechism, saints, etc.) + gentle closing

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

        _removeLoadingMessageIfPresent();   // ← Important
        setState(() {
          _messages.insert(0, _ChatMessage(isUser: false, text: liveResponse));
        });
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      _removeLoadingMessageIfPresent();   // ← Important
      setState(() {
        _messages.insert(0, _ChatMessage(
          isUser: false,
          text: '⚠️ Live API Error:\n$e\n\nPlease check your xAI key in config.dart',
        ));
      });
    }
  }

      void _handleDelveDeeper() {
    _removeLoadingMessageIfPresent(); // Clean any previous loading

    setState(() {
      _messages.add(_ChatMessage(isUser: false, text: '', isLoading: true)); // Show image
    });
    _scrollToNewResponse();

    final lastUserMessage = _messages.lastWhere(
      (m) => m.isUser,
      orElse: () => _ChatMessage(isUser: true, text: "the current topic"),
    );

    final delvePrompt = """Delve much deeper into: ${lastUserMessage.text}";Please provide a much deeper, richer Catholic exploration of this specific question. 
Expand with more Scripture, CCC references, saints, and practical applications.
Maintain the exact 7-part WWJD structure. Be warm and pastoral. Avoid duplications of the initial response unless providing significant expansion of the specific point.
""";

    if (_isMockMode) {
      _removeLoadingMessageIfPresent();
      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: _delveDeeperResponse));
      });
    } else {
      _callLiveGrokAPI(delvePrompt);
      return;
    }

    _scrollToNewResponse();
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
              _sidebarTile(Icons.lightbulb_outline, "Seeking God's Wisdom", _showSeekingGodsWisdom),
              _sidebarTile(Icons.card_giftcard, 'Using My Gifts for the Kingdom', _showUsingMyGifts),
              _sidebarTile(Icons.balance, 'My Moral Dilemmas', _showMyMoralDilemmas),
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
                    // Sticky User Question Area (always visible at top)
                    if (_messages.isNotEmpty && _messages.any((m) => m.isUser))
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.userBubble,
                          border: Border(bottom: BorderSide(color: AppColors.primaryMaroon.withValues(alpha: 0.1))),
                        ),
                        child: SelectableText(
                          _messages.firstWhere((m) => m.isUser).text,
                          style: const TextStyle(fontSize: 16, height: 1.55, color: Colors.black87),
                        ),
                      ),

                    // Scrollable Response Area
                    Expanded(
                      child: _messages.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              SelectableText(msg.text, style: const TextStyle(fontSize: 16, height: 1.55)),

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

  _ChatMessage({
    required this.isUser,
    required this.text,
    this.isStructuredSample = false,
    this.isLoading = false,
    this.isSpiritualNourishment = false,
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