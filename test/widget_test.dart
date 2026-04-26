import 'package:flutter_test/flutter_test.dart';
import 'package:chunimaiq_app/main.dart';

void main() {
  testWidgets('App compiles smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChunimaiQApp());
    expect(find.byType(ChunimaiQApp), findsOneWidget);
  });
}
