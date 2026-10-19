import '../models/store_config.dart';

class BusinessDayHelper {
  /// Returns the start and end DateTime for a given business date.
  /// The business day starts at [config.dayStartHour]:[config.dayStartMinute]
  /// and ends exactly 24 hours later (the next day's start time).
  static (DateTime start, DateTime end) getBusinessDayRange(
      DateTime businessDate, StoreConfig config) {
    final start = DateTime(
      businessDate.year,
      businessDate.month,
      businessDate.day,
      config.dayStartHour,
      config.dayStartMinute,
    );
    final end = start.add(const Duration(hours: 24));
    return (start, end);
  }

  /// Determines which business day date an arbitrary [now] belongs to.
  /// If [now] is before the configured start time of the calendar day,
  /// it belongs to the previous calendar day's business day.
  /// Always returns a MIDNIGHT date (P19: callers store/compare this
  /// date — the two branches used to return different times of day).
  static DateTime getBusinessDayDate(DateTime now, StoreConfig config) {
    final dayMidnight = DateTime(now.year, now.month, now.day);
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
      config.dayStartHour,
      config.dayStartMinute,
    );

    if (now.isBefore(todayStart)) {
      return dayMidnight.subtract(const Duration(days: 1));
    }
    return dayMidnight;
  }

  /// Best day-reset time derived from the owner's USUAL working hours
  /// (P27 — owner's idea): the MIDDLE of the closed gap (closing → next
  /// opening). The middle is the safest minute — the shop can open hours
  /// earlier or later than usual and the day's work still lands in ONE
  /// business day. Degenerate answers (no closed gap, open == close)
  /// fall back to midnight.
  static (int hour, int minute) resetFromHours({
    required int openHour,
    required int openMinute,
    required int closeHour,
    required int closeMinute,
  }) {
    final open = openHour * 60 + openMinute;
    final close = closeHour * 60 + closeMinute;
    final closedMinutes = (open - close + 1440) % 1440;
    if (closedMinutes == 0) return (0, 0); // no closed gap → midnight
    final reset = (close + closedMinutes ~/ 2) % 1440;
    return (reset ~/ 60, reset % 60);
  }
}
