import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shots_studio/services/analytics/posthog_analytics_service.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'posthog_analytics_privacy_by_default_test.mocks.dart';

@GenerateMocks([Posthog])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostHogAnalyticsService: No Logging Before Consent', () {
    late MockPosthog mockPosthog;
    late PostHogAnalyticsService service;

    setUp(() {
      mockPosthog = MockPosthog();
      service = PostHogAnalyticsService.test(mockPosthog);
    });

    test('should disable analytics by default', () async {
      SharedPreferences.setMockInitialValues({});

      await service.initialize();

      expect(service.analyticsEnabled, isFalse);
    });

    test(
      'initialize() with consent=false calls disable() and never capture()',
      () async {
        SharedPreferences.setMockInitialValues({
          'analytics_consent_enabled': false,
        });

        await service.initialize();

        // verifyNever(mockPosthog.setup(any));
        verify(mockPosthog.disable()).called(1);
        verifyNever(mockPosthog.enable());

        // No events sent (startup etc.)
        verifyNever(
          mockPosthog.capture(
            eventName: anyNamed('eventName'),
            properties: anyNamed('properties'),
          ),
        );
      },
    );

    test(
      'initialize() with consent=true calls enable() and logAppStartup()',
      () async {
        SharedPreferences.setMockInitialValues({
          'analytics_consent_enabled': true,
        });

        await service.initialize();

        // Opted in at SDK level
        verify(mockPosthog.enable()).called(1);
        verifyNever(mockPosthog.disable());

        // Startup event is captured
        verify(
          mockPosthog.capture(
            eventName: 'app_startup',
            properties: anyNamed('properties'),
          ),
        ).called(1);
      },
    );

    test(
      'logFeatureUsed() before init or consent never calls capture()',
      () async {
        SharedPreferences.setMockInitialValues({
          'analytics_consent_enabled': false,
        });

        await service.logFeatureUsed('some_feature');

        verifyZeroInteractions(mockPosthog);
      },
    );

    test(
      'enableAnalytics() after init toggles SDK from disable() to enable()',
      () async {
        // start with disabled
        SharedPreferences.setMockInitialValues({
          'analytics_consent_enabled': false,
        });

        await service.initialize();

        verify(mockPosthog.disable()).called(1);
        reset(mockPosthog);

        await service.enableAnalytics();

        // Now SDK is enabled and we log `analytics_enabled`
        verify(mockPosthog.enable()).called(1);
        verify(
          mockPosthog.capture(
            eventName: 'feature_used',
            properties: argThat(
              containsPair('feature_name', 'analytics_enabled'),
              named: 'properties',
            ),
          ),
        ).called(1);
      },
    );

    test(
      'disableAnalytics() after init calls disable() and prevents capture()',
      () async {
        SharedPreferences.setMockInitialValues({
          'analytics_consent_enabled': true,
        });

        await service.initialize();
        reset(mockPosthog); // forget calls from initialize()

        await service.disableAnalytics();

        // We logged "analytics_disabled" BEFORE turning off
        verify(
          mockPosthog.capture(
            eventName: 'feature_used',
            properties: argThat(
              containsPair('feature_name', 'analytics_disabled'),
              named: 'properties',
            ),
          ),
        ).called(1);

        // SDK-level opt-out
        verify(mockPosthog.disable()).called(1);

        reset(mockPosthog);

        // Further logging attempts should be no-ops
        await service.logFeatureUsed('some_feature');
        await service.logAppStartup();

        verifyZeroInteractions(mockPosthog);
      },
    );
  });
}
