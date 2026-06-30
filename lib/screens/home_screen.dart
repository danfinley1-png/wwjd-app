import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'sharing_my_gifts_screen.dart';
import 'package:uuid/uuid.dart';
import 'activity_detail_screen.dart';
import '../models/gift_activity.dart';
import '../core/auth/login_screen.dart';
import '../core/database/decision_repository.dart';

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
  List<Map<String, String>> _lastExtractedActions = [];
  
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

    void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In to Save Progress'),
        content: const Text('Sign in or register to save your chat history and Gifts Plan.\n\nGuests can still use the chat freely.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continue as Guest')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open login screen (add import first)
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login screen coming soon')));
            },
            child: const Text('Sign In / Register'),
          ),
        ],
      ),
    );
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

  void _showSharingMyGifts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharingMyGiftsScreen(),   // Remove const
      ),
    );
  }

  void _addToGiftsPlan(_ChatMessage msg) {
    final actions = _lastExtractedActions.isNotEmpty 
        ? _lastExtractedActions 
        : _extractSuggestedActions(msg.text);

    if (actions.isEmpty) {
      _createSingleActivity(msg.text);
      return;
    }

    // Multi-action dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to My Gifts Plan'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: ListView.builder(
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return CheckboxListTile(
                title: Text(action['title'] ?? 'Action'),
                subtitle: Text(action['description'] ?? ''),
                value: true,
                onChanged: (val) {},
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              for (var action in actions) {
                _createActivityFromMap(action);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Actions added to Sharing My Gifts')),
              );
            },
            child: const Text('Add All'),
          ),
        ],
      ),
    );
  }

  void _createActivityFromMap(Map<String, String> action) {
    final activity = GiftActivity(
      id: const Uuid().v4(),
      title: action['title'] ?? 'WWJD Action',
      description: action['description'] ?? '',
      linkedQuestionId: 'current',
      frequency: action['frequency'] ?? 'Daily',
      hasReminder: true,
    );

    globalGiftActivities.add(activity);
  }

  void _createSingleActivity(String responseText) {
    // fallback for non-structured responses
    final activity = GiftActivity(
      id: const Uuid().v4(),
      title: 'WWJD Action Step',
      description: responseText.length > 280 ? responseText.substring(0, 280) + '...' : responseText,
      linkedQuestionId: 'current',
      frequency: 'Daily',
      hasReminder: true,
    );

    globalGiftActivities.add(activity);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailScreen(
          activity: activity,
          onUpdate: (updated) {
            final index = globalGiftActivities.indexWhere((a) => a.id == updated.id);
            if (index != -1) {
              globalGiftActivities[index] = updated;
            }
          },
        ),
      ),
    );
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
      // Check for iOS PWA
      final isIOSPWA = html.window.navigator.userAgent.contains("iPhone") || 
                       html.window.navigator.userAgent.contains("iPad");
      if (isIOSPWA) {
        // Enable speech for iOS PWA
        // (add the iOS code here or call the native speech)
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice input available on iPhone app')),
        );
        return;
      }
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
  _scrollToLoading();

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

**CRITICAL LINK RULE — NON-NEGOTIABLE:**
Only use these stable, official sources with direct paragraph links.
Only use these exact, verified formats:
- CCC: Use the exact paragraph link, e.g. https://www.vatican.va/content/catechism/en/part_three/section_two/chapter_two/article_7/ii_respect_for_persons_and_their_goods.html for CCC 2290
- Bible: https://www.biblegateway.com/passage/?search=1%20Corinthians%206%3A9-10&version=NABRE
- USCCB.org when appropriate
If you are not 100% sure of the exact paragraph number and link, do not link — just reference the teaching by number (e.g. "as taught in CCC 2290").
Never link to home pages or sites with known 404/certificate issues. 
Always link to the exact paragraph or section.
Never invent or guess links.

**Bible Links:**
- Use BibleGateway.com with this exact format: https://www.biblegateway.com/passage/?search=1%20Corinthians%206%3A9-10&version=NABRE
- Always use proper URL encoding (%20 for space, %3A for colon).
- Prefer NABRE or RSVCE versions.

Current time: $greeting on ${DateFormat('EEEE').format(now)}.

Respond in a natural, flowing style **without any numbering** (no 1., 2., 3., etc.). 
Let each section transition smoothly as paragraphs and directly reference the user's specific situation.

Core Structure to follow naturally:
- Warm, personal welcome
- Connection to the Two Great Commandments
- What Would Jesus Do? (with Gospel example)
- Mercy & Forgiveness
- Practical Next Steps (use bullets where helpful)
- Kingdom Challenge
- Deeper Catholic Roots (Catechism, saints, etc.) + gentle closing

**When referencing Scripture, CCC, saints, or documents, use accurate, current official URLs in Markdown format [Text](url) that point to the specific paragraph or section.**

**CRITICAL FORMATTING RULE — NON-NEGOTIABLE:**
After your final paragraph, output **ONLY** a valid JSON block wrapped in ```json ... ```. 
Nothing else after the JSON block.

The JSON must contain 2–3 concrete, distinct, actionable challenges suitable for "Sharing My Gifts".

