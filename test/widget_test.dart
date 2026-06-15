import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  testWidgets('app renders the floating dashboard shell', (tester) async {
    await tester.pumpWidget(const OjFloatApp());

    expect(find.text('OJ Float'), findsOneWidget);
    expect(find.text('总通过'), findsOneWidget);
    expect(find.text('每日总结'), findsOneWidget);
  });
}
