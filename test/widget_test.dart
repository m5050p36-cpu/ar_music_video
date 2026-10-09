import 'package:flutter_test/flutter_test.dart';
import 'package:ar_music_video/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ARMusicApp());
    expect(find.byType(ARMusicApp), findsOneWidget);
  });
}
