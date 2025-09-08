/// Utility functions for formatting display text
class FormatUtils {
  /// Formats a count with a cap at 99, showing "99+" for counts above 99
  static String formatCountWithCap(int count) {
    return count > 99 ? '99+' : count.toString();
  }
}
