/// Application configuration. Secrets are loaded from the environment — never hardcoded.
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  static const String _xaiApiKeyEnv = 'XAI_API_KEY';

  /// xAI API key from `--dart-define=XAI_API_KEY=...` or `--dart-define-from-file=.env`.
  /// Used for local/dev native builds only — production web uses the `/api/chat` proxy.
  static String get xaiApiKey =>
      const String.fromEnvironment(_xaiApiKeyEnv, defaultValue: '');

  static bool get hasXaiApiKey => xaiApiKey.isNotEmpty;

  /// True when the client may attach the xAI bearer token (local web dev / native).
  static bool get useClientSideXaiKey {
    if (!kIsWeb) return true;
    final host = Uri.base.host;
    return host == 'localhost' || host == '127.0.0.1';
  }

  /// Chat completions endpoint. Web production uses same-origin proxy (no CORS).
  static String get chatCompletionsUrl {
    if (kIsWeb && !useClientSideXaiKey) {
      return '${Uri.base.origin}/api/chat';
    }
    return 'https://api.x.ai/v1/chat/completions';
  }

  static const String appName = 'WWJD - DI';
  /// Full product name shown in the mobile header (no spaces around hyphen).
  static const String mobileDisplayName = 'WWJD-DI';
  static const String tagline =
      'Sharing the Divine Intelligence of Scripture and the Revelation of the Catholic Church';

  /// Shown in the chat when Seeking God's Wisdom opens with no prior conversation.
  static const String seekingGodsWisdomWelcome = '''
**Welcome to WWJD-DI**

Seeking God's Wisdom through the guidance of Divine Intelligence — Scripture and the living revelation of the Catholic Church.

Bring any question, concern, or decision. We walk together.''';

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

  /// @deprecated Use [profilePhotoApiUrl] for uploads and fetches.
  static const String profilePhotoUploadUrl =
      'https://uploadprofilephoto-brqkx7qhla-uc.a.run.app';
}
