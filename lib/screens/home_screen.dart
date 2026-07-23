import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'sharing_my_gifts_screen.dart';
import 'package:uuid/uuid.dart';
import 'activity_detail_screen.dart';
import '../models/gift_activity.dart';
import '../models/chat_message.dart';
import '../core/auth/auth_service.dart';
import '../core/services/gift_service.dart';
import '../core/services/voice_service.dart';
import '../core/providers/app_providers.dart';
import '../widgets/auth_modal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config.dart';
import '../core/wwjd_system_prompt.dart';
import '../widgets/spiritual_nourishment_section.dart';
import '../core/app_colors.dart';
import '../core/responsive_layout.dart';
import '../walk_together_screen.dart';
import 'my_history_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/share_button.dart';
import '../widgets/welcome_dialog.dart';
import '../widgets/auth_layout.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final GlobalKey _homeKey = GlobalKey();

  // Shared journeys for Walk Together
  final List<Map<String, dynamic>> _sharedJourneys = [];

  final GlobalKey _latestMessageKey = GlobalKey();

  // Speech
  final VoiceService _voiceService = VoiceService();
  bool _isListening = false;

  // Services (via Riverpod)
  AuthService get _authService => ref.read(authServiceProvider);
  GiftService get _giftService => ref.read(giftServiceProvider);
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  String? _userId;

  // Other state
  List<Map<String, String>> _lastExtractedActions = [];
  bool _isMockMode = false;
  bool _isSending = false;
  String? _selectedSpiritualTopic;

  static bool _hasShownWelcome = false;

  static const double kSendButtonSize = 48.0;
  static const double kEmptyStateIconSize = 96.0;
  static const double kMessageMaxWidthUser = 0.78;
  static const double kMessageMaxWidthAssistant = 0.92;

  static const String _delveDeeperResponse = '''
Delve Deeper – Additional Light from the Church’s Treasury
... [your full delve deeper text here]
''';

@override
void initState() {
  super.initState();
  _initVoice();
  WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
}

Future<void> _initVoice() async {
  await _voiceService.initialize(
    onPartialText: (text) {
      if (mounted) setState(() => _controller.text = text);
    },
    onListeningChanged: (listening) {
      if (mounted) setState(() => _isListening = listening);
    },
    onError: (message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    },
  );
}

@override
void dispose() {
  _voiceService.dispose();
  _controller.dispose();
  _scrollController.dispose();
  super.dispose();
}

