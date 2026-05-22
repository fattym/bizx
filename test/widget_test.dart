import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dehus/main.dart';

void main() {
  testWidgets('renders the welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DeHeusApp(useRemoteHeroImage: false));

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}
