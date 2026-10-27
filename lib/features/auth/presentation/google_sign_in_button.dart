import 'package:flutter/material.dart';
import 'package:haqly_mobile/core/l10n/generated/app_localizations.dart';

/// Reusable Google authentication button adhering to docs/DESIGN.md and docs/RULES.md.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final text = label ?? l10n?.continueWithGoogle ?? 'Continue with Google';

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.g_mobiledata_rounded,
                  size: 26,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
    );
  }
}
