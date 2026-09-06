import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/countdown.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_confirmation_modal.dart';
import '../../../../shared/services/savings_client.dart';

/// Time-locked withdrawals awaiting release, with a live countdown and a
/// cancel action. Hidden entirely when there is nothing pending.
class PendingLockCard extends ConsumerStatefulWidget {
  const PendingLockCard({super.key});

  @override
  ConsumerState<PendingLockCard> createState() => _PendingLockCardState();
}

class _PendingLockCardState extends ConsumerState<PendingLockCard> {
  Timer? _timer;
  String? _cancellingId;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cancel(PendingElevation e) async {
    final confirmed = await ConfirmationModal.show(
      context: context,
      title: 'Cancel this withdrawal?',
      details: [
        ConfirmationDetail(
            label: 'Amount',
            value: CurrencyFormatter.ngn(e.amountNgn),
            isHighlighted: true),
        ConfirmationDetail(label: 'To', value: _shortAddress(e.destination)),
        const ConfirmationDetail(
            label: 'Fee', value: 'No fee — nothing has moved yet'),
      ],
      confirmText: 'Cancel withdrawal',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancellingId = e.id);
    try {
      final ok =
          await ref.read(savingsClientProvider).cancelElevation(e.id);
      if (!mounted) return;
      setState(() => _cancellingId = null);
      if (ok) {
        ref.invalidate(pendingElevationsProvider);
        ref.invalidate(accountSummaryProvider);
        ref.invalidate(vaultStatusProvider);
        ref.invalidate(transactionsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal cancelled — no fee charged')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not cancel — it may have already released')),
        );
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _cancellingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancel failed: $err')),
      );
    }
  }

  String _shortAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingElevationsProvider);
    return async.maybeWhen(
      data: (elevations) {
        if (elevations.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final e in elevations) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Releasing in ${formatCountdown(e.remaining)}',
                              style: context.typography.labelLarge),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${CurrencyFormatter.ngn(e.amountNgn)} → ${_shortAddress(e.destination)}',
                      style: context.typography.bodyMedium,
                    ),
                    if (e.feeNgn > 0)
                      Text(
                        'Includes ${CurrencyFormatter.ngn(e.feeNgn)} fee on release',
                        style: context.typography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _cancellingId == e.id ? null : () => _cancel(e),
                        child: _cancellingId == e.id
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Cancel withdrawal'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
