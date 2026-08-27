import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'sharing_my_gifts_screen.dart';
import 'prayers_screen.dart';
import '../spiritual_nourishment/local_worship/screens/local_worship_screen.dart';
import 'package:uuid/uuid.dart';
import '../models/gift_activity.dart';
import '../models/chat_message.dart';
import '../models/reflection_source.dart';
import '../core/auth/auth_service.dart';
import '../core/services/gift_service.dart';
import '../core/services/voice_service.dart';
import '../core/providers/app_providers.dart';
import '../admin/providers/admin_providers.dart';
import '../core/providers/tts_providers.dart';
import '../core/providers/reflection_providers.dart';
import '../core/insights/pastoral_insights_config.dart';
import '../widgets/auth_modal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/chat_api_service.dart';
import '../core/analytics/usage_analytics_service.dart';
import '../core/analytics/usage_section.dart';
import '../core/content_guidance/content_guidance_logger.dart';
import '../core/content_guidance/content_guidance_dialogs.dart';
import '../core/content_guidance/private_content_guidance.dart';
import '../core/config.dart';
import '../core/catholic_prayers/prayer_request_detector.dart';
import '../core/catholic_prayers/prayer_response_builder.dart';
import '../core/wwjd_system_prompt.dart';
import '../widgets/mobile_home_app_bar.dart';
import '../widgets/home_pending_invites_section.dart';
import '../widgets/spiritual_nourishment_section.dart';
import '../core/app_colors.dart';
import '../core/gift_reminder_utils.dart';
import '../core/mobile_touch.dart';
import '../core/mobile_web_input.dart';
import '../core/responsive_layout.dart';
import '../walk_together_screen.dart';
import 'my_history_screen.dart';
import 'edit_profile_screen.dart';
import 'my_reflections_screen.dart';
import 'ministry_insights_screen.dart';
import '../widgets/linked_markdown_body.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/share_button.dart';
import '../widgets/reflection_composer.dart';
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
  final FocusNode _inputFocusNode = FocusNode();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final GlobalKey _homeKey = GlobalKey();

  // Shared journeys for Walk Together — persisted in Firestore (see WalkTogetherService).

  final GlobalKey _latestMessageKey = GlobalKey();

  // Speech
  VoiceService? _voiceService;
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
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _voiceService = VoiceService();
    _initVoice();
    _initReadAloud();
  });
  WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
}

