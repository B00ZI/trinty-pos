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
  static DateTime getBusinessDayDate(DateTime now, StoreConfig config) {
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
      config.dayStartHour,
      config.dayStartMinute,
    );

    if (now.isBefore(todayStart)) {
      return todayStart.subtract(const Duration(days: 1));
    }
    return DateTime(now.year, now.month, now.day);
  }
}
