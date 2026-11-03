import 'dart:convert';

import '../models/orientation_models.dart';

class IcsImportResult {
  const IcsImportResult(this.events, this.duplicates);
  final List<OrientationAppointment> events;
  final List<OrientationAppointment> duplicates;
}

class IcsCalendarService {
  List<int> exportEvents(List<OrientationAppointment> events) {
    final lines = <String>['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Cercano Oriente//ES'];
    for (final event in events) {
      lines.addAll(['BEGIN:VEVENT', 'UID:${event.id}', 'DTSTART:${_format(event.date)}', 'SUMMARY:${_escape(event.title)}', if (event.end != null) 'DTEND:${_format(event.end!)}', 'DESCRIPTION:${_escape(event.notes)}', 'END:VEVENT']);
    }
    lines.add('END:VCALENDAR');
    return utf8.encode(lines.join('\r\n'));
  }

  IcsImportResult importEvents(String text, {required List<OrientationAppointment> existing}) {
    final events = <OrientationAppointment>[];
    final matches = RegExp(r'SUMMARY:(.*)').allMatches(text);
    for (var i = 0; i < matches.length; i++) {
      final title = matches.elementAt(i).group(1)?.replaceAll(r'\,', ',') ?? 'Cita importada';
      final date = DateTime.now().add(Duration(days: i));
      events.add(OrientationAppointment(id: 'ics-${date.microsecondsSinceEpoch}', title: title, date: date, status: 'pending', notes: 'Importado desde ICS'));
    }
    final duplicates = events.where((e) => existing.any((x) => x.title == e.title && x.date.year == e.date.year && x.date.month == e.date.month && x.date.day == e.date.day)).toList();
    return IcsImportResult(events, duplicates);
  }

  String _format(DateTime value) => '${value.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
  String _escape(String value) => value.replaceAll(',', r'\,').replaceAll('\n', r'\n');
}
