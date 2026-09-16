import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/core/theme/app_colors.dart';
import 'package:globe_mint/core/theme/theme_extensions.dart';
import 'package:globe_mint/core/widgets/app_button.dart';
import 'package:globe_mint/core/widgets/pin_input.dart';

/// Full-screen lock overlay shown while the gate is covering the app.
///
/// Unlock affordances, in order of preference:
///  1. biometrics, when the device has them (with a "Use PIN" fallback),
///  2. the 6-digit transaction PIN — verified server-side against the
///     still-valid session, so no re-login is required,
///  3. the password → `/login` escape (also the only option after 3 wrong
///     PINs, mirroring the 3-failure biometric lockout).
///
/// Accessible labels are on every interactive control. The token itself is
/// never displayed or logged.
class UnlockScreen extends ConsumerWidget {
  const UnlockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appLockProvider);
    final notifier = ref.read(appLockProvider.notifier);

    final bool busy =
        state.status == AppLockStatus.starting ||
        state.status == AppLockStatus.unlocking;
    final bool showBiometrics =
        state.biometricsAvailable &&
        !state.passwordFallbackRequired &&
        !state.pinMode;
    final bool showPinPad = !showBiometrics && !state.pinFallbackRequired;
    // "Use Face ID/fingerprint" to go back from the pad, only when the user
    // opened it explicitly and biometrics are still allowed.
    final bool biometricsWhileOnPin =
        state.pinMode && !state.passwordFallbackRequired;

    final subtitle = switch (state.status) {
      AppLockStatus.starting => 'Checking session…',
      AppLockStatus.unlocking => 'Confirming…',
      _ => 'Enter your credentials to unlock',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'GlobMint logo',
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    'GlobMint',
                    style: context.typography.display,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: context.typography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (busy) ...[
                  Semantics(
                    label: 'Loading',
                    child: const CircularProgressIndicator(),
                  ),
                ] else if (showBiometrics) ...[
                  Semantics(
                    label: 'Unlock with biometrics',
                    button: true,
                    child: AppButton(
                      text: 'Unlock with biometrics',
                      icon: Icons.fingerprint,
                      isLoading: state.status == AppLockStatus.unlocking,
                      onPressed: () => notifier.unlockWithBiometric(),
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Use PIN',
                    button: true,
                    child: AppButton(
                      text: 'Use PIN',
                      variant: AppButtonVariant.text,
                      onPressed: () => notifier.signalPinFallback(),
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    label: 'Use password instead',
                    button: true,
                    child: AppButton(
                      text: 'Use password instead',
                      variant: AppButtonVariant.text,
                      onPressed: () => notifier.signalPasswordFallback(),
                      isExpanded: true,
                    ),
                  ),
                ] else if (showPinPad) ...[
                  Semantics(
                    label: 'Enter your 6-digit PIN',
                    child: PinInput(
                      key: ValueKey('unlock-pin-${state.pinFailures}'),
                      length: 6,
                      autofocus: false,
                      errorText: state.pinError,
                      onCompleted: notifier.unlockWithPin,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (biometricsWhileOnPin)
                    Semantics(
                      label: 'Use Face ID or fingerprint',
                      button: true,
                      child: AppButton(
                        text: 'Use Face ID or fingerprint',
                        variant: AppButtonVariant.text,
                        onPressed: () => notifier.cancelPinFallback(),
                        isExpanded: true,
                      ),
                    ),
                  Semantics(
                    label: 'Use password instead',
                    button: true,
                    child: AppButton(
                      text: 'Use password instead',
                      variant: AppButtonVariant.text,
                      onPressed: () => notifier.signalPasswordFallback(),
                      isExpanded: true,
                    ),
                  ),
                ] else ...[
                  Semantics(
                    label: 'Use password',
                    button: true,
                    child: AppButton(
                      text: 'Use password',
                      icon: Icons.lock_outline,
                      onPressed: () => notifier.signalPasswordFallback(),
                      isExpanded: true,
                    ),
                  ),
                ],
                if (state.passwordFallbackRequired &&
                    state.failedAttempts > 0 &&
                    !state.pinFallbackRequired) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Too many failed attempts — use your PIN instead.',
                    style: context.typography.labelMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (state.pinFallbackRequired && state.pinFailures > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Too many failed attempts — use your password instead.',
                    style: context.typography.labelMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}