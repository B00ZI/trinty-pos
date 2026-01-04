import 'package:flutter_test/flutter_test.dart';
import 'package:Easify/main.dart';
import 'package:Easify/objectbox.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Create a real ObjectBox instance (uses actual database logic)
    final objectbox = await ObjectBox.create();

    // Build the app
    await tester.pumpWidget(Easify(objectbox: objectbox));

    // Verify that the app title is found
    expect(find.text('Easify'), findsOneWidget);

    // Optional: Close the store after the test
  });
}
