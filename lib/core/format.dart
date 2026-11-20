import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Locale-aware formatting for money, dates and times.
class Fmt {
  Fmt(this.lang);

  final String lang;

  String money(int cents) =>
      NumberFormat.currency(locale: lang, symbol: '€').format(cents / 100);

  /// Mon 3 Nov
  String day(DateTime d) => DateFormat('EEE d MMM', lang).format(d);

  /// Monday 3 November
  String dayLong(DateTime d) => DateFormat('EEEE d MMMM', lang).format(d);

  /// November 2026
  String monthYear(DateTime d) => DateFormat('LLLL y', lang).format(d);

  /// Two-letter weekday, e.g. Mo / ma
  String weekdayShort(DateTime d) {
    final t = DateFormat.E(lang).format(d);
    return t.length <= 2 ? t : t.substring(0, 2);
  }

  /// 3 Nov
  String dayShort(DateTime d) => DateFormat('d MMM', lang).format(d);

  /// 09:00
  String time(DateTime d) => DateFormat.Hm(lang).format(d);

  /// 09:00 – 11:00
  String timeRange(DateTime a, DateTime b) => '${time(a)} – ${time(b)}';

  /// 3 Nov 2026
  String date(DateTime d) => DateFormat('d MMM y', lang).format(d);

  /// 3 Nov, 09:00
  String dateTime(DateTime d) => '${DateFormat('d MMM', lang).format(d)}, ${time(d)}';

  /// 2026-11-03, the format the leave API expects.
  static String apiDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}

extension FmtContext on BuildContext {
  Fmt get fmt => Fmt(Localizations.localeOf(this).languageCode);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
