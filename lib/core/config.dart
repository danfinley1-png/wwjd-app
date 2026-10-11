/// Application configuration. Secrets are loaded from the environment — never hardcoded.
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

class AppConfig {
  static const String _xaiApiKeyEnv = 'XAI_API_KEY';

  /// Optional xAI key — **debug localhost web only** (never release / store builds).
  static String get xaiApiKey =>
      const String.fromEnvironment(_xaiApiKeyEnv, defaultValue: '');

  static bool get hasXaiApiKey => xaiApiKey.isNotEmpty;

  static bool get _isLocalhostWeb {
    if (!kIsWeb) return false;
    final host = Uri.base.host;
    return host == 'localhost' || host == '127.0.0.1';
  }

  /// Direct xAI from the browser — debug localhost **with** `--dart-define-from-file=.env` only.
  static bool get useClientSideXaiKey =>
      kDebugMode && _isLocalhostWeb && hasXaiApiKey;

  static const String chatCompletionsFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/chatCompletions';

  /// Authenticated proxy (`/api/chat` or Cloud Function URL). Never ships xAI key.
  static String get chatCompletionsUrl {
    if (useClientSideXaiKey) {
      return 'https://api.x.ai/v1/chat/completions';
    }
    // `flutter run` on localhost has no Hosting `/api/chat` rewrite — call the function URL.
    if (kIsWeb && !(kDebugMode && _isLocalhostWeb)) {
      return '${Uri.base.origin}/api/chat';
    }
    return chatCompletionsFunctionUrl;
  }

  static const String appName = 'WWJD - DI';
  /// Full product name shown in the mobile header (no spaces around hyphen).
  static const String mobileDisplayName = 'WWJD-DI';

  /// Bump when Saints routing/posters/player change — visible under Saints app bar.
  static const String saintsUiBuildId = 'saints-2026-03-29-v8';

  /// Legacy export copy (calendar ICS). Not shown in the app header.
  static const String tagline =
      'Sharing the Divine Intelligence of Scripture and the Revelation of the Catholic Church';

  static const String purposeLineOne = 'A Catholic Divine Intelligence guide.';
  static const String purposeLineTwo = 'Ask WWJD.';

  static const List<String> homeDecisionChips = [
    'I have a hard conversation this week.',
    "I'm anxious and don't know what to pray.",
    'How do I treat someone I resent?',
    'Why is it important to go to Mass?',
  ];

  static const String chatInputPlaceholder =
      "What's on your heart?";

  /// Ask WWJD limits — enforced server-side in `chatCompletions` (keep in sync with functions/chat_quota.js).
  static const int guestQuestionLimit = 3;
  static const int registeredDailyQuestionLimit = 25;

  /// Home empty state (above decision chips) — not injected into chat history.
  static const String homeWelcomeMarkdown = '''
**Welcome to WWJD-DI**

Seeking God's Wisdom through the guidance of Divine Intelligence — Scripture and the living revelation of the Catholic Church.

Bring any questions, concerns or decisions. We walk together.''';

  /// Legacy alias for tests or static prompts.
  static const String seekingGodsWisdomWelcome = homeWelcomeMarkdown;

  /// First-open dialog for new / guest users (Sign Up or Continue as Guest).
  static const String guestWelcomeTitle = 'Welcome to WWJD-DI';
  static const String guestWelcomeInvite =
      'Bring your questions, struggles, and decisions.';
  static const String guestWelcomeBody =
      'Receive warm, faithful Catholic guidance rooted in Scripture and Church teaching.';
  static const String guestWelcomeClosing = 'Your journey, guided by faith.';

  /// Production web origin for share links (e.g. https://app.example.com).
  /// When null, web uses [Uri.base.origin] at runtime.
  static const String? webBaseUrl = null;

  static const String firebaseProjectId = 'wwjd-di-e36ce';
  static const String firebaseFunctionsRegion = 'us-central1';
  static const String firebaseStorageBucket = 'wwjd-di-e36ce.firebasestorage.app';

