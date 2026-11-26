import 'package:intl/intl.dart';

class AppDateFormatter {
  AppDateFormatter._();

  static String dateOnly(DateTime dt) {
    return DateFormat('d MMM yyyy', 'id_ID').format(dt.toLocal());
  }

  static String fullDate(DateTime dt) {
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt.toLocal());
  }

  static String dateTime(DateTime dt) {
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt.toLocal());
  }

  static String timeOnly(DateTime dt) {
    return DateFormat('HH:mm', 'id_ID').format(dt.toLocal());
  }

  static String shortDayMonth(DateTime dt) {
    return DateFormat('d/M', 'id_ID').format(dt.toLocal());
  }

  static String relativeOrDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(target).inDays;

    if (diffDays == 0) {
      return 'Hari ini, ${timeOnly(local)}';
    } else if (diffDays == 1) {
      return 'Kemarin, ${timeOnly(local)}';
    } else if (diffDays == -1) {
      return 'Besok, ${timeOnly(local)}';
    }
    return dateTime(local);
  }
}
