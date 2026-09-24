import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fitbit_health_dashboard/features/ai_coach/data/ai_rate_limiter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiRateLimiter Tests', () {
    late AiRateLimiter rateLimiter;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      rateLimiter = AiRateLimiter();
    });

    test('permits up to 10 queries per 2 hours and tracks quota', () async {
      for (int i = 0; i < 10; i++) {
        final quota = await rateLimiter.getRemainingQuota();
        expect(quota, 10 - i);
        await rateLimiter.recordRequest();
      }

      final quotaAfter10 = await rateLimiter.getRemainingQuota();
      expect(quotaAfter10, 0);
    });

    test('throws GeminiRateLimitException on 11th request', () async {
      for (int i = 0; i < 10; i++) {
        await rateLimiter.recordRequest();
      }

      expect(
        () async => await rateLimiter.recordRequest(),
        throwsA(isA<GeminiRateLimitException>().having(
          (e) => e.remainingMinutes,
          'remainingMinutes',
          greaterThan(0),
        )),
      );
    });
  });
}
