import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RoadDistressApp()));
    await tester.pumpAndSettle();

    expect(find.text('Secure Access'), findsOneWidget);
    expect(find.text('Sign in with your authorized Google account.'), findsOneWidget);
  });
}
