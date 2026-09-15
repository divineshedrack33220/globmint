import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/models/beneficiary.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/create_account_page.dart';
import '../../features/auth/presentation/pages/verification_page.dart';
import '../../features/auth/presentation/pages/create_pin_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/savings/presentation/pages/savings_page.dart';
import '../../features/savings/presentation/pages/add_money_page.dart';
import '../../features/savings/presentation/pages/conversion_page.dart';
import '../../features/savings/presentation/pages/savings_details_page.dart';
import '../../features/savings/presentation/pages/withdraw_page.dart';
import '../../features/savings/presentation/pages/withdrawal_review_page.dart';
import '../../features/savings/presentation/pages/vault_recovery_page.dart';
import '../../features/pay/presentation/pages/pay_page.dart';
import '../../features/pay/presentation/pages/bank_transfer_page.dart';
import '../../features/pay/presentation/pages/send_to_beneficiary_page.dart';
import '../../features/pay/presentation/pages/transfer_review_page.dart';
import '../../features/pay/presentation/pages/transfer_result_page.dart';
import '../../features/activity/presentation/pages/activity_page.dart';
import '../../features/activity/presentation/pages/transaction_details_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/personal_info_page.dart';
import '../../features/profile/presentation/pages/bank_accounts_page.dart';
import '../../features/profile/presentation/pages/beneficiaries_page.dart';
import '../../features/profile/presentation/pages/beneficiary_details_page.dart';
import '../../features/profile/presentation/pages/security_center_page.dart';
import '../../features/profile/presentation/pages/devices_page.dart';
import '../../features/profile/presentation/pages/security_activity_page.dart';
import '../../features/profile/presentation/pages/change_pin_page.dart';
import '../../features/profile/presentation/pages/change_password_page.dart';
import '../../features/legal/data/legal_documents.dart';
import '../../features/legal/presentation/pages/legal_document_page.dart';
import '../../features/legal/presentation/pages/faq_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import 'providers.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Routes that require a validated session. The app-lock gate covers them
/// visually, but on the web the browser tab can restore a guarded URL on
/// reload — without a redirect the guarded page would mount *underneath* the
/// lock overlay and fire unauthenticated requests (a spurious 401) while the
/// stored session is being validated. This redirect refuses to mount them
/// until the session is confirmed, matching what the README has always
/// documented as "go_router redirects unauthenticated visits".
const Set<String> _protectedRoots = {
  '/home',
  '/savings',
  '/pay',
  '/activity',
  '/profile',
};

bool _isProtectedRoute(String path) => _protectedRoots.any(
      (root) => path == root || path.startsWith('$root/'),
    );

/// Pure redirect decision for the app lock. Kept as a standalone function so
/// the whole matrix can be unit tested without booting a real app/router.
///
///   - A route needing a fresh login ([AppLockState.needsLogin]) or the user
///     being unauthenticated in this run → `/login`.
///   - The session not yet validated / app still locked (`starting`/`locked`)
///     → `/welcome` (never `/login`, which would flash for a session that
///     merely awaits biometric confirmation).
///   - Everything else (unlocked with a live session) → null (allowed).
String? appLockRedirect({
  required AppLockState lock,
  required bool isAuthenticated,
  required String path,
}) {
  if (!_isProtectedRoute(path)) return null;
  if (lock.needsLogin) return '/login';
  if (lock.status != AppLockStatus.unlocked) return '/welcome';
  if (!isAuthenticated) return '/login';
  return null;
}

