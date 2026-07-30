import 'package:flutter_test/flutter_test.dart';

import 'package:umbra/main.dart';

void main() {
  testWidgets('Umbra shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const UmbraApp());

    expect(find.text('Umbra'), findsOneWidget);
  });
}
