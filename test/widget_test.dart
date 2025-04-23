import 'package:flutter_test/flutter_test.dart';

import 'package:chatbot/main.dart';
import 'package:chatbot/chat_screen.dart';

void main() {
  testWidgets('ChatScreen is present', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that ChatScreen is present.
    expect(find.byType(ChatScreen), findsOneWidget);
  });
}
