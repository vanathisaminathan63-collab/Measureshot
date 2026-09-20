import 'package:flutter_test/flutter_test.dart';

import 'package:kitchen/main.dart';

void main() {
  testWidgets('App starts on the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MeasureShotApp());

    expect(find.text('MeasureShot'), findsOneWidget);
    expect(find.text('Start New Report'), findsOneWidget);
    expect(find.text('Report progress'), findsOneWidget);
  });
}