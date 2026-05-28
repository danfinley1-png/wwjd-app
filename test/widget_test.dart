// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wwjd_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WWJDApp());   // ← Changed from MyApp

    // Basic smoke test - check if app launches without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}