import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    this.backgroundThreshold = AppConstants.appLockBackgroundThreshold,
  });

  final Widget child;
  final Duration backgroundThreshold;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late final ProviderSubscription<AppLockState> _lockSubscription;
  UnauthorizedHandler? _unauthorizedHandler;

  bool _coldStart = false;
  bool _loginRouteInFlight = false;
  DateTime? _backgroundedAt;

  /// Current router path, e.g. `/welcome` or `/home`.
  String get _currentRoute =>
      appRouter.routerDelegate.currentConfiguration.uri.path;

  void _onLockChanged(AppLockState? previous, AppLockState next) {
    final prev = previous;

    // Always ignore the transition that simply clears the flag after we
    // navigated.
    if (!next.needsLogin && (prev?.needsLogin ?? false)) return;

    if (next.needsLogin && !(prev?.needsLogin ?? false)) {
      _goToLogin();
      return;
    }

    // Cold start with a valid session: after the first successful unlock,
    // land on /home (the initial route is /welcome).
    if (next.status == AppLockStatus.unlocked &&
        !next.needsLogin &&
        _coldStart &&
        (prev == null || prev.status != AppLockStatus.unlocked)) {
      _coldStart = false;
      _goHomeIfStillAtWelcome();
    }
  }

  Future<void> _goToLogin() async {
    if (_loginRouteInFlight) return;
    _loginRouteInFlight = true;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      final email = await ref.read(sessionStoreProvider).readEmail() ?? '';
      if (!mounted) return;
      appRouter.go('/login', extra: email.isEmpty ? null : {'email': email});
      ref.read(appLockProvider.notifier).clearNeedsLogin();
    } catch (_) {
      if (mounted) appRouter.go('/login');
    } finally {
      _loginRouteInFlight = false;
    }
  }

  void _goHomeIfStillAtWelcome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentRoute == '/welcome' || _currentRoute == '/') {
        appRouter.go('/home');
      }
    });
  }

  void _handleUnauthorized() {
    ref.read(appLockProvider.notifier).expireToLogin();
  }

  @override
  void initState() {
    super.initState();
    _coldStart = _currentRoute == '/welcome';
    _lockSubscription = ref.listenManual(appLockProvider, _onLockChanged);
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