/// Builds a page with custom transitions based on route type
Page<dynamic> _buildPageWithTransition(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  bool isAuthRoute = false,
  bool isModal = false,
  bool isFullScreenDialog = false,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (isAuthRoute) {
        return FadeTransition(opacity: animation, child: child);
      }
      if (isModal || isFullScreenDialog) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        );
      }
      // Standard page push - slide from right + fade
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.15, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/welcome',
  redirect: (context, state) {
    // The navigator context always sits beneath the app-wide ProviderScope,
    // so we can reach the providers the lock gate is driven by. Keeping the
    // decision itself pure (see [appLockRedirect]) keeps this testable.
    final container = ProviderScope.containerOf(context, listen: false);
    return appLockRedirect(
      lock: container.read(appLockProvider),
      isAuthenticated: container.read(authServiceProvider).isAuthenticated,
      path: state.matchedLocation,
    );
  },
  routes: [
    GoRoute(
      path: '/welcome',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const WelcomePage(), isAuthRoute: true),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) {
        final extra = state.extra is Map ? (state.extra as Map) : null;
        return _buildPageWithTransition(
          context,
          state,
          LoginPage(initialEmail: extra?['email'] as String?),
          isAuthRoute: true,
        );
      },
    ),
    GoRoute(
      path: '/forgot-password',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const ForgotPasswordPage(), isAuthRoute: true),
    ),
    GoRoute(
      path: '/create-account',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const CreateAccountPage(), isAuthRoute: true),
    ),
    GoRoute(
      path: '/verify',
      pageBuilder: (context, state) {
        final extra = state.extra is Map ? (state.extra as Map) : const <String, dynamic>{};
        return _buildPageWithTransition(
          context,
          state,
          VerificationPage(
            email: extra['email'] as String?,
            // When registration already sent a code, carry the cooldown
            // deadline so the page never double-sends on open.
            initialResendAfterMs: extra['resend_after'] as int?,
          ),
          isAuthRoute: true,
        );
      },
    ),
    GoRoute(
      path: '/create-pin',
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const CreatePinPage(), isAuthRoute: true),
    ),
    // Savings flow
    GoRoute(
      path: '/savings/add-money',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const AddMoneyPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/savings/convert',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const ConversionPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/savings/details',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(context, state, const SavingsDetailsPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/savings/withdraw',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final extra = (state.extra as Map?) ?? const {};
        return _buildPageWithTransition(
          context,
          state,
          WithdrawPage(initialAddress: extra['address'] as String?),
          isFullScreenDialog: true,
        );
      },
    ),
    GoRoute(
      path: '/savings/withdraw-review',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final extra = state.extra as Map? ?? {};
        return _buildPageWithTransition(
          context,
          state,
          WithdrawalReviewPage(
            amount: (extra['amount'] as num?)?.toDouble(),
            account: extra['account'] as dynamic,
            destination: extra['destination'] as String?,
            network: extra['network'] as String?,
          ),
          isFullScreenDialog: true,
        );
      },
    ),
    GoRoute(
      path: '/savings/recovery',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const VaultRecoveryPage(), isFullScreenDialog: true),
    ),
    // Pay flow
    GoRoute(
      path: '/pay/bank-transfer',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const BankTransferPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/pay/send-beneficiary',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final extra = (state.extra as Map?) ?? const {};
        return _buildPageWithTransition(
          context,
          state,
          SendToBeneficiaryPage(beneficiary: extra['beneficiary'] as dynamic),
          isFullScreenDialog: true,
        );
      },
    ),
    GoRoute(
      path: '/pay/review',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final extra = state.extra as Map? ?? {};
        return _buildPageWithTransition(
          context,
          state,
          TransferReviewPage(
            amount: (extra['amount'] as num?)?.toDouble(),
            accountName: extra['accountName'] as String?,
            accountNumber: extra['accountNumber'] as String?,
            bankName: extra['bankName'] as String?,
            note: extra['note'] as String?,
          ),
          isFullScreenDialog: true,
        );
      },
    ),
    GoRoute(
      path: '/pay/result',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final extra = state.extra as Map? ?? {};
        return _buildPageWithTransition(
          context,
          state,
          TransferResultPage(
            amount: (extra['amount'] as num?)?.toDouble(),
            accountName: extra['accountName'] as String?,
          ),
          isFullScreenDialog: true,
        );
      },
    ),
    // Activity flow
    GoRoute(
      path: '/activity/:id',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context,
        state,
        TransactionDetailsPage(transactionId: state.pathParameters['id']),
        isFullScreenDialog: true,
      ),
    ),
    // Profile flow
    GoRoute(
      path: '/profile/security-center',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const SecurityCenterPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/profile/devices',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const DevicesPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/profile/security-activity',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const SecurityActivityPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/profile/change-pin',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const ChangePinPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/profile/change-password',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const ChangePasswordPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/profile/personal-info',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const PersonalInfoPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/profile/bank-accounts',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const BankAccountsPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/profile/beneficiaries',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const BeneficiariesPage(), isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/profile/beneficiaries/:id',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final extra = state.extra as Beneficiary?;
        return _buildPageWithTransition(
          context,
          state,
          BeneficiaryDetailsPage(beneficiary: extra),
          isFullScreenDialog: true,
        );
      },
    ),
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const NotificationsPage(), isFullScreenDialog: true),
    ),
    // Legal documents (public: readable before and without an account)
    GoRoute(
      path: '/legal/privacy',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context,
        state,
        const LegalDocumentPage(
          title: 'Privacy Policy',
          sections: LegalDocuments.privacyPolicy,
        ),
        isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/legal/terms',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context,
        state,
        const LegalDocumentPage(
          title: 'Terms of Service',
          sections: LegalDocuments.termsOfService,
        ),
        isFullScreenDialog: true),
    ),
    GoRoute(
      path: '/legal/faq',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _buildPageWithTransition(
        context, state, const FaqPage(), isFullScreenDialog: true),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/savings',
              builder: (context, state) => const SavingsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/pay',
              builder: (context, state) => const PayPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/activity',
              builder: (context, state) => const ActivityPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
