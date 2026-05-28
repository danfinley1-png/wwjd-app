import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/config.dart';
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

  bool _isMockMode = false;   // Default to Live Mode
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

  static const String _primarySampleResponse = '''
Welcome, friend. In our Catholic community we believe there is no wound, no anger, and no betrayal too heavy to bring into the light of Christ. You are safe here. Many of us have carried the same heavy stones you describe.

The Two Great Commandments frame everything: we are called to love the Lord our God with all our heart, soul, mind, and strength, and to love our neighbor as ourselves (Mark 12:30-31). This includes the neighbor who has hurt us most deeply.

What Would Jesus Do? The Gospels show us a Savior who forgave those who crucified Him while they were still mocking Him. He did not wait for their apology. He offered mercy from the Cross. In the same way, He invites us to hand over the debt we feel is owed, not because the harm was small, but because we ourselves have been shown an ocean of mercy we could never repay.

Mercy & Forgiveness. Jesus came for sinners—for those who have been sinned against and for those who have sinned. The hurt you feel is real; pretending otherwise helps no one. At the same time, the Sacrament of Reconciliation is the place where we lay down both our own sins and the right to hold others’ sins against them. There we meet the same mercy that raised Jesus from the dead.

Practical Next Steps. 
• Each morning for the next thirty days, pray one decade of the Rosary for the person who hurt you, using the Sorrowful Mysteries. 
• Write a letter you will never send in which you name the specific harms and then, at the end, write “I release this debt to the mercy of God.” 
• Speak with a trusted priest or spiritual director about the wound; do not carry it alone. 
• If safe and appropriate, take one small concrete act of kindness toward that person (a prayer, a courteous word) as an act of obedience to Christ, not as a feeling.

Kingdom Challenge. Your willingness to forgive, even when it costs, becomes a quiet witness that the world desperately needs. The freedom you gain will flow outward: you will have more room in your heart for your own family, for the poor, for the stranger, and for the work God has actually entrusted to you. That is how we build the Kingdom—one liberated heart at a time.

Deeper Catholic Roots. The Catechism teaches that “it is not in our power not to feel or to forget” an offense, but the grace of the Holy Spirit can convert our hearts (CCC 2840). The parable of the Unforgiving Servant (Matthew 18:21-35) makes the same point with unforgettable force. St. John Paul II wrote in Dives in Misericordia that mercy is the ultimate way of living the Gospel. We do not forgive because the other person deserves it; we forgive because we have been forgiven first.

WWJD is a formation aid aligned with the Magisterium. It is not a substitute for the sacraments or a priest. For grave matters, consult your pastor.
''';

  static const String _delveDeeperResponse = '''
Delve Deeper – Additional Light from the Church’s Treasury

The Catechism is very realistic about the cost of forgiveness. CCC 2840 reminds us that “it is not in our power not to feel or to forget” an offense. The grace we seek is not emotional amnesia but the supernatural strength to will the good of the one who hurt us. This is why the Lord’s Prayer is so demanding: “forgive us… as we forgive those who trespass against us.”

Jesus gives us a second, even more searching parable in Matthew 18:21-35. Peter asks how many times—seven? Jesus answers seventy times seven and then tells the story of the servant who was forgiven a colossal debt yet refused to forgive a tiny one. The point is not that God is a harsh accountant; the point is that once we have received unmerited mercy, refusing to extend it distorts our own souls and blocks the very grace we need.

St. Thomas Aquinas teaches that mercy is the virtue by which we are most closely conformed to God (Summa Theologiae II-II, q. 30). When we forgive, we are not saying “what happened is acceptable.” We are saying “I will no longer let this wound be the lens through which I view this person or my own future.” That is an act of spiritual authority given to us by Christ Himself (John 20:23).

A further practical grace: many people find it helpful to pray the Chaplet of Divine Mercy for the specific individual, inserting their name at the end of each decade: “For the sake of His sorrowful Passion, have mercy on N. and on the whole world.” The very act of interceding for the one who wounded us often loosens the grip of resentment faster than anything else.

If the relationship involves ongoing harm or danger, forgiveness does not require continued proximity or trust. Prudence and justice remain. A spiritual director can help you discern the concrete form love must take in your particular situation.

WWJD is a formation aid aligned with the Magisterium. It is not a substitute for the sacraments or a priest. For grave matters, consult your pastor.
''';

  @override
  void initState() {
    super.initState();
    if (!_hasShownInitialDemo) {
      _loadInitialSampleConversation();
      _hasShownInitialDemo = true;
    }
  }

  void _loadInitialSampleConversation() {
    _messages.addAll([
      _ChatMessage(
        isUser: true,
        text: 'I’m struggling to forgive a family member who betrayed my trust. I feel angry and hurt every time I see them. What would Jesus do?',
      ),
      _ChatMessage(
        isUser: false,
        text: _primarySampleResponse,
        isStructuredSample: true,
      ),
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _removeLoadingMessageIfPresent() {
    _messages.removeWhere((m) => m.isLoading);
  }

  Widget _buildLoadingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.assistantBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/images/wwjd_header.jpg',
              height: kLoadingImageSize,
              width: kLoadingImageSize,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.church, size: 42, color: AppColors.primaryMaroon),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seeking Wisdom...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Praying with the Church for guidance...', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          const CircularProgressIndicator(strokeWidth: 2.5),
        ],
      ),
    );
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
    _scrollToBottom();

    try {
      if (_isMockMode) {
        await Future.delayed(const Duration(milliseconds: 800));
        _removeLoadingMessageIfPresent();
        setState(() {
          _messages.add(_ChatMessage(isUser: false, text: 'Thank you for trusting our community with this. The WWJD framework shown earlier applies directly to your situation. Would you like to "Delve Deeper" on the main response?'));
          _isSending = false;
        });
      } else {
        await _callLiveGrokAPI(text);
      }
    } catch (e) {
      _removeLoadingMessageIfPresent();
      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: '⚠️ Connection error. Please check your xAI API key in lib/core/config.dart\n\nError: $e'));
        _isSending = false;
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
              _sidebarTile(Icons.lightbulb_outline, "Seeking God's Wisdom", _showSeekingGodsWisdom),
              _sidebarTile(Icons.card_giftcard, 'Using My Gifts for the Kingdom', _showUsingMyGifts),
              _sidebarTile(Icons.balance, 'My Moral Dilemmas', _showMyMoralDilemmas),
              _sidebarTile(Icons.history, 'My History', _showMyHistory),
              _sidebarTile(Icons.people_outline, 'Walk Together', _showWalkTogether),
              _sidebarTile(Icons.policy_outlined, 'Terms & Privacy', _showTermsAndPrivacy),

              const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 4), child: Divider()),

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

  void _showSeekingGodsWisdom() => _simpleDialog("Seeking God's Wisdom", "James 1:5 promises...");
  void _showUsingMyGifts() => _simpleDialog("Using My Gifts for the Kingdom", "Each of us has received a gift...");
  void _showMyMoralDilemmas() => _simpleDialog("My Moral Dilemmas", "This is the heart of our shared journey...");
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
          color: Color(0xFF8B1E1E), // your primaryMaroon
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,   // This forces vertical center
            children: [
              const Icon(Icons.church, size: 36, color: Colors.white),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConfig.appName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    AppConfig.tagline,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
            else
              SelectableText(msg.text, style: const TextStyle(fontSize: 16, height: 1.55)),

            if (!isUser && !msg.isLoading) ...[
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

  _ChatMessage({
    required this.isUser,
    required this.text,
    this.isStructuredSample = false,
    this.isLoading = false,
  });
}