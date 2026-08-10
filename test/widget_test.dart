import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical_video/main.dart';

void main() {
  testWidgets('App splash screen render test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LyricalVideoApp(),
      ),
    );

    expect(find.text('Lyrical Video Maker'), findsOneWidget);
  });
}
