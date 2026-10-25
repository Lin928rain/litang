import 'package:yaml/yaml.dart';

/// 周类型：理论教学 / 短期学期 / 考试周 / 假期。
class CalendarWeekType {
  const CalendarWeekType({
    required this.startWeek,
    required this.endWeek,
    required this.type,
    required this.label,
  });

  final int startWeek;
  final int endWeek;
  final String type;
  final String label;

  bool contains(int week) => week >= startWeek && week <= endWeek;
}

class CalendarVacation {
  const CalendarVacation({
    required this.name,
    required this.start,
    required this.end,
  });

  final String name;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

class AcademicTerm {
  const AcademicTerm({
    required this.id,
    required this.label,
    required this.week1Monday,
    required this.totalWeeks,
    required this.weekTypes,
    this.vacation,
  });

  final String id;
  final String label;
  final DateTime week1Monday;
  final int totalWeeks;
  final List<CalendarWeekType> weekTypes;
  final CalendarVacation? vacation;

  DateTime get endDate => week1Monday.add(Duration(days: totalWeeks * 7 - 1));

  bool containsDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(week1Monday) && !d.isAfter(endDate);
  }

  int? weekFor(DateTime date) {
    if (!containsDate(date)) return null;
    final d = DateTime(date.year, date.month, date.day);
    final days = d.difference(week1Monday).inDays;
    final week = days ~/ 7 + 1;
    if (week < 1 || week > totalWeeks) return null;
    return week;
  }

  CalendarWeekType? typeForWeek(int week) {
    for (final type in weekTypes) {
      if (type.contains(week)) return type;
    }
    return null;
  }

  CalendarWeekType? typeForDate(DateTime date) {
    final week = weekFor(date);
    return week == null ? null : typeForWeek(week);
  }

  bool isVacationDate(DateTime date) {
    final vacation = this.vacation;
    if (vacation != null && vacation.contains(date)) return true;
    return typeForDate(date)?.type == 'vacation';
  }
}

class AcademicCalendar {
  const AcademicCalendar({
    required this.schemaVersion,
    required this.academicYear,
    required this.currentTermId,
    required this.terms,
  });

  final int schemaVersion;
  final String academicYear;
  final String currentTermId;
  final List<AcademicTerm> terms;

  static AcademicCalendar? fromYaml(String raw) {
    try {
      final doc = loadYaml(raw);
      if (doc is! YamlMap) return null;
      final terms = <AcademicTerm>[];
      final rawTerms = doc['terms'];
      if (rawTerms is YamlList) {
        for (final item in rawTerms) {
          if (item is! YamlMap) continue;
          final id = (item['id'] ?? '').toString().trim();
          final label = (item['label'] ?? '').toString().trim();
          final start = _parseDate(item['week1Monday']);
          final total = (item['totalWeeks'] as num?)?.toInt() ?? 0;
          if (id.isEmpty || start == null || total <= 0) continue;
          final types = <CalendarWeekType>[];
          final rawTypes = item['weekTypes'];
          if (rawTypes is YamlList) {
            for (final type in rawTypes) {
              if (type is! YamlMap) continue;
              final range = _parseWeeks((type['weeks'] ?? '').toString());
              if (range == null) continue;
              types.add(
                CalendarWeekType(
                  startWeek: range.$1,
                  endWeek: range.$2,
                  type: (type['type'] ?? '').toString(),
                  label: (type['label'] ?? '').toString(),
                ),
              );
            }
          }
          CalendarVacation? vacation;
          final rawVacation = item['vacation'];
          if (rawVacation is YamlMap) {
            final vs = _parseDate(rawVacation['start']);
            final ve = _parseDate(rawVacation['end']);
            if (vs != null && ve != null) {
              vacation = CalendarVacation(
                name: (rawVacation['name'] ?? '').toString(),
                start: vs,
                end: ve,
              );
            }
          }
          terms.add(
            AcademicTerm(
              id: id,
              label: label.isEmpty ? id : label,
              week1Monday: start,
              totalWeeks: total,
              weekTypes: types,
              vacation: vacation,
            ),
          );
        }
      }
      if (terms.isEmpty) return null;
      terms.sort((a, b) => a.week1Monday.compareTo(b.week1Monday));
      return AcademicCalendar(
        schemaVersion: (doc['schemaVersion'] as num?)?.toInt() ?? 1,
        academicYear: (doc['academicYear'] ?? '').toString(),
        currentTermId: (doc['currentTerm'] ?? '').toString(),
        terms: terms,
      );
    } catch (_) {
      return null;
    }
  }

  AcademicTerm? termFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    for (final term in terms) {
      if (term.containsDate(d)) return term;
    }
    return null;
  }

  AcademicTerm? get currentTerm {
    if (currentTermId.isNotEmpty) {
      for (final term in terms) {
        if (term.id == currentTermId) return term;
      }
    }
    return termFor(DateTime.now());
  }

  int? get currentWeek {
    final term = currentTerm;
    if (term == null) return null;
    return term.weekFor(DateTime.now());
  }

  /// 配置缺失时的学年学期兜底，例如 2026-10 -> 2026-2027-1。
  static String fallbackTermId(DateTime date) {
    final year = date.year;
    if (date.month >= 8) return '$year-${year + 1}-1';
    if (date.month <= 1) return '${year - 1}-$year-1';
    return '${year - 1}-$year-2';
  }

  static DateTime? _parseDate(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static (int, int)? _parseWeeks(String raw) {
    final match = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(raw);
    if (match != null) {
      final start = int.tryParse(match.group(1)!);
      final end = int.tryParse(match.group(2)!);
      if (start != null && end != null && start <= end) return (start, end);
    }
    final single = int.tryParse(raw.trim());
    if (single != null) return (single, single);
    return null;
  }
}
