import 'package:shared_preferences/shared_preferences.dart';

/// Result of checking or consuming the local daily AI allowance.
class AiRateLimitStatus {
  final bool allowed;
  final int remaining;

  const AiRateLimitStatus({required this.allowed, required this.remaining});
}

/// A lightweight on-device guard for the shared Gemini free-tier quota.
///
/// This is intentionally not an anti-tamper security boundary; a production
/// backend must enforce its own authenticated quota. It simply prevents normal
/// app usage from accidentally making too many requests from one device.
class AiRateLimitService {
  static const int dailyLimit = 15;
  static const String _dateKey = 'ai_questions_date';
  static const String _countKey = 'ai_questions_count';

  final DateTime Function() _now;

  AiRateLimitService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Returns today's allowance without consuming a question.
  Future<AiRateLimitStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final count = _countForToday(prefs);
    final remaining = dailyLimit - count;
    return AiRateLimitStatus(
      allowed: count < dailyLimit,
      remaining: remaining < 0 ? 0 : remaining,
    );
  }

  /// Atomically enough for this single-screen UI, consumes one local question.
  Future<AiRateLimitStatus> tryConsumeQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateStamp(_now());
    final count = _countForToday(prefs);

    if (count >= dailyLimit) {
      return const AiRateLimitStatus(allowed: false, remaining: 0);
    }

    final updatedCount = count + 1;
    await prefs.setString(_dateKey, today);
    await prefs.setInt(_countKey, updatedCount);

    return AiRateLimitStatus(
      allowed: true,
      remaining: dailyLimit - updatedCount,
    );
  }

  int _countForToday(SharedPreferences prefs) {
    if (prefs.getString(_dateKey) != _dateStamp(_now())) return 0;
    return prefs.getInt(_countKey) ?? 0;
  }

  static String _dateStamp(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
