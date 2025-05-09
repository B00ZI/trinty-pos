import 'package:flutter_test/flutter_test.dart';
import 'package:Drywich/main.dart';
import 'package:Drywich/objectbox.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Create a real ObjectBox instance (uses actual database logic)
    final objectbox = await ObjectBox.create();

    // Build the app
    await tester.pumpWidget(Drywich(objectbox: objectbox));

    // Verify that the app title is found
    expect(find.text('Drywich'), findsOneWidget);

    // Optional: Close the store after the test
  });
}
