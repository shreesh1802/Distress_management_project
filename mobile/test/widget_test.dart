import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RoadDistressApp()));
    await tester.pumpAndSettle();

    expect(find.text('Administrator Access'), findsOneWidget);
    expect(find.text('Secure Login'), findsOneWidget);
  });
}