Future<void> _initVoice() async {
  final voiceService = _voiceService;
  if (voiceService == null) return;
  await voiceService.initialize(
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

Future<void> _initReadAloud() async {
  final readAloud = ref.read(ttsReadAloudProvider);
  readAloud.onError = (message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  };
  if (!readAloud.isReady) {
    await readAloud.initialize();
  }
}

@override
void dispose() {
  _voiceService?.dispose();
  _inputFocusNode.dispose();
  _controller.dispose();
  _scrollController.dispose();
  super.dispose();
}

Future<void> _bootstrap() async {
  if (!mounted) return;

  await ref.read(authServiceProvider).waitForAuthReady();
  final user = _authService.currentUser;

  if (user != null) {
    _refreshPendingInvites();
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

  ChatMessage _welcomeMessage() => _staticPrompt(AppConfig.seekingGodsWisdomWelcome);

  /// Reload pending organization and group invitations for the signed-in user.
  void _refreshPendingInvites() {
    ref.invalidate(pendingOrgInvitesForUserProvider);
    ref.invalidate(pendingGroupInvitesForUserProvider);
  }

  /// Load history from Firebase, merge guest cache, update provider and UI.
  Future<void> _loadSessionFromFirebase() async {
    try {
      _refreshPendingInvites();
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

  void _trackUsageSection(UsageSection section) {
    UsageAnalyticsService.instance.trackSectionView(section);
  }

  void _showSeekingGodsWisdom() {
    _trackUsageSection(UsageSection.seekingWisdom);
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

  void _showMyReflections() {
    _trackUsageSection(UsageSection.myReflections);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => const MyReflectionsScreen(),
      ),
    );
  }

  void _showMinistryInsights() {
    _trackUsageSection(UsageSection.pastoralInsights);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => const MinistryInsightsScreen(),
      ),
    );
  }

  void _showSharingMyGifts() {
    _trackUsageSection(UsageSection.sharingGifts);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SharingMyGiftsScreen(),
      ),
    ).then((_) {
      if (mounted) _applySessionHistoryToMessages();
    });
  }

  void _showPrayers() {
    _trackUsageSection(UsageSection.prayers);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => const PrayersScreen(),
      ),
    );
  }

  void _showLocalWorship({String? tab}) {
    _trackUsageSection(UsageSection.localWorship);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => LocalWorshipScreen(initialKindId: tab),
      ),
    );
  }

  void _showOrgCalendar() {
    _showLocalWorship(tab: 'school');
  }

  void _showEditProfile() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    );
  }

  List<Map<String, String>> _actionsForMessage(ChatMessage msg) {
    if (msg.suggestedActions != null && msg.suggestedActions!.isNotEmpty) {
      return msg.suggestedActions!;
    }
    final isLatestAi = _messages.isNotEmpty && identical(_messages.last, msg);
    if (isLatestAi && _lastExtractedActions.isNotEmpty) {
      return _lastExtractedActions;
    }
    return WwjdSystemPrompt.extractSuggestedActionsFromResponse(msg.text);
  }

  Future<void> _addToGiftsPlan(ChatMessage msg) async {
    var actions = _actionsForMessage(msg);
    actions = WwjdSystemPrompt.sanitizeGiftActions(actions, msg.text);

    if (actions.isEmpty) {
      actions = WwjdSystemPrompt.buildFallbackGiftActions(
        msg.text,
        userQuestion: _getUserQuestionForMessage(msg),
      );
    }

    if (actions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not find a specific action in this response. Try Delve Deeper or ask again.',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final existingGifts = await _giftService.getUserGifts();
    if (!mounted) return;

    final selected = await showDialog<List<Map<String, String>>>(
      context: context,
      builder: (dialogContext) {
        return _AddGiftsPlanDialog(
          actions: actions,
          existingGifts: existingGifts,
          giftService: _giftService,
        );
      },
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    final uid = await _ensureAuthUidForGifts();
    if (uid == null || !mounted) return;

    final linkedQuestion = _getUserQuestionForMessage(msg);
    final linkedResponse = msg.text;

    try {
      final toSave = <GiftActivity>[];
      for (final action in selected) {
        toSave.add(
          GiftActivity(
            id: const Uuid().v4(),
            title: action['title'] ?? 'WWJD Action',
            description: action['description'] ?? '',
            linkedQuestionId: 'current',
            linkedQuestionText: linkedQuestion,
            linkedResponseText: linkedResponse,
            frequency: action['frequency'] ?? 'Daily',
            hasReminder: true,
            specificTime: GiftReminderUtils.formatStoredTime(
              GiftReminderUtils.defaultTime,
            ),
            userId: uid,
            createdAt: DateTime.now(),
          ),
        );
      }

      final result = await _giftService.saveGiftsSkippingDuplicates(toSave);

      if (mounted) {
        final parts = <String>[];
        if (result.added > 0) {
          parts.add(
            result.added == 1
                ? 'Added 1 item to Sharing My Gifts'
                : 'Added ${result.added} items to Sharing My Gifts',
          );
        }
        if (result.skipped > 0) {
          parts.add(
            result.skipped == 1
                ? '1 duplicate skipped'
                : '${result.skipped} duplicates skipped',
          );
        }
        if (parts.isEmpty) {
          parts.add('Selected items are already in your plan');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parts.join(' · '))),
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

  Future<void> _addToReflections(ChatMessage msg) async {
    final uid = await _ensureAuthUidForGifts();
    if (uid == null || !mounted) return;

    final question = _getUserQuestionForMessage(msg);
    final initialTitle = _reflectionTitleFromQuestion(question);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _WisdomReflectionDialog(
          question: question,
          initialTitle: initialTitle,
          onSave: ({String? title, required String body}) async {
            await ref.read(reflectionServiceProvider).createReflection(
                  title: title,
                  body: body,
                  linkedQuestionText: question,
                  linkedResponseText: msg.text,
                  source: ReflectionSource.wisdomSession,
                );
          },
        );
      },
    );
  }

  String _getUserQuestionForMessage(ChatMessage msg) {
    final index = _messages.indexOf(msg);
    if (index > 0) {
      for (var i = index - 1; i >= 0; i--) {
        final candidate = _messages[i];
        if (candidate.isUser && candidate.text.trim().isNotEmpty) {
          return candidate.text;
        }
      }
    }
    return _getLatestUserQuestion();
  }

  String _reflectionTitleFromQuestion(String question) {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return "Seeking God's Wisdom";
    if (trimmed.length <= 50) return 'Reflection: $trimmed';
    return 'Reflection: ${trimmed.substring(0, 47)}…';
  }

  Future<void> _createActivityFromMap(
    Map<String, String> action, {
    String? linkedQuestion,
    String? linkedResponse,
    String? uid,
    bool showSnackBar = true,
  }) async {
    final resolvedUid = uid ?? await _ensureAuthUidForGifts();
    if (resolvedUid == null) return;

    final activity = GiftActivity(
      id: const Uuid().v4(),
      title: action['title'] ?? 'WWJD Action',
      description: action['description'] ?? '',
      linkedQuestionId: 'current',
      linkedQuestionText: linkedQuestion,
      linkedResponseText: linkedResponse,
      frequency: action['frequency'] ?? 'Daily',
      hasReminder: true,
      userId: resolvedUid,
      createdAt: DateTime.now(),
    );

    await _giftService.saveGift(activity);

    if (showSnackBar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to Sharing My Gifts')),
      );
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

  Future<void> _showMyHistory() async {
    _trackUsageSection(UsageSection.myHistory);
    _runFromSidebar(() async {
      try {
        await ref.read(sessionHistoryProvider.notifier).loadSessionFromFirebase();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('History load issue: $e')),
          );
        }
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MyHistoryScreen(),
        ),
      ).then((_) {
        if (mounted) _applySessionHistoryToMessages();
      });
    });
  }

  String _getLatestUserQuestion() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        return _messages[i].text;
      }
    }
    return 'No question found';
  }

  void _showWalkTogether() {
    _trackUsageSection(UsageSection.walkTogether);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WalkTogetherScreen(),
      ),
    );
  }

  void _showAuthModal() {
    _scaffoldKey.currentState?.closeDrawer();
    final user = _authService.currentUser;

    if (user == null || user.isAnonymous) {
      showDialog(
        context: context,
        builder: (dialogContext) => ResponsiveAuthDialog(
          title: const Text('Save Your Journey'),
          content: const Text(
            'You are currently continuing as a Guest.\n\n'
            'Sign in or register to permanently save your history, '
            'Sharing My Gifts plan, and continue across sessions.',
          ),
          actions: AuthDialogActions(
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(kMinTouchTarget),
                ),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _saveSessionToFirebase();
                  if (!mounted) return;
                  showAuthModal(
                    context,
                    ref,
                    onAuthSuccess: _loadSessionFromFirebase,
                  );
                },
                child: const Text('Sign In / Register'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel / Continue as Guest'),
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogContext) => ResponsiveAuthDialog(
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
                  Navigator.pop(dialogContext);
                  _confirmLogout();
                },
                child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
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
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _saveSessionToFirebase();
                  if (!mounted) return;
                  showAuthModal(
                    context,
                    ref,
                    onAuthSuccess: _loadSessionFromFirebase,
                  );
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
      ref.read(walkTogetherSessionProvider.notifier).clear();
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
    _trackUsageSection(UsageSection.spiritualNourishment);
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
    await _voiceService?.toggleListening();
  }

  Future<void> _speak(String text) async {
    final readAloud = ref.read(ttsReadAloudProvider);
    readAloud.onError ??= (message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    };
    await readAloud.speak(text);
  }

  /// Ensures anonymous Firebase auth so Firestore history can persist on web.
  Future<void> _ensureAuthForSession() async {
    if (_authService.currentUser != null) return;
    await ref.read(authCoordinatorProvider).continueAsGuest();
  }

  Future<void> _persistSessionInBackground() async {
    final persistable = _messages.where((m) => m.isPersistable).toList();
    if (persistable.isEmpty) return;

    try {
      await _ensureAuthForSession()
          .timeout(const Duration(seconds: 12));
      await _saveSessionToFirebase()
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Session persist: $e');
    }
  }

  Future<void> _handleSend() async {
    var text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final suggestion = PrivateContentGuidance().suggest(text);
    if (suggestion.hasSuggestion && mounted) {
      ContentGuidanceLogger.logPrivateSuggestionOffered();
      final chosen = await PrivateRephraseDialog.show(context, suggestion);
      if (!mounted) return;
      if (chosen == null) return;
      ContentGuidanceLogger.logPrivateSuggestionAccepted(
        accepted: chosen != suggestion.original,
      );
      text = chosen;
    }

    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(ChatMessage(isUser: true, text: text));
      _messages.add(ChatMessage(isUser: false, text: '', isLoading: true));
      _isSending = true;
    });
    _controller.clear();
    _scrollToLoading();
    _scrollToNewResponse();

    // Save in parallel — do not block the AI call (was causing infinite spinner).
    unawaited(_persistSessionInBackground());

    try {
      if (_isMockMode) {
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() {
          _removeLoadingMessageIfPresent();
          _messages.add(ChatMessage(
            isUser: false,
            text: 'Mock response for: $text',
          ));
          _isSending = false;
        });
      } else {
        await _callLiveGrokAPI(text);
      }
    } catch (e) {
      debugPrint('Send error: $e');
      if (_isSending) {
        setState(() {
          _removeLoadingMessageIfPresent();
          _isSending = false;
        });
      }
    }
    _scrollToNewResponse();
    unawaited(_persistSessionInBackground());
  }

  Future<void> _callLiveGrokAPI(String userMessage) async {
    try {
      final prayerMatch = PrayerRequestDetector.detect(userMessage);
      if (prayerMatch != null) {
        final rawResponse = PrayerResponseBuilder.build(prayerMatch);
        final (cleanText, actions) = _processApiResponse(rawResponse);
        _lastExtractedActions = actions;

        if (!mounted) return;
        setState(() {
          _removeLoadingMessageIfPresent();
          _messages.add(ChatMessage(
            isUser: false,
            text: cleanText,
            suggestedActions: actions.isNotEmpty ? actions : null,
          ));
          _isSending = false;
        });
        _scrollToNewResponse();
        unawaited(_persistSessionInBackground());
        return;
      }

      final varietyContext = await _buildGiftVarietyContext();
      final enriched = WwjdSystemPrompt.enrichUserMessageWithVarietyContext(
        userMessage,
        varietyContext,
      );
      final rawResponse = await ChatApiService.fetchResponse(
        userMessage: enriched,
      );
      final (cleanText, actions) = _processApiResponse(rawResponse);
      _lastExtractedActions = actions;

      if (!mounted) return;
      setState(() {
        _removeLoadingMessageIfPresent();
        _messages.add(ChatMessage(
          isUser: false,
          text: cleanText,
          suggestedActions: actions.isNotEmpty ? actions : null,
        ));
        _isSending = false;
      });
      _scrollToNewResponse();
      unawaited(_persistSessionInBackground());
    } on ChatApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _removeLoadingMessageIfPresent();
        _messages.add(ChatMessage(
          isUser: false,
          text: '⚠️ ${e.message}\n\nYour question was saved to My History.',
        ));
        _isSending = false;
      });
      _scrollToNewResponse();
      unawaited(_persistSessionInBackground());
    } catch (e) {
      debugPrint('API Error: $e');
      if (!mounted) return;
      setState(() {
        _removeLoadingMessageIfPresent();
        _messages.add(ChatMessage(
          isUser: false,
          text: '⚠️ Live API Error:\n$e\n\nYour question was saved to My History.',
        ));
        _isSending = false;
      });
      _scrollToNewResponse();
      unawaited(_persistSessionInBackground());
    }
  }
  Future<void> _callLiveGrokDelveDeeper(String delveUserMessage) async {
    try {
      final rawResponse = await ChatApiService.fetchDelveDeeperResponse(
        delveUserMessage: delveUserMessage,
      );
      final (cleanText, actions) = _processApiResponse(rawResponse);
      _lastExtractedActions = actions;

      if (!mounted) return;
      setState(() {
        _removeLoadingMessageIfPresent();
        _messages.add(ChatMessage(
          isUser: false,
          text: cleanText,
          suggestedActions: actions.isNotEmpty ? actions : null,
        ));
        _isSending = false;
      });
      _scrollToNewResponse();
      unawaited(_persistSessionInBackground());
    } on ChatApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _removeLoadingMessageIfPresent();
        _messages.add(ChatMessage(
          isUser: false,
          text: '⚠️ ${e.message}\n\nYour question was saved to My History.',
        ));
        _isSending = false;
      });
      _scrollToNewResponse();
      unawaited(_persistSessionInBackground());
    } catch (e) {
      debugPrint('Delve Deeper API Error: $e');
      if (!mounted) return;
      setState(() {
        _removeLoadingMessageIfPresent();
        _messages.add(ChatMessage(
          isUser: false,
          text: '⚠️ Delve Deeper error:\n$e',
        ));
        _isSending = false;
      });
      _scrollToNewResponse();
      unawaited(_persistSessionInBackground());
    }
  }

  void _handleDelveDeeper([ChatMessage? aiMessage]) {
    final targetAi = aiMessage ??
        _messages.lastWhere(
          (m) => m.showsConversationActions,
          orElse: () => ChatMessage(isUser: false, text: ''),
        );

    if (targetAi.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No response available to explore further.'),
          ),
        );
      }
      return;
    }

    _removeLoadingMessageIfPresent();
    setState(() {
      _messages.add(ChatMessage(isUser: false, text: '', isLoading: true));
      _isSending = true;
    });
    _scrollToNewResponse();
    unawaited(_handleDelveDeeperAsync(targetAi));
  }

  Future<String> _buildGiftVarietyContext() async {
    final giftSummaries = <String>[];
    try {
      final gifts = await _giftService.getUserGifts();
      for (final gift in gifts.take(20)) {
        final title = gift.title.trim();
        final description = gift.description.trim();
        if (title.isEmpty && description.isEmpty) continue;
        giftSummaries.add(
          title.isEmpty ? '- $description' : '- $title: $description',
        );
      }
    } catch (e) {
      debugPrint('Gift variety context: $e');
    }

    final sessionActions = <String>[];
    final seen = <String>{};
    for (final message in _messages) {
      final actions = message.suggestedActions;
      if (actions == null) continue;
      for (final line in WwjdSystemPrompt.summarizeSuggestedActions(actions)) {
        if (seen.add(line)) sessionActions.add(line);
      }
    }
    for (final line in WwjdSystemPrompt.summarizeSuggestedActions(
      _lastExtractedActions,
    )) {
      if (seen.add(line)) sessionActions.add(line);
    }

    return WwjdSystemPrompt.buildVarietyAvoidanceContext(
      recentGiftSummaries: giftSummaries,
      sessionActionSummaries: sessionActions,
    );
  }

  Future<void> _handleDelveDeeperAsync(ChatMessage targetAi) async {
    final index = _messages.indexOf(targetAi);
    var userQuestion = 'the current topic';
    if (index > 0) {
      for (var i = index - 1; i >= 0; i--) {
        final candidate = _messages[i];
        if (candidate.isUser && candidate.text.trim().isNotEmpty) {
          userQuestion = candidate.text;
          break;
        }
      }
    }

    final delvePrompt = WwjdSystemPrompt.forDelveDeeper(
      userTopic: userQuestion,
      previousResponse: targetAi.text,
      varietyContext: await _buildGiftVarietyContext(),
    );

    _lastExtractedActions = [];
    await _callLiveGrokDelveDeeper(delvePrompt);
  }

