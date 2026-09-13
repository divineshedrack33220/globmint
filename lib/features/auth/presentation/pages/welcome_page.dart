import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _controller = PageController();
  int _page = 0;

  late final List<({IconData icon, String title, String subtitle})> _slides = [
    (
      icon: Icons.account_balance_wallet,
      title: 'Your own address',
      subtitle:
          'You get a personal on-chain address. Anyone can send you USDC '
          '\u2014 no wallet connect needed.',
    ),
    (
      icon: Icons.visibility_off,
      title: 'Privacy mode',
      subtitle:
          'Keep balances hidden from block explorers whenever you choose. '
          'Optional, always.',
    ),
    (
      icon: Icons.payments,
      title: 'Nearly free fees',
      subtitle:
          'Deposits cost only network gas. Withdrawals are 0.2% \u2014 '
          'min \u20a610, capped at \u20a6100.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      context.push('/create-account');
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SlideHero(icon: slide.icon),
                        const SizedBox(height: 36),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: context.typography.headline.copyWith(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: context.typography.bodyMedium.copyWith(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _PageDots(count: _slides.length, active: _page),
            const SizedBox(height: 8),
            const Text(
              'Self-custody \u00b7 No KYC',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.4,
                color: AppColors.textTertiary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Column(
                children: [
                  AppButton(
                    text: last ? 'Get Started' : 'Next',
                    onPressed: _next,
                    isExpanded: true,
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    text: 'I already have an account',
                    onPressed: () => context.push('/login'),
                    variant: AppButtonVariant.text,
                    isExpanded: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SlideHero extends StatelessWidget {
  const _SlideHero({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 168,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow,
            blurRadius: 60,
            spreadRadius: 12,
          ),
        ],
      ),
      child: Icon(icon, size: 84, color: AppColors.primaryForeground),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.borderLight,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}