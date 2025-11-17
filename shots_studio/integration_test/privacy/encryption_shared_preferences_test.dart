import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shots_studio/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Encryption Testing', () {
    setUpAll(() async {
      // Clear any stored preferences before each test.
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    testWidgets('SharedPreferences stores data in plain text on disk (Android)', (
      tester,
    ) async {
      const testApiKey = 'SUPER_SECRET_API_KEY_123';

      await tester.pumpWidget(const app.MyApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump(const Duration(milliseconds: 500));

      // Find the API key TextFormField by its hint text.
      final hintFinder = find.text('Enter Gemini API Key');
      final apiKeyFieldFinder = find.ancestor(
        of: hintFinder,
        matching: find.byType(TextFormField),
      );

      expect(
        apiKeyFieldFinder,
        findsOneWidget,
        reason:
            'Cannot find the API key TextFormField. '
            'Make sure the hint is "Enter Gemini API Key" in this locale.',
      );

      // Type the API key – this triggers onChanged -> _saveApiKey(value).
      await tester.enterText(apiKeyFieldFinder, testApiKey);

      // Wait for the API key to be saved to SharedPreferences.
      await tester.pump(const Duration(milliseconds: 500));

      if (Platform.isAndroid) {
        // Get the path to FlutterSharedPreferences.xml.
        final info = await PackageInfo.fromPlatform();
        final packageName = info.packageName;

        final prefsFile = File(
          '/data/data/$packageName/shared_prefs/FlutterSharedPreferences.xml',
        );

        expect(
          await prefsFile.exists(),
          isTrue,
          reason: 'Expected FlutterSharedPreferences.xml to exist.',
        );

        final contents = await prefsFile.readAsString();

        expect(
          contents.contains(testApiKey),
          isFalse,
          reason:
              'Boolean value for apiKey should not appear in plaintext in XML.',
        );
      } else {
        // Currently the test only works on Android
        print('Skipping disk check: not running on Android.');
        return;
      }
    });
  });
}
