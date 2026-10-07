import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/main.dart';

void main() {
  testWidgets('NitPliks smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NitPliksApp(),
      ),
    );

    // Verify that the title NitPliks is rendered on the screen
    expect(find.text('NitPliks'), findsOneWidget);
  });
}
