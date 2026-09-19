import 'package:flutter_test/flutter_test.dart';
import 'package:ai_career_mentor/main.dart';

void main() {
  testWidgets(
    'AI Career Mentor app smoke test',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const AICareerMentorApp(),
      );

      // Splash screen has a 3-second timer.
      // Advance fake time so the timer completes.
      await tester.pump(const Duration(seconds: 3));

      // Allow the navigation/build to complete.
      await tester.pump();

      // App should still be running successfully.
      expect(
        find.byType(AICareerMentorApp),
        findsOneWidget,
      );
    },
  );
}