// ====================== HELPER METHODS ======================

(String cleanText, List<Map<String, String>> actions) _processApiResponse(String fullResponse) {
  final actions = WwjdSystemPrompt.extractSuggestedActionsFromResponse(fullResponse);
  final cleanText = WwjdSystemPrompt.stripSuggestedActionsJson(fullResponse);
  return (cleanText, actions);
}

  void _openDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    _scaffoldKey.currentState?.openDrawer();
  }

  Widget _buildSidebar({bool isInDrawer = false}) {
    final pendingInviteCount =
        ref.watch(pendingProfileInviteCountProvider);

    final content = ListView(
      padding: EdgeInsets.only(
        top: isInDrawer ? 4 : 0,
        bottom: 12,
      ),
      children: [
        _sidebarTile(Icons.account_circle, 'Sign In / Account', _showAuthModal),
        ListTile(
          minVerticalPadding: 12,
          minLeadingWidth: 28,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          tileColor: AppColors.sidebarBackground,
          hoverColor: AppColors.primaryMaroon.withValues(alpha: 0.08),
          splashColor: AppColors.primaryMaroon.withValues(alpha: 0.12),
          leading: Badge(
            isLabelVisible: pendingInviteCount > 0,
            label: Text('$pendingInviteCount'),
            child: Icon(Icons.person_outline,
                color: AppColors.primaryMaroon, size: 24),
          ),
          title: const Text('My Profile', style: TextStyle(fontSize: 15)),
          subtitle: pendingInviteCount > 0
              ? Text(
                  'Notification waiting — open Messages',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : null,
          onTap: () => _runFromSidebar(_showEditProfile),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Divider(),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            'Tools for the Journey',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        _sidebarTile(Icons.lightbulb_outline, "Seeking God's Wisdom", _showSeekingGodsWisdom),
        _sidebarTile(Icons.card_giftcard, 'Sharing My Gifts', _showSharingMyGifts),
        _sidebarTile(Icons.edit_note_outlined, 'My Reflections', _showMyReflections),
        _sidebarTile(Icons.history, 'My History', _showMyHistory),
        _sidebarTile(Icons.people_outline, 'Walk Together', _showWalkTogether),
        _sidebarTile(
          Icons.calendar_month_outlined,
          'School / Organization Calendar',
          _showOrgCalendar,
        ),
        if (PastoralInsightsConfig.insightsMenuEnabled)
          _sidebarTile(
            Icons.insights_outlined,
            'Pastoral Insights',
            _showMinistryInsights,
          ),
        _sidebarTile(Icons.policy_outlined, 'Terms & Privacy', _showTermsAndPrivacy),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Divider(),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            'Spiritual Nourishment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        _sidebarTile(Icons.place_outlined, 'Near Me', _showLocalWorship),
        _sidebarTile(Icons.church_outlined, 'Attend Mass', () => _showSpiritualNourishment('mass')),
        _sidebarTile(Icons.refresh, 'Go to Confession', () => _showSpiritualNourishment('confession')),
        _sidebarTile(Icons.favorite_border, 'Eucharistic Adoration', () => _showSpiritualNourishment('adoration')),
        _sidebarTile(Icons.assignment_outlined, 'Examination of Conscience', () => _showSpiritualNourishment('examination')),
        _sidebarTile(Icons.menu_book_outlined, 'Prayers', _showPrayers),
        _sidebarTile(
          Icons.psychology_outlined,
          'Church Teaching on Artificial Intelligence',
          () => _showSpiritualNourishment('ai_teaching'),
        ),
      ],
    );

    if (isInDrawer) {
      return Material(
        color: AppColors.sidebarBackground,
        child: content,
      );
    }

    return Container(
      width: 290.0,
      color: AppColors.sidebarBackground,
      child: SafeArea(child: content),
    );
  }

  Widget _sidebarTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      minVerticalPadding: 12,
      minLeadingWidth: 28,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      tileColor: AppColors.sidebarBackground,
      hoverColor: AppColors.primaryMaroon.withValues(alpha: 0.08),
      splashColor: AppColors.primaryMaroon.withValues(alpha: 0.12),
      leading: Icon(icon, color: AppColors.primaryMaroon, size: 24),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      onTap: () => _runFromSidebar(onTap),
    );
  }

  void _runFromSidebar(VoidCallback action) {
    runSidebarAction(_scaffoldKey.currentState, action);
  }

  Future<void> _focusChatInput() async {
    await requestMobileWebKeyboard(_inputFocusNode);
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
      drawer: isWide
          ? null
          : Drawer(
              width: 290,
              child: SafeArea(
                child: _buildSidebar(isInDrawer: true),
              ),
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              if (isWide) _buildSidebar(),
      Expanded(
                      child: Column(
                        children: [
                          const HomePendingInvitesSection(),
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
                              reverse: false,
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
    if (!isWide) {
      return MobileHomeAppBar(
        onOpenMenu: _openDrawer,
        onSignOut: _confirmLogout,
      );
    }

    final compact = isCompactWidth(context);

    return AppBar(
      toolbarHeight: compact ? 56 : 90,
      automaticallyImplyLeading: false,
      leading: !isWide
          ? IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open menu',
              onPressed: _openDrawer,
              style: mobileIconButtonStyle(context),
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.church, size: compact ? 28 : 36),
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
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Log out',
          onPressed: _confirmLogout,
          style: mobileIconButtonStyle(context),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.church, size: kEmptyStateIconSize, color: AppColors.primaryMaroon),
          const SizedBox(height: 24),
          const Text('Peace be with you.', style: TextStyle(fontSize: 22)),
          const Text(
            'What is weighing on your heart today?',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _focusChatInput,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Tap to ask a question'),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(200, touchTargetMin(context)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
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
            else if (msg.isStaticPrompt)
              LinkedMarkdownBody(
                data: msg.text.trim(),
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontSize: isCompactWidth(context) ? 15 : 16,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                  strong: TextStyle(
                    fontSize: isCompactWidth(context) ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                    color: AppColors.primaryMaroon,
                  ),
                  blockSpacing: 14,
                ),
              )
            else
              LinkedMarkdownBody(data: msg.text),

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
          mobileLabeledAction(
            context: context,
            icon: Icons.expand_more,
            label: 'Delve',
            onPressed: () => _handleDelveDeeper(msg),
            foregroundColor: AppColors.primaryMaroon,
          ),
          mobileLabeledAction(
            context: context,
            icon: Icons.copy_outlined,
            label: 'Copy',
            onPressed: () => _copyToClipboard(msg.text),
          ),
          mobileLabeledAction(
            context: context,
            icon: Icons.volume_up_outlined,
            label: 'Listen',
            onPressed: () => _speak(msg.text),
          ),
          ShareButton(
            question: _getLatestUserQuestion(),
            response: msg.text,
            showLabel: true,
          ),
          mobileLabeledAction(
            context: context,
            icon: Icons.card_giftcard_outlined,
            label: 'Gifts',
            onPressed: () => _addToGiftsPlan(msg),
            foregroundColor: AppColors.primaryMaroon,
          ),
          mobileLabeledAction(
            context: context,
            icon: Icons.edit_note_outlined,
            label: 'Reflect',
            onPressed: () => _addToReflections(msg),
            foregroundColor: AppColors.primaryMaroon,
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
          onPressed: () => _handleDelveDeeper(msg),
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
        TextButton.icon(
          icon: const Icon(Icons.edit_note_outlined, size: 18),
          label: const Text('Add to My Reflections'),
          onPressed: () => _addToReflections(msg),
          style: maroon,
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    final horizontal = responsiveHorizontalPadding(context);
    final compact = isCompactWidth(context);

    return SafeArea(
      top: false,
      child: keyboardAwarePadding(
        context: context,
        child: Container(
          padding: horizontal.copyWith(top: 8, bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.parchment,
            border: Border(
              top: BorderSide(
                color: AppColors.primaryMaroon.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (compact)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: mobileLabeledAction(
                    context: context,
                    icon: _isListening ? Icons.mic_off : Icons.mic,
                    label: _isListening ? 'Stop' : 'Voice',
                    onPressed: _toggleListening,
                    foregroundColor: AppColors.primaryMaroon,
                  ),
                )
              else
                IconButton(
                  icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                  tooltip: _isListening ? 'Stop listening' : 'Voice input',
                  onPressed: _toggleListening,
                  style: mobileIconButtonStyle(context),
                ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _inputFocusNode,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  autocorrect: true,
                  enableSuggestions: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: isCompactWidth(context)
                        ? 'Your question…'
                        : 'Bring your question or struggle… we walk together',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (compact)
                FilledButton.icon(
                  onPressed: _isSending ? null : _handleSend,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 20),
                  label: const Text('Send'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryMaroon,
                    foregroundColor: Colors.white,
                    minimumSize: Size(88, touchTargetMin(context)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                )
              else
                Material(
                  color: AppColors.primaryMaroon,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _isSending ? null : _handleSend,
                    borderRadius: BorderRadius.circular(28),
                    child: SizedBox(
                      width: kSendButtonSize,
                      height: kSendButtonSize,
                      child: Center(
                        child: _isSending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                      ),
                    ),
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

class _WisdomReflectionDialog extends StatefulWidget {
  const _WisdomReflectionDialog({
    required this.question,
    required this.initialTitle,
    required this.onSave,
  });

  final String question;
  final String initialTitle;
  final Future<void> Function({String? title, required String body}) onSave;

  @override
  State<_WisdomReflectionDialog> createState() => _WisdomReflectionDialogState();
}

class _WisdomReflectionDialogState extends State<_WisdomReflectionDialog> {
  bool _busy = false;

  Future<void> _submit({String? title, required String body}) async {
    setState(() => _busy = true);
    try {
      await widget.onSave(title: title, body: body);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to My Reflections')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAuthDialog(
      title: const Text('Add to My Reflections'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Private to you — only your words are saved.',
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Your question',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.question,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
            ReflectionComposer(
              showTitle: true,
              initialTitle: widget.initialTitle,
              submitLabel: 'Save reflection',
              busy: _busy,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
      actions: AuthDialogActions(actions: const []),
    );
  }
}

class _AddGiftsPlanDialog extends StatefulWidget {
  const _AddGiftsPlanDialog({
    required this.actions,
    required this.existingGifts,
    required this.giftService,
  });

  final List<Map<String, String>> actions;
  final List<GiftActivity> existingGifts;
  final GiftService giftService;

  @override
  State<_AddGiftsPlanDialog> createState() => _AddGiftsPlanDialogState();
}

class _AddGiftsPlanDialogState extends State<_AddGiftsPlanDialog> {
  late final List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.actions.map((action) {
      return !_isDuplicate(action);
    }).toList();
  }

  bool _isDuplicate(Map<String, String> action) {
    final candidate = GiftActivity(
      id: '',
      title: action['title'] ?? '',
      description: action['description'] ?? '',
      frequency: action['frequency'] ?? 'Daily',
      hasReminder: true,
      userId: '',
      createdAt: DateTime.now(),
    );
    return widget.giftService.findDuplicate(candidate, widget.existingGifts) != null;
  }

  int get _selectedCount => _selected.where((s) => s).length;

  void _toggleAll(bool value) {
    setState(() {
      for (var i = 0; i < widget.actions.length; i++) {
        if (!_isDuplicate(widget.actions[i])) {
          _selected[i] = value;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectableCount =
        widget.actions.where((a) => !_isDuplicate(a)).length;

    return ResponsiveAuthDialog(
      title: const Text('Add to My Gifts Plan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.actions.length > 1 && selectableCount > 1)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  final allSelected = _selectedCount == selectableCount;
                  _toggleAll(!allSelected);
                },
                child: Text(
                  _selectedCount == selectableCount
                      ? 'Deselect all'
                      : 'Select all',
                ),
              ),
            ),
          for (var i = 0; i < widget.actions.length; i++)
            _buildActionRow(i),
        ],
      ),
      actions: AuthDialogActions(
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _selectedCount == 0
                ? null
                : () {
                    final chosen = <Map<String, String>>[];
                    for (var i = 0; i < widget.actions.length; i++) {
                      if (_selected[i]) chosen.add(widget.actions[i]);
                    }
                    Navigator.pop(context, chosen);
                  },
            child: Text(
              _selectedCount <= 1
                  ? 'Add to Plan'
                  : 'Add $_selectedCount to Plan',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(int index) {
    final action = widget.actions[index];
    final duplicate = _isDuplicate(action);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: duplicate ? false : _selected[index],
        onChanged: duplicate
            ? null
            : (value) {
                setState(() => _selected[index] = value ?? false);
              },
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        secondary: duplicate
            ? Chip(
                label: const Text('Already in plan'),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
                visualDensity: VisualDensity.compact,
              )
            : null,
        title: Text(
          action['title'] ?? 'Action',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${action['description'] ?? ''}\n${action['frequency'] ?? 'Daily'}',
        ),
      ),
    );
  }
}