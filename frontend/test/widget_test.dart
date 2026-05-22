import 'package:flutter_test/flutter_test.dart';

import 'package:pilotage_and_assistance_app/main.dart';

void main() {
  testWidgets('shows Firebase setup error when configuration is missing', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(firebaseError: 'missing config'));
    await tester.pump();

    expect(find.text('Firebase belum siap'), findsOneWidget);
    expect(find.text('missing config'), findsOneWidget);
  });
}
