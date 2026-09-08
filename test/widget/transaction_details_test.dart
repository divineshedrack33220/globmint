import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/core/enums/transaction_status.dart';
import 'package:globe_mint/core/enums/transaction_type.dart';
import 'package:globe_mint/core/theme/app_theme.dart';
import 'package:globe_mint/features/activity/presentation/pages/transaction_details_page.dart';
import 'package:globe_mint/shared/models/transaction.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/transaction_service.dart';

class _FakeTransactionService extends TransactionService {
  _FakeTransactionService(this._transactions)
      : super(ApiClient(baseUrl: 'http://x'));

  final List<Transaction> _transactions;

  @override
  Future<List<Transaction>> getTransactions() async => _transactions;
}

void main() {
  testWidgets('NGN transaction amount renders a single naira sign',
      (tester) async {
    final txn = Transaction(
      id: 'tx-1',
      type: TransactionType.deposit,
      amount: 132191.00,
      currency: 'NGN',
      status: TransactionStatus.completed,
      date: DateTime(2026, 9, 7),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        transactionServiceProvider.overrideWithValue(
          _FakeTransactionService([txn]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const TransactionDetailsPage(transactionId: 'tx-1'),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('₦132,191.00'), findsOneWidget);
    expect(find.text('₦₦132,191.00'), findsNothing);
    expect(find.textContaining('₦₦'), findsNothing);
  });
}