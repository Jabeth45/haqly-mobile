import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haqly_mobile/core/l10n/generated/app_localizations.dart';
import 'package:haqly_mobile/core/theme/tokens.dart';
import 'package:haqly_mobile/domain/models/account_choice.dart';
import 'package:haqly_mobile/features/auth/presentation/google_sign_in_button.dart';
import 'package:haqly_mobile/features/auth/providers/auth_providers.dart';

/// Screen allowing guest users to upgrade to a cloud-synced account.
/// Implements PRD FR-A4, M3 (preserving guest history), and M4 (resolving existing account conflicts).
class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpgrade() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = await ref
        .read(authStateProvider.notifier)
        .upgradeWithEmail(email: email, password: password);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.emailAlreadyInUse) {
      // M4: Existing account detected; prompt user to choose keep cloud vs replace
      await _showExistingAccountChoiceDialog(email, password);
      return;
    }

    if (!result.isSuccess) {
      setState(() {
        _errorMessage = result.errorMessage;
      });
      return;
    }

    if (result.requiresVerification) {
      await context.push('/verify-otp', extra: email);
    } else {
      context.go('/home');
    }
  }

  Future<void> _handleGoogleUpgrade() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(authStateProvider.notifier)
        .upgradeWithGoogle();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.emailAlreadyInUse) {
      await _showExistingAccountChoiceDialog(
        result.email ?? 'google_user@haqly.app',
        '',
      );
      return;
    }

    if (!result.isSuccess) {
      setState(() {
        _errorMessage = result.errorMessage;
      });
      return;
    }

    context.go('/home');
  }

  Future<void> _showExistingAccountChoiceDialog(
    String email,
    String password,
  ) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final router = GoRouter.of(context);

    var selectedChoice = ExistingAccountChoice.keepCloud;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tokens.accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_sync_outlined,
                            color: tokens.accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            l10n?.accountConflictTitle ??
                                'Account Already Exists',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n?.accountConflictPrompt ?? 'An account with this email already exists. Choose how to handle your device data:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Option 1: Keep Cloud Data
                    InkWell(
                      key: const Key('keep_cloud_option'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setModalState(() {
                          selectedChoice = ExistingAccountChoice.keepCloud;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                selectedChoice ==
                                    ExistingAccountChoice.keepCloud
                                ? tokens.accent
                                : theme.colorScheme.outlineVariant,
                            width:
                                selectedChoice ==
                                    ExistingAccountChoice.keepCloud
                                ? 2
                                : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color:
                              selectedChoice == ExistingAccountChoice.keepCloud
                              ? tokens.accent.withValues(alpha: 0.06)
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              selectedChoice == ExistingAccountChoice.keepCloud
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color:
                                  selectedChoice ==
                                      ExistingAccountChoice.keepCloud
                                  ? tokens.accent
                                  : theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n?.keepCloudOption ?? 'Keep Cloud Data',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n?.keepCloudDescription ?? 'Discard device data and download your cloud records.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Option 2: Replace with Device Data
                    InkWell(
                      key: const Key('replace_device_option'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setModalState(() {
                          selectedChoice =
                              ExistingAccountChoice.replaceWithDevice;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                selectedChoice ==
                                    ExistingAccountChoice.replaceWithDevice
                                ? tokens.accent
                                : theme.colorScheme.outlineVariant,
                            width:
                                selectedChoice ==
                                    ExistingAccountChoice.replaceWithDevice
                                ? 2
                                : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color:
                              selectedChoice ==
                                  ExistingAccountChoice.replaceWithDevice
                              ? tokens.accent.withValues(alpha: 0.06)
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              selectedChoice ==
                                      ExistingAccountChoice.replaceWithDevice
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color:
                                  selectedChoice ==
                                      ExistingAccountChoice.replaceWithDevice
                                  ? tokens.accent
                                  : theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n?.replaceWithDeviceOption ??
                                        'Replace with Device Data',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n?.replaceWithDeviceDescription ?? 'Overwrite cloud data with records from this device.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('confirm_conflict_choice_button'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        setState(() => _isLoading = true);
                        final res = await ref
                            .read(authStateProvider.notifier)
                            .resolveExistingAccount(
                              email: email,
                              password: password,
                              choice: selectedChoice,
                            );
                        if (!mounted) return;
                        setState(() {
                          _isLoading = false;
                          if (!res.isSuccess) {
                            _errorMessage = res.errorMessage;
                          }
                        });
                        if (res.isSuccess) {
                          router.go('/home');
                        }
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(l10n?.confirm ?? 'Confirm'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('cancel_conflict_choice_button'),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(l10n?.cancel ?? 'Cancel'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.upgradeAccount ?? 'Upgrade Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      size: 32,
                      color: tokens.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n?.upgradeAccount ?? 'Upgrade Account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n?.upgradeSubtitle ??
                      'Back up your data and sync securely across devices.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                // Helper note that history is preserved
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: tokens.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: tokens.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n?.guestDataPreservedNote ?? 'Your existing expenses and history will be saved to your new account.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  key: const Key('upgrade_email_field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n?.email ?? 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('upgrade_password_field'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n?.password ?? 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('upgrade_submit_button'),
                  onPressed: _isLoading ? null : _handleUpgrade,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n?.upgradeAction ?? 'Upgrade'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: theme.colorScheme.outlineVariant),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l10n?.orDivider ?? 'OR',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: theme.colorScheme.outlineVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GoogleSignInButton(
                  key: const Key('google_upgrade_button'),
                  isLoading: _isLoading,
                  onPressed: _handleGoogleUpgrade,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    key: const Key('upgrade_to_login_button'),
                    onPressed: () => context.push('/login'),
                    child: Text(
                      l10n?.alreadyHaveAccount ??
                          'Already have an account? Sign In',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
