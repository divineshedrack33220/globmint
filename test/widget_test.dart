import 'package:flutter_test/flutter_test.dart';

import 'package:globe_mint/app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GlobeMintApp());
    await tester.pump();
  });
}
