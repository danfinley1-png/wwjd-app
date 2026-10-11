/// Debug helpers for Firestore Storage download URLs (never truncate to "..." in UI).
class SaintUrlDebug {
  SaintUrlDebug._();

  static bool isUsableUrl(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) return false;
    if (s == '...' || s == '…') return false;
    return s.startsWith('http://') || s.startsWith('https://');
  }

  static String describe(String label, String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) {
      return '$label: (empty, len=0)';
    }
    if (s == '...' || s == '…') {
      return '$label: LITERAL_PLACEHOLDER "$s" — re-seed Firestore URLs';
    }
    if (!s.startsWith('http')) {
      return '$label: invalid scheme, len=${s.length} start=${_head(s, 80)}';
    }
    return '$label: len=${s.length} start=${_head(s, 80)}';
  }

  static String _head(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }
}