  /// Profile photo API — same Cloud Function handles GET (fetch) and POST (upload).
  /// Production web uses same-origin `/api/profile-photo` when hosting rewrites are deployed.
  static String get profilePhotoApiUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/api/profile-photo';
    }
    return profilePhotoUploadUrl;
  }

  /// Super Admin usage report API (hosting rewrite → getUsageReport function).
  static String get usageReportApiUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/api/getUsageReport';
    }
    return usageReportFunctionUrl;
  }

  /// Direct HTTPS endpoint (Gen2 / Cloud Functions URL).
  static const String usageReportFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/getUsageReport';

  /// Bulk institutional user provisioning (hosting rewrite → provisionInstitutionalUsers).
  static String get provisionInstitutionalUsersApiUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/provisionInstitutionalUsers';
    }
    return provisionInstitutionalUsersFunctionUrl;
  }

  /// Direct HTTPS endpoint for provisionInstitutionalUsers (localhost web + native).
  static const String provisionInstitutionalUsersFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/provisionInstitutionalUsers';

  /// Overall Admin user directory (hosting rewrite → getUserDirectory).
  static String get userDirectoryApiUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/api/getUserDirectory';
    }
    return userDirectoryFunctionUrl;
  }

  static const String userDirectoryFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/getUserDirectory';

  static String get resendDirectoryInviteApiUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/api/resendDirectoryInvite';
    }
    return resendDirectoryInviteFunctionUrl;
  }

  static const String resendDirectoryInviteFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/resendDirectoryInvite';

  static String get recordQuestionThemeApiUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/api/recordQuestionTheme';
    }
    return recordQuestionThemeFunctionUrl;
  }

  static const String recordQuestionThemeFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/recordQuestionTheme';

  static String get questionThemeReportApiUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/api/getQuestionThemeReport';
    }
    return questionThemeReportFunctionUrl;
  }

  static const String questionThemeReportFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/getQuestionThemeReport';

  /// Foundation admin self-registration (hosting rewrite → ensurePlatformAdmin).
  static String get ensurePlatformAdminApiUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/ensurePlatformAdmin';
    }
    return ensurePlatformAdminFunctionUrl;
  }

  static const String ensurePlatformAdminFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/ensurePlatformAdmin';

  static const String productionWebOrigin = 'https://wwjd-di-e36ce.web.app';

  /// Nearby parish lookup (hosting rewrite → nearbyParishes function).
  static String get nearbyParishesApiUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/api/nearby-parishes';
    }
    return nearbyParishesFunctionUrl;
  }

  static const String nearbyParishesFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/nearbyParishes';

  /// Organization logo upload. Uses the Cloud Functions URL so production web
  /// does not depend on the Hosting `/api/org-logo` rewrite (Hosting deploy is
  /// currently blocked until [nearbyParishes] exists in us-central1).
  static String get orgLogoApiUrl => orgLogoFunctionUrl;

  static const String orgLogoFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/uploadOrgLogo';

  /// Saint clip upload (web/desktop proxy). Hosting rewrite → uploadSaintVideo.
  static String get saintVideoApiUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/api/saint-video';
    }
    return saintVideoFunctionUrl;
  }

  static const String saintVideoFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/uploadSaintVideo';

  /// GET stream for saint feast / legacy clips (web playback; Range requests).
  static String get streamSaintVideoApiUrl {
    // Localhost dev server has no `/api/*` rewrites — use the function URL (see [chatCompletionsUrl]).
    if (kIsWeb && !(kDebugMode && _isLocalhostWeb)) {
      return '${Uri.base.origin}/api/stream-saint-video';
    }
    return streamSaintVideoFunctionUrl;
  }

  static const String streamSaintVideoFunctionUrl =
      'https://us-central1-wwjd-di-e36ce.cloudfunctions.net/streamSaintVideo';

  /// @deprecated Use [profilePhotoApiUrl] for uploads and fetches.
  static const String profilePhotoUploadUrl =
      'https://uploadprofilephoto-brqkx7qhla-uc.a.run.app';
}
