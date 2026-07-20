library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hex_haven/core/constants.dart';
import 'package:hex_haven/services/review_service.dart';

void main() {
  late ReviewService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = const ReviewService();
  });

  group('shouldPromptForReview', () {
    test('returns false below threshold', () async {
      expect(await service.shouldPromptForReview(0), false);
      expect(
        await service.shouldPromptForReview(kReviewPromptGamesThreshold - 1),
        false,
      );
    });

    test('returns true at threshold', () async {
      expect(
        await service.shouldPromptForReview(kReviewPromptGamesThreshold),
        true,
      );
    });

    test('returns true above threshold if not yet shown', () async {
      expect(
        await service.shouldPromptForReview(kReviewPromptGamesThreshold + 100),
        true,
      );
    });
  });

  test('markPromptShown prevents future prompts', () async {
    await service.markPromptShown();
    expect(await service.shouldPromptForReview(999), false);
  });
}
