/// Basic password strength rules for institutional account setup.
class PasswordStrength {
  PasswordStrength._();

  static const int minLength = 8;

  static String? validate(String password) {
    final value = password.trim();
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return 'Password must include at least one letter.';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Password must include at least one number.';
    }
    return null;
  }
}