Future<void> _bootstrap() async {
  if (!mounted) return;

  await ref.read(authServiceProvider).waitForAuthReady();
  final user = _authService.currentUser;

  if (user != null) {
    await _loadSessionFromFirebase();
  } else {
    _loadSeekingGodsWisdomScreen();
  }

  if (user == null && !_hasShownWelcome) {
    _hasShownWelcome = true;
    showWelcomeDialog(context, ref);
  }
}

  List<ChatMessage> get _sessionHistory => ref.read(sessionHistoryProvider);

  ChatMessage _staticPrompt(String text) => ChatMessage(
        isUser: false,
        text: text,
        isStaticPrompt: true,
      );

  ChatMessage _welcomeMessage() => _staticPrompt(
        "Welcome to Seeking God's Wisdom.\n\nBring any question, struggle, or decision.",
      );

  /// Load history from Firebase, merge guest cache, update provider and UI.
  Future<void> _loadSessionFromFirebase() async {
    try {
      await ref.read(sessionHistoryProvider.notifier).loadSessionFromFirebase();
      if (!mounted) return;
      _applySessionHistoryToMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load history: $e')),
        );
      }
    }
  }

  /// Persist only real conversation messages (excludes welcome/static prompts).
  Future<void> _saveSessionToFirebase() async {
    try {
      final conversation = _messages.where((m) => m.isPersistable).toList();
      await ref.read(sessionHistoryProvider.notifier).saveSessionToFirebase(conversation);
    } catch (e) {
      debugPrint('Save history error: $e');
    }
  }

  void _applySessionHistoryToMessages() {
    final hadConversation = _sessionHistory.isNotEmpty;
    setState(() {
      final history = _sessionHistory;
      if (history.isNotEmpty) {
        _messages.clear();
        _messages.addAll(history);
      } else if (_messages.isEmpty) {
        _messages.add(_welcomeMessage());
      }
    });
    _scrollAfterMessagesUpdated(scrollToLatest: hadConversation);
  }

  void _loadSeekingGodsWisdomScreen() {
    final hadConversation = _sessionHistory.isNotEmpty;
    setState(() {
      if (_messages.isEmpty) {
        _messages.add(_welcomeMessage());
      }

      final history = _sessionHistory;
      if (history.isNotEmpty) {
        _messages.clear();
        _messages.addAll(history);
      }
    });
    _scrollAfterMessagesUpdated(scrollToLatest: hadConversation);
  }

  /// Ensures a Firebase user exists (anonymous guest if needed) for Firestore writes.
  Future<String?> _ensureAuthUidForGifts() async {
    var user = _authService.currentUser;
    if (user != null) return user.uid;

    try {
      await ref.read(authCoordinatorProvider).continueAsGuest();
      return _authService.currentUser?.uid;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save gift: $e')),
        );
      }
      return null;
    }
  }

  void _showSeekingGodsWisdom() {
    final hadConversation = _sessionHistory.isNotEmpty;
    setState(() {
      _messages.clear();
      _messages.addAll(_sessionHistory);
      if (_messages.isEmpty) {
        _messages.add(_welcomeMessage());
      }
    });
    _scrollAfterMessagesUpdated(scrollToLatest: hadConversation);
  }

  void _showSharingMyGifts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SharingMyGiftsScreen(),
      ),
    ).then((_) {
      if (mounted) _applySessionHistoryToMessages();
    });
  }

  void _addToGiftsPlan(ChatMessage msg) {
  final actions = _lastExtractedActions.isNotEmpty
      ? _lastExtractedActions 
      : _extractSuggestedActions(msg.text);

  if (actions.isEmpty) {
    _createSingleActivity(msg.text);
    return;
  }

  // Compact dialog — only shows the action(s), no full expanded view
  showDialog(
    context: context,
    builder: (context) {
      final compact = isCompactWidth(context);
      final maxHeight = MediaQuery.sizeOf(context).height * (compact ? 0.55 : 0.4);

      return ResponsiveAuthDialog(
        title: const Text('Add to My Gifts Plan'),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight.clamp(180, 420)),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                isThreeLine: true,
                leading: const Icon(Icons.card_giftcard, color: Colors.brown),
                title: Text(
                  action['title'] ?? 'Action',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${action['description'] ?? ''}\n${action['frequency'] ?? 'Daily'}',
                ),
              );
            },
          ),
        ),
        actions: AuthDialogActions(
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                final linkedQuestion = _getLatestUserQuestion();
                final linkedResponse = msg.text;
                for (var action in actions) {
                  _createActivityFromMap(
                    action,
                    linkedQuestion: linkedQuestion,
                    linkedResponse: linkedResponse,
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to Sharing My Gifts')),
                );
              },
              child: const Text('Add to Plan'),
            ),
          ],
        ),
      );
    },
  );
}
  Future<void> _createActivityFromMap(
    Map<String, String> action, {
    String? linkedQuestion,
    String? linkedResponse,
  }) async {
    final uid = await _ensureAuthUidForGifts();
    if (uid == null) return;

    final activity = GiftActivity(
      id: const Uuid().v4(),
      title: action['title'] ?? 'WWJD Action',
      description: action['description'] ?? '',
      linkedQuestionId: 'current',
      linkedQuestionText: linkedQuestion,
      linkedResponseText: linkedResponse,
      frequency: action['frequency'] ?? 'Daily',
      hasReminder: true,
      userId: uid,
      createdAt: DateTime.now(),
    );

    try {
      await _giftService.saveGift(activity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to Sharing My Gifts')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

    Future<void> _createSingleActivity(String responseText) async {
    final uid = await _ensureAuthUidForGifts();
    if (uid == null) return;

    String title = responseText.length > 70
        ? '${responseText.substring(0, 67)}...'
        : responseText;

    final activity = GiftActivity(
      id: const Uuid().v4(),
      title: title,
      description: responseText,
      linkedQuestionId: 'current',
      linkedQuestionText: _getLatestUserQuestion(),
      linkedResponseText: responseText,
      frequency: 'Daily',
      hasReminder: true,
      userId: uid,
      createdAt: DateTime.now(),
    );

    try {
      await _giftService.saveGift(activity);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityDetailScreen(
              activity: activity,
              onUpdate: (updated) {
                _giftService.saveGift(updated);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
    
  void _showMyMoralDilemmas() {
    setState(() {
      _messages.clear();
      _messages.add(_staticPrompt(
        "**My Moral Dilemmas**\n\n"
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
        builder: (context) => const MyHistoryScreen(),
      ),
    ).then((_) {
      if (mounted) _applySessionHistoryToMessages();
    });
  }

  void _shareToWalkTogether(ChatMessage msg) {
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

  String _getLatestUserQuestion() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        return _messages[i].text;
      }
    }
    return "No question found";
  }
  

  void _showWalkTogether() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WalkTogetherScreen(),
      ),
    );
  }

 void _showAuthModal() {
  final user = _authService.currentUser;

  if (user == null || user.isAnonymous) {
    showDialog(
      context: context,
      builder: (context) => ResponsiveAuthDialog(
        title: const Text('Save Your Journey'),
        content: const Text(
          'You are currently continuing as a Guest.\n\n'
          'Sign in or register to permanently save your history, '
          'Sharing My Gifts plan, and continue across sessions.',
        ),
        actions: AuthDialogActions(
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                showAuthModal(context, ref);
              },
              child: const Text('Sign In / Register'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel / Continue as Guest'),
            ),
          ],
        ),
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (context) => ResponsiveAuthDialog(
        title: const Text('Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Signed in as'),
            const SizedBox(height: 6),
            Text(
              user.email ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your journey is being saved automatically.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actions: AuthDialogActions(
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmLogout();
              },
              child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

  /// Shows logout confirmation — retention reminder for guests, standard confirm for signed-in users.
  void _confirmLogout() {
    final user = _authService.currentUser;
    final isGuest = user == null || user.isAnonymous;

    showDialog(
      context: context,
      builder: (ctx) => ResponsiveAuthDialog(
        title: const Text('Logout?'),
        content: Text(
          isGuest
              ? 'Log in or register to retain your session history before leaving.'
              : 'Your saved history will remain on your account. '
                  'Log in again anytime to continue your journey.\n\n'
                  'Are you sure you want to log out?',
        ),
        actions: AuthDialogActions(
          actions: [
            if (isGuest)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  showAuthModal(context, ref);
                },
                child: const Text('Log in / Register'),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetToBlankHomeScreen();
                _performLogout();
              },
              child: const Text(
                'Continue to Log out',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  /// Clears chat UI immediately — used on logout before and after auth completes.
  void _resetToBlankHomeScreen() {
    _controller.clear();
    _lastExtractedActions = [];
    _selectedSpiritualTopic = null;
    _isSending = false;
    _scaffoldKey.currentState?.closeDrawer();

    if (!mounted) return;
    setState(() {
      _messages.clear();
      _messages.add(_welcomeMessage());
    });
    _scrollToTop();
  }

  /// Sign out, clear local session, start fresh anonymous guest, return to welcome state.
  Future<void> _performLogout() async {
    final user = _authService.currentUser;
    final isRegistered = user != null && !user.isAnonymous;

    if (isRegistered) {
      try {
        await _saveSessionToFirebase();
      } catch (e) {
        debugPrint('Pre-logout save: $e');
      }
    }

    try {
      await ref.read(sessionHistoryProvider.notifier).clearSessionForLogout();
      await ref.read(authCoordinatorProvider).signOut();
      await ref.read(sessionHistoryProvider.notifier).clearSessionForLogout();
      await ref.read(authCoordinatorProvider).continueAsGuest();
      await ref.read(sessionHistoryProvider.notifier).clearSessionForLogout();
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
      return;
    }

    _hasShownWelcome = false;
    ref.read(homeRefreshKeyProvider.notifier).state++;
  }

  void _showTermsAndPrivacy() {
      setState(() {
      _messages.clear();
      _messages.add(_staticPrompt(
        "**Terms & Privacy**\n\n"
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
      _messages.add(ChatMessage(
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

  bool _hasConversationMessages() =>
      _messages.any((m) => m.isUser && !m.isStaticPrompt && m.text.isNotEmpty);

  /// After history load, scroll to the newest Q&A so the sticky header matches the view.
  void _scrollToLatestConversation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted || !_scrollController.hasClients) return;

        if (!_hasConversationMessages()) {
          _scrollToTop();
          return;
        }

        final anchor = _latestMessageKey.currentContext;
        if (anchor != null) {
          Scrollable.ensureVisible(
            anchor,
            alignment: 0.05,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
          return;
        }

        final max = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  void _scrollAfterMessagesUpdated({required bool scrollToLatest}) {
    if (scrollToLatest) {
      _scrollToLatestConversation();
    } else {
      _scrollToTop();
    }
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

  Future<void> _toggleListening() async {
    await _voiceService.toggleListening();
  }

  Future<void> _speak(String text) async {
    await _voiceService.speak(text);
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(ChatMessage(isUser: true, text: text));
      _messages.add(ChatMessage(isUser: false, text: '', isLoading: true));
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
            "content": WwjdSystemPrompt.forChat(
              timeContext: '$greeting on ${DateFormat('EEEE').format(now)}.',
            ),
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
    _messages.add(ChatMessage(isUser: false, text: cleanText));
    _isSending = false;
  });
  _scrollToNewResponse();

  // Save full conversation (user + AI)
  await _saveSessionToFirebase();
} else {
  throw Exception('API Error: ${response.statusCode}');
}
} catch (e) {
print('API Error: $e');
setState(() {
_removeLoadingMessageIfPresent();
_messages.add(ChatMessage(
isUser: false,
text: '⚠️ Live API Error:\n$e\n\nPlease check your xAI key in config.dart',
));
_isSending = false;
});
_scrollToNewResponse();
await _saveSessionToFirebase();
}
}
void _handleDelveDeeper() {
_removeLoadingMessageIfPresent();
setState(() {
_messages.add(ChatMessage(isUser: false, text: '', isLoading: true));
_isSending = true;
});
_scrollToNewResponse();
final lastUserMessage = _messages.lastWhere(
(m) => m.isUser,
orElse: () => ChatMessage(isUser: true, text: "the current topic"),
);
final delvePrompt = WwjdSystemPrompt.forDelveDeeper(
  userTopic: lastUserMessage.text,
);

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
      final list = data['suggestedActions'] as List?;
      if (list != null && list.isNotEmpty) {
        actions = WwjdSystemPrompt.normalizeSuggestedActions(
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        );
      }
    } catch (e) {
      print('JSON parse error: $e');
    }
  }

  // Safer fallback action extraction
  if (actions.isEmpty) {
    final actionMatches = RegExp(
      r'(Begin|Try|Consider|Set aside|Reach out|Join|Practice|Commit to|Daily Prayer|Weekly)[^.]{15,140}\.',
      caseSensitive: false,
    ).allMatches(fullResponse);

    actions = WwjdSystemPrompt.normalizeSuggestedActions(
      actionMatches.take(3).map((m) {
        final text = m.group(0)!.trim();
        return {
          'description': text,
          'frequency': 'Daily',
        };
      }).toList(),
    );
  }

  // Clean visible text (remove JSON)
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
    final raw = <Map<String, dynamic>>[];

    // Clean any JSON-like noise first
    String cleanedText = text.replaceAll(RegExp(r'```json[\s\S]*?```'), '')
        .replaceAll(RegExp(r'\{[\s\S]*?"suggestedActions"[\s\S]*?\}'), '');

    // Extract bullet-style actions
    final RegExp actionRegExp = RegExp(
      r'(?:^|\n)[\s•\-*]+\s*([^\n]+?)(?=\n[\s•\-*]|\n\n|$)',
      multiLine: true,
    );

    final matches = actionRegExp.allMatches(cleanedText);

    for (var match in matches) {
      final description = match.group(1)?.trim() ?? '';
      if (description.isEmpty ||
          description.length < 8 ||
          description.contains('"description"')) {
        continue;
      }

      raw.add({
        'description': description,
        'frequency': 'Daily',
      });
    }

    // Fallback: first substantive line
    if (raw.isEmpty && cleanedText.isNotEmpty) {
      final fallback = cleanedText.split('\n').firstWhere(
            (line) => line.trim().length >= 12,
            orElse: () => cleanedText.split('\n').first.trim(),
          );
      if (fallback.isNotEmpty) {
        raw.add({'description': fallback.trim(), 'frequency': 'Daily'});
      }
    }

    return WwjdSystemPrompt.normalizeSuggestedActions(raw);
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
              // Account / Sign In
              _sidebarTile(Icons.account_circle, 'Sign In / Account', _showAuthModal),

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Divider(),
              ),

              // Tools for the Journey
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text('Tools for the Journey', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _sidebarTile(Icons.lightbulb_outline, "Seeking God's Wisdom", _showSeekingGodsWisdom),
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
    return Material(                                   // ← added
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryMaroon),
        title: Text(label, style: const TextStyle(fontSize: 15)),
        onTap: onTap,
        dense: true,
      ),
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
    SharePlus.instance.share(ShareParams(text: text));
  }

    @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

      return Scaffold(
      key: _scaffoldKey,
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
                                  orElse: () => ChatMessage(isUser: true, text: ''),
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
    final compact = isCompactWidth(context);
    final barHeight = compact ? 56.0 : 90.0;

    return PreferredSize(
      preferredSize: Size.fromHeight(barHeight),
      child: Container(
        height: barHeight,
        decoration: const BoxDecoration(
          color: Color(0xFF8B1E1E),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (!isWide)
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  tooltip: 'Open menu',
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.church, size: compact ? 28 : 36, color: Colors.white),
                    SizedBox(width: compact ? 8 : 12),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            compact ? 'WWJD' : AppConfig.appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 18 : 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (!compact)
                            Text(
                              AppConfig.tagline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 12),
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
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Log out',
                onPressed: _confirmLogout,
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

 Widget _buildMessageBubble(ChatMessage msg, int index) {
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
                        // Action buttons for AI responses only
            if (msg.showsConversationActions) ...[
              const SizedBox(height: 12),
              _buildConversationActions(msg),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationActions(ChatMessage msg) {
    final compact = isCompactWidth(context);
    final maroon = TextButton.styleFrom(foregroundColor: AppColors.primaryMaroon);

    if (compact) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 2,
        runSpacing: 2,
        children: [
          IconButton(
            tooltip: 'Delve Deeper',
            icon: const Icon(Icons.expand_more, size: 22),
            onPressed: _handleDelveDeeper,
            color: AppColors.primaryMaroon,
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_outlined, size: 21),
            onPressed: () => _copyToClipboard(msg.text),
          ),
          IconButton(
            tooltip: 'Listen',
            icon: const Icon(Icons.volume_up_outlined, size: 21),
            onPressed: () => _speak(msg.text),
          ),
          ShareButton(
            question: _getLatestUserQuestion(),
            response: msg.text,
          ),
          IconButton(
            tooltip: 'Add to My Gifts Plan',
            icon: const Icon(Icons.card_giftcard_outlined, size: 21),
            onPressed: () => _addToGiftsPlan(msg),
            color: AppColors.primaryMaroon,
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 4,
      runSpacing: 4,
      children: [
        TextButton.icon(
          onPressed: _handleDelveDeeper,
          icon: const Icon(Icons.expand_more, size: 18),
          label: const Text('Delve Deeper'),
          style: maroon,
        ),
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy, size: 19),
          onPressed: () => _copyToClipboard(msg.text),
        ),
        IconButton(
          tooltip: 'Listen',
          icon: const Icon(Icons.volume_up, size: 19),
          onPressed: () => _speak(msg.text),
        ),
        ShareButton(
          question: _getLatestUserQuestion(),
          response: msg.text,
        ),
        TextButton.icon(
          icon: const Icon(Icons.card_giftcard, size: 18),
          label: const Text('Add to My Gifts Plan'),
          onPressed: () => _addToGiftsPlan(msg),
          style: maroon,
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final horizontal = responsiveHorizontalPadding(context);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          padding: horizontal.copyWith(top: 8, bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.parchment,
            border: Border(top: BorderSide(color: AppColors.primaryMaroon.withValues(alpha: 0.1))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                tooltip: _isListening ? 'Stop listening' : 'Voice input',
                onPressed: _toggleListening,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: isCompactWidth(context)
                        ? 'Your question…'
                        : 'Bring your question or struggle… we walk together',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
        ),
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