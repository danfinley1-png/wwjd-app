import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../widgets/spiritual_nourishment_section.dart';
import '../core/app_colors.dart';

/// The primary screen for the WWJD Catholic Dialog experience.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasShownInitialDemo = false;

  bool _isMockMode = false;
  bool _isSending = false;

  static const double kDesktopBreakpoint = 900.0;
  static const double kHeaderLogoSize = 74.0;
  static const double kSendButtonSize = 48.0;
  static const double kEmptyStateIconSize = 96.0;
  static const double kAppBarHeight = 102.0;
  static const double kSidebarWidth = 290.0;
  static const double kMessageMaxWidthUser = 0.78;
  static const double kMessageMaxWidthAssistant = 0.92;
  static const double kLoadingImageSize = 42.0;

  static const String _primarySampleResponse = '''[Your full primary response text]''';

  static const String _delveDeeperResponse = '''[Your full delve deeper response text]''';

    @override
  void initState() {
    super.initState();
    _loadSeekingGodsWisdomScreen();
  }

  void _loadSeekingGodsWisdomScreen() {
    _messages.clear();

    _messages.add(_ChatMessage(
      isUser: false,
      text: "Welcome to Seeking God's Wisdom.\n\n"
          "This is the main space where you can bring any question, struggle, decision, or moral dilemma you are facing.\n\n"
          "Type your question above, and WWJD will share faithful Catholic guidance rooted in Scripture, the Catechism, and Church teaching.\n\n"
          "Here is an example of how the app works:",
    ));

    _messages.add(_ChatMessage(
      isUser: true,
      text: 'I’m struggling to forgive a family member who betrayed my trust. What would Jesus do?',
    ));

    _messages.add(_ChatMessage(
      isUser: false,
      text: _primarySampleResponse,
      isStructuredSample: true,
    ));

    // Scroll to top
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    });
  }  void _loadSeekingGodsWisdomScreen() { ... }

  // ←←← PUT IT HERE ←←←
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

    Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _isSending = true;
      _isLoadingResponse = true;
    });

    _controller.clear();
    _scrollToBottom();   // Scroll after user message

    try {
      if (_isMockMode) {
        await Future.delayed(const Duration(milliseconds: 800));
        final mockReply = 'Thank you for sharing this with our community. The WWJD framework applies directly here.';

        setState(() {
          _messages.add(_ChatMessage(isUser: false, text: mockReply));
          _isSending = false;
          _isLoadingResponse = false;
        });
      } else {
        await _callLiveGrokAPI(text);
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          isUser: false,
          text: '⚠️ Connection error. Please check your xAI API key.',
        ));
        _isSending = false;
        _isLoadingResponse = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _callLiveGrokAPI(String userMessage) async {
    setState(() => _isSending = true);

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
              "content": """You are WWJD, a warm, faithful Catholic moral advisor.
               "You are WWJD, a warm, faithful Catholic advisor. Always respond using the exact 7-part structure from REQUIREMENTS.md **without any numbering** (1., 2., 3.). Make each section flow naturally as paragraphs and directly reference the user's specific situation in each section."
Respond using this exact 7-part structure:
1. Warm welcome to the community
2. Reference to the Two Great Commandments
3. What Would Jesus Do? (Gospel example)
4. Mercy & Forgiveness section
5. Practical Next Steps (bullet points)
6. Kingdom Challenge
7. Deeper Catholic Roots (CCC, saints, etc.) + final disclaimer

Stay reverent, encouraging, and fully aligned with Catholic teaching. Never speak in first person as Jesus."""
            },
            {"role": "user", "content": userMessage}
          ],
          "temperature": 0.75,
          "max_tokens": 1100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String liveResponse = data['choices'][0]['message']['content'] ?? 'No response received.';

        _removeLoadingMessageIfPresent();
        setState(() {
          _messages.add(_ChatMessage(isUser: false, text: liveResponse));
        });
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _removeLoadingMessageIfPresent();
      setState(() {
        _messages.add(_ChatMessage(
          isUser: false,
          text: '⚠️ Live API Error:\n$e\n\nPlease verify your xAI key in config.dart is correct and active.',
        ));
      });
    } finally {
      setState(() => _isSending = false);
    }
    _scrollToBottom();
  }

  void _handleDelveDeeper() {
    final lastUser = _messages.lastWhere((m) => m.isUser, orElse: () => _ChatMessage(isUser: true, text: "this topic"));
    final delvePrompt = "Delve much deeper into the user's question: ${lastUser.text}";

    if (_isMockMode) {
      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: _delveDeeperResponse));
      });
    } else {
      _callLiveGrokAPI(delvePrompt);
      return;
    }
    _scrollToBottom();
  }

  void _showSpiritualNourishment() {
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(
        isUser: false,
        text: '',
        isSpiritualNourishment: true,
      ));
    });
    _scrollToBottom();
  }

  void _showModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WWJD Response Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Mock Mode'),
              subtitle: const Text('Safe, hand-crafted Catholic responses'),
              value: _isMockMode,
              onChanged: (val) {
                setState(() => _isMockMode = val);
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              title: const Text('Live Mode'),
              subtitle: const Text('Real Grok + xAI API'),
              value: !_isMockMode,
              onChanged: (val) {
                setState(() => _isMockMode = !val);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildSidebar({bool isInDrawer = false}) {
    return Container(
      width: isInDrawer ? null : kSidebarWidth,
      color: AppColors.sidebarBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text('Tools for the Journey', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text('Spiritual Nourishment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _sidebarTile(Icons.church_outlined, 'Attend Mass', _showMass),
              _sidebarTile(Icons.refresh, 'Go to Confession', _showConfession),
              _sidebarTile(Icons.favorite_border, 'Eucharistic Adoration', _showAdoration),
              _sidebarTile(Icons.assignment_outlined, 'Examination of Conscience', _showExaminationOfConscience),
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

  //void _showSeekingGodsWisdom() => _simpleDialog("Seeking God's Wisdom", "James 1:5 promises...");
  void _showUsingMyGifts() => _simpleDialog("Using My Gifts for the Kingdom", "Each of us has received a gift...");
  //void _showMyMoralDilemmas() => _simpleDialog("My Moral Dilemmas", "This is the heart of our shared journey...");
  void _showMyHistory() => _simpleDialog("My History", "Saved conversations...");
  void _showTermsAndPrivacy() => _simpleDialog("Terms & Privacy", "Full policy...");
  void _showMass() => _simpleDialog("Attend Mass", "The Eucharist is the source...");
  void _showConfession() => _simpleDialog("Go to Confession", "God’s mercy is infinite...");
  void _showAdoration() => _simpleDialog("Eucharistic Adoration", "Jesus is truly present...");
  void _showExaminationOfConscience() => _simpleDialog("Examination of Conscience", "A simple nightly examen...");

  void _showWalkTogether() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Walk Together'),
        content: const Text('This community feature will let the faithful share...'),
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
                    Expanded(
                      child: _messages.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[_messages.length - 1 - index];
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
                  Text(AppConfig.tagline, style: const TextStyle(fontSize: 12, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  errorBuilder: (_, __, ___) => const Icon(Icons.church, size: 48, color: Colors.white70),
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

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isUser ? kMessageMaxWidthUser : kMessageMaxWidthAssistant)),
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
              const SpiritualNourishmentSection()
            else
              SelectableText(msg.text, style: const TextStyle(fontSize: 16, height: 1.55)),

            if (!isUser && !msg.isLoading && !msg.isSpiritualNourishment) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _handleDelveDeeper,
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: const Text('Delve Deeper'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryMaroon),
                  ),
                  IconButton(icon: const Icon(Icons.copy, size: 19), onPressed: () => _copyToClipboard(msg.text)),
                  IconButton(icon: const Icon(Icons.share, size: 19), onPressed: () => _shareMessage(msg.text)),
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
              decoration: const InputDecoration(hintText: 'Bring your question or struggle… we walk together'),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _isSending ? null : _handleSend,
            child: Container(
              width: kSendButtonSize,
              height: kSendButtonSize,
              decoration: BoxDecoration(color: AppColors.primaryMaroon, borderRadius: BorderRadius.circular(28)),
              child: _isSending
                  ? const CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _StructuredWWJDResponse extends StatelessWidget {
  final String text;
  final VoidCallback onDelveDeeper;

  const _StructuredWWJDResponse({required this.text, required this.onDelveDeeper});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
          child: const Text('EXAMPLE • WWJD RESPONSE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primaryMaroon)),
        ),
        const SizedBox(height: 12),
        SelectableText(text, style: const TextStyle(fontSize: 16.2, height: 1.58)),
        const SizedBox(height: 14),
        const Divider(),
        TextButton.icon(onPressed: onDelveDeeper, icon: const Icon(Icons.menu_book_outlined), label: const Text('Delve Deeper')),
      ],
    );
  }
}

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