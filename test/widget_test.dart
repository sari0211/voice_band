import 'package:flutter_test/flutter_test.dart';
import 'package:voice_band/main.dart';

void main() {
  testWidgets('App starts and shows Voice Band title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceBandApp());
    expect(find.text('Voice Band'), findsOneWidget);
  });
}
