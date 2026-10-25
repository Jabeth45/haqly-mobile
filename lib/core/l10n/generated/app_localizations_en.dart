// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Haqly';

  @override
  String get appTagline => 'Not just what did you spend, but was it worth it.';

  @override
  String get tabHome => 'Home';

  @override
  String get tabAdd => 'Add';

  @override
  String get tabCheck => 'Check';

  @override
  String get tabLedger => 'Ledger';

  @override
  String get tabHistory => 'History';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get edit => 'Edit';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get welcomeTitle => 'Haqly';

  @override
  String get welcomeSubtitle => 'Smart personal finance for Ethiopia';

  @override
  String get welcomeTagline =>
      'Track expenses, check value, and manage debt offline.';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get verifyEmail => 'Verify Email';

  @override
  String get otpCode => 'Verification Code';

  @override
  String get enterOtpPrompt =>
      'Enter the 6-digit verification code sent to your email.';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Sign Up';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign In';

  @override
  String get resendCode => 'Resend Code';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get sendResetCode => 'Send Reset Code';

  @override
  String get newPassword => 'New Password';

  @override
  String get passwordResetSuccess =>
      'Password reset successfully. You can now sign in.';
}
