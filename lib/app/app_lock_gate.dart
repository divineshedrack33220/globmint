import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../features/auth/presentation/widgets/unlock_screen.dart';
import 'providers.dart';
import 'router.dart';

/// Wraps the whole app on top of the [MaterialApp.router] navigator.
///
/// Two jobs:
///
///  1. View gate — while [AppLockStatus] isn't `unlocked` it stacks the
///     [UnlockScreen] over the navigator, so the underlying pages stay
///     mounted (no state loss) but are invisible and untouchable.
///  2. Router — cold-start with a valid session lands on `/home` after a
///     successful unlock; a missing/expired session or a "use password
///     instead" choice routes to `/login` (pre-filled with the remembered
///     email). Mid-session 401s are received via [UnauthorizedHandler].
///
/// Re-locks when the app has been backgrounded longer than
/// [backgroundThreshold]; [backgroundThreshold] is injectable so widget
/// tests can force a re-lock without waiting real time.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
    this.router,
    this.backgroundThreshold = AppConstants.appLockBackgroundThreshold,
  });

  final Widget child;

  /// Router used for the gate's navigation decisions and redirects. Defaults
  /// to the app-wide [appRouter]; injectable so widget tests can use a tiny
  /// test router without booting the whole app shell.
  final GoRouter? router;

  final Duration backgroundThreshold;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late final ProviderSubscription<AppLockState> _lockSubscription;
  UnauthorizedHandler? _unauthorizedHandler;

  /// Router path the gate booted at (the app boots at `/welcome`; tests can
  /// use their own landing route). Used to decide when a cold-start unlock
  /// should redirect to `/home`. Captured on the first frame because the
  /// router's current configuration is not yet populated during [initState].
  String? _initialRoute;

  bool _loginRouted = false;
  bool _homeRouted = false;
  bool _loginRouteInFlight = false;
  DateTime? _backgroundedAt;

  /// Current router path, e.g. `/welcome` or `/home`.
  GoRouter get _router => widget.router ?? appRouter;

  String get _currentRoute =>
      _router.routerDelegate.currentConfiguration.uri.path;

  /// Reacts to (or reconciles with) the lock state. Called both by the
  /// [appLockProvider] listener and — once, on the first frame — with the
  /// already-resolved state, in case the notifier settled before the gate
  /// mounted (which the transition listener would otherwise miss).
  void _evaluate(AppLockState next) {
    if (next.needsLogin) {
      _homeRouted = true;
      if (!_loginRouted) {
        _loginRouted = true;
        _goToLogin();
      }
      return;
    }
    // First unlock of a real session after a cold start: land on /home.
    if (next.sessionExists &&
        next.status == AppLockStatus.unlocked &&
        !next.needsLogin &&
        !_homeRouted) {
      _homeRouted = true;
      _redirectHomeIfStillOnInitial();
    }
  }

  Future<void> _goToLogin() async {
    if (_loginRouteInFlight) return;
    _loginRouteInFlight = true;
    try {
      final email = await ref.read(sessionStoreProvider).readEmail() ?? '';
      if (!mounted) return;
      _router.go('/login', extra: email.isEmpty ? null : {'email': email});
      ref.read(appLockProvider.notifier).clearNeedsLogin();
    } catch (_) {
      if (mounted) _router.go('/login');
    } finally {
      _loginRouteInFlight = false;
    }
  }

  void _redirectHomeIfStillOnInitial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialRoute == null) return;
      if (_currentRoute == _initialRoute) {
        _router.go('/home');
      }
    });
  }

  void _handleUnauthorized(String? rejectedToken) {
    ref.read(appLockProvider.notifier)
        .expireToLogin(rejectedToken: rejectedToken);
  }

  @override
  void initState() {
    super.initState();
    // Capture the landing route as soon as the router has one; do this before
    // the first frame's post-frame callbacks run (see _redirectHomeIfStillOnInitial),
    // then reconcile with the lock state again in case it settled pre-mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialRoute ??= _currentRoute;
      _evaluate(ref.read(appLockProvider));
    });
    _lockSubscription = ref.listenManual(appLockProvider, (prev, next) => _evaluate(next));
    _unauthorizedHandler = ref.read(unauthorizedHandlerProvider);
    _unauthorizedHandler!.add(_handleUnauthorized);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unauthorizedHandler?.remove(_handleUnauthorized);
    _lockSubscription.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt != null &&
            DateTime.now().difference(backgroundedAt) >
                widget.backgroundThreshold) {
          ref.read(appLockProvider.notifier).relock();
        }
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appLockProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (state.status != AppLockStatus.unlocked) const UnlockScreen(),
      ],
    );
  }
}