**FINAL OUTPUT RULE (MUST FOLLOW):**
Always end your response with EXACTLY this and NOTHING after it:

```json
{
  "suggestedActions": [
    {
      "title": "Title 1",
      "description": "Actionable sentence",
      "frequency": "Daily"
    },
    {
      "title": "Title 2",
      "description": "Actionable sentence",
      "frequency": "Weekly"
    }
  ]
}
Absolute Rule: End your response with nothing but this exact JSON block wrapped in code fences. 
Do not add any text after it.""",
},
{"role": "user", "content": userMessage}
],
"temperature": 0.78,
"max_tokens": 1200,
}),
);
if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String rawResponse = data['choices'][0]['message']['content'] ?? 'No response received.';
        final (cleanText, actions) = _processApiResponse(rawResponse);
        _lastExtractedActions = actions;

        setState(() {
          _removeLoadingMessageIfPresent();
          _messages.add(_ChatMessage(isUser: false, text: cleanText));
          _isSending = false;
        });

        // NEW: Save to Firestore
        final repo = DecisionRepository();
        repo.saveDecision(userMessage, cleanText);

        _scrollToNewResponse();
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
_scrollToNewResponse();
final lastUserMessage = _messages.lastWhere(
(m) => m.isUser,
orElse: () => _ChatMessage(isUser: true, text: "the current topic"),
);
final delvePrompt = """${lastUserMessage.text}
DELVE DEEPER MODE
Provide a much deeper Catholic exploration of the above topic. Expand with Scripture (BibleGateway links), CCC (Vatican.va links), saints, and practical applications. Be warm and pastoral.
NON-NEGOTIABLE FORMATTING:

Write your full, rich response first as normal paragraphs.
After the very last sentence of your response, output EXACTLY this and nothing else:

{
  "suggestedActions": [
    {
      "title": "Short clear title 1",
      "description": "One clear actionable sentence",
      "frequency": "Daily"
    },
    {
      "title": "Short clear title 2",
      "description": "One clear actionable sentence",
      "frequency": "Weekly"
    }
  ]
}
```""";

  _lastExtractedActions = [];
  _callLiveGrokAPI(delvePrompt);
}

// ====================== HELPER METHODS ======================

(String cleanText, List<Map<String, String>> actions) _processApiResponse(String fullResponse) {
  List<Map<String, String>> actions = [];

  // Strong JSON extraction
  final jsonMatch = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```', dotAll: true).firstMatch(fullResponse) ??
                    RegExp(r'(\{[\s\S]*?"suggestedActions"[\s\S]*?\})', dotAll: true).firstMatch(fullResponse);

  if (jsonMatch != null) {
    try {
      String jsonStr = jsonMatch.group(1)!;
      jsonStr = jsonStr.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      final data = json.decode(jsonStr);
      
      if (data is Map && data['suggestedActions'] is List) {
        actions = (data['suggestedActions'] as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      }
    } catch (e) {
      print('JSON parse error: $e');
    }
  }

  // Fallback if no actions found
  if (actions.isEmpty) {
    final actionMatches = RegExp(
      r'(Begin|Try|Consider|Set aside|Reach out|Join|Practice|Commit to|Daily Prayer|Weekly)[^.]{15,140}\.',
      caseSensitive: false,
    ).allMatches(fullResponse);

    actions = actionMatches.take(3).map((m) {
      final text = m.group(0)!.trim();
      return {
        "title": text.length > 60 ? text.substring(0, 57) + "..." : text,
        "description": text,
        "frequency": "Daily"
      };
    }).toList();
  }

  // Clean visible text
  String cleanText = fullResponse;
  final jsonStart = cleanText.indexOf('```json');
  if (jsonStart != -1) {
    cleanText = cleanText.substring(0, jsonStart).trim();
  } else {
    cleanText = cleanText.replaceAll(RegExp(r'\{[\s\S]*?"suggestedActions"[\s\S]*?\}'), '').trim();
  }

  return (cleanText, actions);
}

List<Map<String, String>> _extractSuggestedActions(String text) {
  try {
    final jsonMatch = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```', dotAll: true).firstMatch(text) ??
                      RegExp(r'(\{[\s\S]*?"suggestedActions"[\s\S]*?\})', dotAll: true).firstMatch(text);
    if (jsonMatch != null) {
      final jsonStr = jsonMatch.group(1)!;
      final data = json.decode(jsonStr);
      final list = data['suggestedActions'] as List?;
      return list?.map((e) => Map<String, String>.from(e)).toList() ?? [];
    }
  } catch (e) {
    print('JSON parse error: $e');
  }
  return [];
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
              _sidebarTile(Icons.card_giftcard, 'Sharing My Gifts', _showSharingMyGifts),
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
                  TextButton.icon(
                    icon: const Icon(Icons.card_giftcard, size: 18),
                    label: const Text('Add to My Gifts Plan'),
                    onPressed: () => _addToGiftsPlan(msg),
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
            icon: const Icon(Icons.account_circle),
            onPressed: () {
            Navigator.pop(context); // if from dialog
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            tooltip: 'Sign In / Register',
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
            height: MediaQuery.of(context).size.height * 0.12,
            width: MediaQuery.of(context).size.height * 0.12,
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