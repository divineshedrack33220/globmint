import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../core/widgets/pin_verify_sheet.dart';
import '../../../../core/widgets/success_dialog.dart';

class WithdrawalReviewPage extends ConsumerStatefulWidget {
  const WithdrawalReviewPage({
    super.key,
    this.amount,
    this.account,
    this.destination,
    this.network,
  });

  final double? amount;
  final dynamic account; // kept for compatibility; unused in the vault flow
  final String? destination;
  final String? network;

  @override
  ConsumerState<WithdrawalReviewPage> createState() =>
      _WithdrawalReviewPageState();
}

class _WithdrawalReviewPageState extends ConsumerState<WithdrawalReviewPage> {
  bool _isProcessing = false;
  double? _usdcEstimate;

  /// Client-side mirror of the server withdrawal fee (GLOBMINT_WITHDRAW_FEE_*
  /// defaults: 20 bps = 0.2%, min ₦10, cap ₦100). Display-only: the server is
  /// authoritative and computes the same schedule in kobo.
  double _withdrawalFee(double amountNgn) {
    if (amountNgn <= 0) return 0;
    final raw = amountNgn * 20 / 10000;
    return raw.clamp(10.0, 100.0);
  }

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    final a = widget.amount ?? 0;
    if (a <= 0) return;
    try {
      final q = await ref
          .read(conversionServiceProvider)
          .getQuote(amount: a, fromCurrency: 'NGN', toCurrency: 'USDC');
      if (mounted) setState(() => _usdcEstimate = q.outputAmount);
    } catch (_) {
      // No inverse NGN->USDC rate available; omit the USDC line.
    }
  }

  Future<void> _confirmWithdrawal() async {
    final a = widget.amount ?? 0;
    final destination = widget.destination?.trim() ?? '';
    if (a <= 0 || destination.isEmpty) return;
    final fee = _withdrawalFee(a);

    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Finalize withdrawal?',
      details: [
        ConfirmationDetail(
            label: 'Amount', value: CurrencyFormatter.ngn(a), isHighlighted: true),
        ConfirmationDetail(
            label: 'Fee (0.2%)', value: CurrencyFormatter.ngn(fee)),
        ConfirmationDetail(
            label: 'Total charged', value: CurrencyFormatter.ngn(a + fee)),
        if (_usdcEstimate != null)
          ConfirmationDetail(
              label: 'You receive',
              value: '≈ ${_usdcEstimate!.toStringAsFixed(2)} USDC'),
        ConfirmationDetail(label: 'To', value: destination),
      ],
      confirmText: 'Confirm',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final pin = await showPinVerifySheet(
        context,
        title: 'Enter your PIN',
        subtitle: 'Verify it\u2019s you before sending ${CurrencyFormatter.ngn(a)}',
        onVerify: (pin) => ref.read(authServiceProvider).verifyPin(pin),
      );
      if (pin == null || !mounted) return;

      setState(() => _isProcessing = true);
      try {
        final txHash = await ref.read(savingsClientProvider).withdrawToAddress(
              amount: a.toStringAsFixed(2),
              destination: destination,
              pin: pin,
            );
        if (mounted) {
          ref.invalidate(accountSummaryProvider);
          ref.invalidate(transactionsProvider);
          ref.invalidate(vaultStatusProvider);
          setState(() => _isProcessing = false);
          _showSuccess(a, txHash);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Withdrawal failed: $e')),
          );
        }
      }
    }
  }

  void _showSuccess(double amount, String txHash) {
    SuccessDialog.show(
      context: context,
      type: SuccessDialogType.success,
      title: 'Withdrawal Sent',
      amount: CurrencyFormatter.ngn(amount),
      subtitle: 'USDC sent on-chain. Transaction: $txHash',
      onPressed: () => context.go('/savings'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.amount ?? 0;
    final destination = widget.destination?.trim() ?? '';
    final fee = _withdrawalFee(a);

    final availableAfter = ref.watch(accountSummaryProvider).whenOrNull(
          data: (s) => s.available.balance - a - fee,
        );

    final network = widget.network?.isNotEmpty == true
        ? widget.network!
        : ref
            .watch(depositInfoProvider)
            .maybeWhen(
              data: (info) =>
                  info.network.isNotEmpty ? info.network : 'on-chain',
              orElse: () => 'on-chain',
            );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Review Withdrawal')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    Text('You withdraw', style: context.typography.labelMedium),
                    const SizedBox(height: 4),
                    Text(CurrencyFormatter.ngn(a),
                        style: context.typography.amountHero),
                    if (_usdcEstimate != null) ...[
                      const SizedBox(height: 4),
                      Text('≈ ${_usdcEstimate!.toStringAsFixed(2)} USDC',
                          style: context.typography.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _ReviewRow(
                label: 'Fee (0.2%, min ₦10, cap ₦100)',
                value: CurrencyFormatter.ngn(fee),
              ),
              _ReviewRow(
                label: 'Total charged',
                value: CurrencyFormatter.ngn(a + fee),
              ),
              if (_usdcEstimate != null)
                _ReviewRow(
                  label: 'You receive',
                  value: '≈ ${_usdcEstimate!.toStringAsFixed(2)} USDC',
                ),
              _ReviewRow(
                label: 'Destination',
                value: destination,
              ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 8),
              _ReviewRow(
                label: 'Available after',
                value:
                    availableAfter != null ? CurrencyFormatter.ngn(availableAfter) : '—',
              ),
              const SizedBox(height: 8),
              _ReviewRow(
                label: 'Sent on',
                value: network,
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Confirm Withdrawal',
                isExpanded: true,
                isLoading: _isProcessing,
                onPressed: _confirmWithdrawal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.typography.bodyMedium),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.typography.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
