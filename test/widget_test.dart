import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suadinians_dates/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed
    expect(find.text('Saudi Dates Classifier'), findsOneWidget);

    // Verify that the camera button is present
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);

    // Verify that the initial state shows 'No prediction yet'
    expect(find.text('No prediction yet'), findsOneWidget);
  });
}
