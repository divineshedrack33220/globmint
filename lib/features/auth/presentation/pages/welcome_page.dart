import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Logo
              Container(
                width: 96,
                height: 96,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Globe Mint',
                style: context.typography.display.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your digital savings vault',
                style: context.typography.bodyMedium,
              ),
              const Spacer(flex: 2),
              // Features
              _FeatureItem(
                icon: Icons.lock_outline,
                title: 'Secure Savings',
                description: 'Your money, protected by modern security',
              ),
              const SizedBox(height: 20),
              _FeatureItem(
                icon: Icons.currency_exchange,
                title: 'Smart Conversion',
                description: 'Seamlessly convert between NGN and USDT',
              ),
              const SizedBox(height: 20),
              _FeatureItem(
                icon: Icons.speed,
                title: 'Instant Access',
                description: 'Withdraw to your bank account anytime',
              ),
              const Spacer(flex: 3),
              AppButton(
                text: 'Get Started',
                onPressed: () => context.push('/create-account'),
                isExpanded: true,
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'I already have an account',
                onPressed: () => context.push('/login'),
                variant: AppButtonVariant.text,
                isExpanded: true,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.typography.labelLarge),
              const SizedBox(height: 2),
              Text(description, style: context.typography.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
