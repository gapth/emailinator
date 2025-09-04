class DateProvider {
  static DateTime? _forcedToday;

  static DateTime now() {
    final realNow = DateTime.now();
    if (_forcedToday != null) {
      return DateTime(
        _forcedToday!.year,
        _forcedToday!.month,
        _forcedToday!.day,
        realNow.hour,
        realNow.minute,
        realNow.second,
        realNow.millisecond,
        realNow.microsecond,
      );
    }
    return realNow;
  }

  static void setForcedToday(DateTime? date) {
    _forcedToday =
        date == null ? null : DateTime(date.year, date.month, date.day);
  }

  static DateTime? get forcedToday => _forcedToday;
}
