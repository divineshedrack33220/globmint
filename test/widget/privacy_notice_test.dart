import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:globe_mint/app/providers.dart';
import 'package:globe_mint/core/theme/app_theme.dart';
import 'package:globe_mint/features/savings/presentation/pages/add_money_page.dart';
import 'package:globe_mint/shared/services/api_client.dart';
import 'package:globe_mint/shared/services/savings_client.dart';
import 'package:globe_mint/shared/widgets/privacy_notice.dart';

/// Netless [SavingsClient] that answers with a controlled [DepositInfo].
class _FakeSavingsClient extends SavingsClient {
  _FakeSavingsClient({required this.info})
      : super(ApiClient(baseUrl: 'http://x'));

  final DepositInfo info;

  @override
  Future<DepositInfo> getDepositInfo() async => info;
}

DepositInfo _info({bool privacyEnabled = false}) => DepositInfo(
      address: '0xB6EdBecA8aB6EdBecA8aB6EdBecA8aB6EdBecA8a',
      vaultContract: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
      stablecoinSymbol: 'USDC',
      stablecoinName: 'USD Coin',
      stablecoinDecimals: 6,
      stablecoinContract: '',
      network: 'sepolia',
      chainId: 11155111,
      mode: 'real',
      privacyEnabled: privacyEnabled,
    );

Future<void> pumpAddMoney(WidgetTester tester, {bool privacyEnabled = false}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      savingsClientProvider.overrideWithValue(
        _FakeSavingsClient(info: _info(privacyEnabled: privacyEnabled)),
      ),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: const AddMoneyPage()),
  ));
  // Let the async getDepositInfo() resolve and rebuild.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('PrivacyNotice renders the full privacy copy', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(body: PrivacyNotice()),
    ));

    expect(find.text('How your deposits stay private'), findsOneWidget);
    expect(
      find.textContaining('one-way commitment', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('PrivacyNotice compact hides the body copy', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(body: PrivacyNotice(compact: true)),
    ));

    expect(find.text('Privacy-protected'), findsOneWidget);
    expect(find.text('How your deposits stay private'), findsNothing);
  });

  testWidgets('PrivacyBadge advertises the protected balance', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(body: Center(child: PrivacyBadge())),
    ));

    expect(find.text('Privacy-protected balance'), findsOneWidget);
  });

  testWidgets('AddMoneyPage shows the privacy badge when privacy is on',
      (tester) async {
    await pumpAddMoney(tester, privacyEnabled: true);

    expect(find.byType(PrivacyBadge), findsOneWidget);
    expect(find.byType(PrivacyNotice), findsOneWidget);
    expect(find.text('Privacy-protected balance'), findsOneWidget);
  });

  testWidgets('AddMoneyPage hides the privacy badge when privacy is off',
      (tester) async {
    await pumpAddMoney(tester, privacyEnabled: false);

    expect(find.byType(PrivacyBadge), findsNothing);
    expect(find.byType(PrivacyNotice), findsNothing);
    // The deposit address card still renders.
    expect(find.text('Send USDC to your vault'), findsOneWidget);
  });
}