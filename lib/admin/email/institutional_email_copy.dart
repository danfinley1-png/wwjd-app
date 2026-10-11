import '../models/admin_role.dart';

/// Default transactional copy for admin preview. Keep in sync with
/// `functions/email_templates.js`.
class InstitutionalEmailCopy {
  InstitutionalEmailCopy._();

  static const String fromAddress = 'WWJD-DI <noreply@contact.wwjddi.com>';
  static const String appPublicUrl = 'https://wwjd-di-e36ce.web.app';
  static const String logoUrl =
      'https://wwjd-di-e36ce.web.app/icons/Icon-192.png';
  static const String tempPasswordPlaceholder =
      '[temporary password — assigned when Send is tapped]';

  static String openAppInstructionsText() {
    return [
      'Open WWJD-DI',
      '1. Tap this link: $appPublicUrl',
      '2. Sign in with the email this message was sent to (set your password on first login if prompted).',
      '3. Add to your phone Home Screen:',
      '   iPhone: Safari → Share → Add to Home Screen. Use the WWJD-DI icon.',
      '   Android: Chrome → menu → Add to Home screen / Install app.',
    ].join('\n');
  }

  static String _rolePhrase(AdminRole role) {
    switch (role) {
      case AdminRole.orgAdmin:
        return 'organization administrator';
      case AdminRole.groupLeader:
        return 'group leader';
      case AdminRole.member:
        return 'member';
    }
  }

  static String _firstName(String? displayName, String email) {
    final fromName = displayName?.trim() ?? '';
    if (fromName.isNotEmpty) return fromName.split(RegExp(r'\s+')).first;
    final local = email.split('@').first;
    if (local.isEmpty) return 'friend';
    return '${local[0].toUpperCase()}${local.substring(1)}';
  }

  static ({String subject, String text}) organizationInvite({
    required String inviteeEmail,
    required String organizationName,
    required AdminRole role,
    List<String> groupNames = const [],
  }) {
    final orgLabel =
        organizationName.trim().isEmpty ? 'your organization' : organizationName.trim();
    final roleText = _rolePhrase(role);
    final groups = groupNames.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
    final groupsText = groups.isEmpty
        ? ''
        : ' Assigned groups after you accept: ${groups.join(', ')}.';

    return (
      subject: "You're invited to join $orgLabel on WWJD-DI",
      text: [
        'Hello,',
        '',
        'You have been invited to join $orgLabel in WWJD-DI as a $roleText.$groupsText',
        '',
        'WWJD-DI is a Catholic discernment companion rooted in Scripture and Church teaching.',
        '',
        'You may Accept or Decline this invitation in the app — membership is never added without your consent.',
        '',
        openAppInstructionsText(),
        '',
        'This message contains no private spiritual content.',
        '',
        'Peace in Christ,',
        'The WWJD-DI Team',
      ].join('\n'),
    );
  }

  static ({String subject, String text}) groupInvite({
    required String groupName,
    String? organizationName,
  }) {
    final groupLabel =
        groupName.trim().isEmpty ? 'your ministry group' : groupName.trim();
    final orgLabel = organizationName?.trim() ?? '';
    final orgSentence = orgLabel.isEmpty ? '' : ' at $orgLabel';
    final subject = orgLabel.isEmpty
        ? "You're invited to join $groupLabel on WWJD-DI"
        : "You're invited to join $groupLabel on WWJD-DI — $orgLabel";

    return (
      subject: subject,
      text: [
        'Hello,',
        '',
        'You have been invited to join the group "$groupLabel"$orgSentence in WWJD-DI.',
        '',
        'WWJD-DI is a Catholic discernment companion rooted in Scripture and Church teaching.',
        '',
        'You may Accept or Decline this invitation in the app — membership is never added without your consent.',
        '',
        'View invitations: $appPublicUrl/group-invites',
        '',
        openAppInstructionsText(),
        '',
        'This message contains no private spiritual content.',
        '',
        'Peace in Christ,',
        'The WWJD-DI Team',
      ].join('\n'),
    );
  }

  static ({String subject, String text}) platformInvite({
    required String inviteeEmail,
  }) {
    return (
      subject: "You're invited to WWJD-DI",
      text: [
        'Hello,',
        '',
        'You have been invited to use WWJD-DI, a Catholic discernment companion rooted in Scripture and Church teaching.',
        '',
        'Register or sign in with the email this message was sent to. Personal features such as Seeking God\'s Wisdom are available after you create your account.',
        '',
        'A school, parish, or ministry is added only if you later accept a separate invitation. Nothing is assigned automatically.',
        '',
        openAppInstructionsText(),
        '',
        'This message contains no private spiritual content.',
        '',
        'Peace in Christ,',
        'The WWJD-DI Team',
      ].join('\n'),
    );
  }

  static ({String subject, String text}) welcome({
    required String email,
    String? displayName,
    String? organizationName,
    String temporaryPassword = tempPasswordPlaceholder,
  }) {
    final greeting = _firstName(displayName, email);
    final orgLine = (organizationName ?? '').trim().isNotEmpty
        ? 'Your account was set up for ministry use with ${organizationName!.trim()}.'
        : 'Your WWJD-DI account is ready. Personal discernment features are available after you sign in.';

    return (
      subject: 'Welcome to WWJD-DI — your account is ready',
      text: [
        'Dear $greeting,',
        '',
        'Welcome to WWJD-DI — a Catholic discernment companion rooted in Scripture and Church teaching.',
        '',
        orgLine,
        '',
        'Your next steps:',
        '1. Open WWJD-DI: $appPublicUrl',
        '2. Sign in with this email address: $email',
        '3. Use this temporary password: $temporaryPassword',
        '4. You will be asked to choose a new password on first sign-in.',
        '',
        openAppInstructionsText(),
        '',
        "Privacy: Your personal conversations in Seeking God's Wisdom, reflections, and gifts are private. Organization leaders cannot read them.",
        '',
        'Peace in Christ,',
        'The WWJD-DI Team',
      ].join('\n'),
    );
  }
}

class EmailSendDraft {
  const EmailSendDraft({
    required this.subject,
    required this.text,
    required this.edited,
  });

  final String subject;
  final String text;
  final bool edited;

  /// Custom fields for Firestore / provision API when the admin edited copy.
  Map<String, String> get overrideFields {
    if (!edited) return const {};
    return {
      'emailSubject': subject.trim(),
      'emailText': text.trim(),
    };
  }
}
