/// Identifies where a private reflection thread originated.
class ReflectionSource {
  ReflectionSource._();

  static const manual = 'manual';
  static const wisdomSession = 'wisdom_session';
  static const giftActivity = 'gift_activity';
  static const sharedJourney = 'shared_journey';

  static String label(String? source) {
    switch (source) {
      case wisdomSession:
        return "Seeking God's Wisdom";
      case giftActivity:
        return 'Sharing My Gifts';
      case sharedJourney:
        return 'Walk Together';
      default:
        return 'Private reflection';
    }
  }

  static bool hasNavigableSource(String? source) {
    return source == wisdomSession ||
        source == giftActivity ||
        source == sharedJourney;
  }
}
