class EducationCenter {
  const EducationCenter({required this.id, required this.name, this.address = ''});
  final String id;
  final String name;
  final String address;
}

class Student {
  const Student({required this.id, required this.name, required this.groupId, this.birthDate = '', this.course = '', this.notes = '', this.attentionLevel = 0});
  final String id;
  final String name;
  final String groupId;
  final String birthDate;
  final String course;
  final String notes;
  final int attentionLevel;
}

class Professional {
  const Professional({required this.id, required this.name, required this.centerId, required this.role, this.notes = '', this.attentionLevel = 0});
  final String id;
  final String name;
  final String centerId;
  final String role;
  final String notes;
  final int attentionLevel;
}

class OrientationAppointment {
  const OrientationAppointment({required this.id, required this.title, required this.date, this.end, this.studentId, this.professionalId, this.centerId, this.groupId, this.resource = '', this.status = 'pending', this.color = 0, this.recurrence = '', this.reminderMinutes = 60, this.notes = ''});
  final String id;
  final String title;
  final DateTime date;
  final DateTime? end;
  final String? studentId;
  final String? professionalId;
  final String? centerId;
  final String? groupId;
  final String resource;
  final String status;
  final int color;
  final String recurrence;
  final int reminderMinutes;
  final String notes;
}

class OrientatorNote {
  const OrientatorNote({required this.id, required this.title, required this.body, this.color = 0, this.done = false});
  final String id;
  final String title;
  final String body;
  final int color;
  final bool done;
}

class OrientationServiceType {
  const OrientationServiceType({required this.id, required this.name, this.durationMinutes = 60, this.confidential = true, this.reminderMinutes = 60, this.templatePath = ''});
  final String id;
  final String name;
  final int durationMinutes;
  final bool confidential;
  final int reminderMinutes;
  final String templatePath;
}

class ServiceFormField {
  const ServiceFormField({required this.id, required this.serviceTypeId, required this.label, required this.type, this.required = false, this.confidential = true, this.options = ''});
  final String id;
  final String serviceTypeId;
  final String label;
  final String type;
  final bool required;
  final bool confidential;
  final String options;
}

class StudentImportDraft {
  const StudentImportDraft({this.name = '', this.birthDate = '', this.course = '', this.notes = '', required this.sourceText});
  final String name;
  final String birthDate;
  final String course;
  final String notes;
  final String sourceText;
}

class TemplateFieldProposal {
  TemplateFieldProposal({required this.key, required this.label, required this.value, required this.confidence, required this.origin, this.accepted = true});
  final String key;
  final String label;
  String value;
  final double confidence;
  final String origin;
  bool accepted;
}

class TemplateReviewDraft {
  TemplateReviewDraft({required this.fields, required this.sourceFormat, required this.sourceText, required this.templateFormat});
  final List<TemplateFieldProposal> fields;
  final String sourceFormat;
  final String sourceText;
  final String templateFormat;
}

class OrientationEvent {
  const OrientationEvent({required this.id, required this.title, required this.date, this.studentId});
  final String id;
  final String title;
  final DateTime date;
  final String? studentId;
}

class OrientationGroup {
  const OrientationGroup({required this.id, required this.name, required this.centerId});
  final String id;
  final String name;
  final String centerId;
}

class AppPreferences {
  const AppPreferences({this.navigation = 'grid', this.calendar = 'week', this.notes = 'paper', this.seedColor = 0xff087e8b, this.fontScale = 1, this.community = 'Andalucía', this.language = 'spanish', this.lockEnabled = true, this.lockMinutes = 10, this.lockOnBackground = true});
  final String navigation;
  final String calendar;
  final String notes;
  final int seedColor;
  final double fontScale;
  final String community;
  final String language;
  final bool lockEnabled;
  final int lockMinutes;
  final bool lockOnBackground;

  AppPreferences copyWith({String? navigation, String? calendar, String? notes, int? seedColor, double? fontScale, String? community, String? language, bool? lockEnabled, int? lockMinutes, bool? lockOnBackground}) => AppPreferences(navigation: navigation ?? this.navigation, calendar: calendar ?? this.calendar, notes: notes ?? this.notes, seedColor: seedColor ?? this.seedColor, fontScale: fontScale ?? this.fontScale, community: community ?? this.community, language: language ?? this.language, lockEnabled: lockEnabled ?? this.lockEnabled, lockMinutes: lockMinutes ?? this.lockMinutes, lockOnBackground: lockOnBackground ?? this.lockOnBackground);
}

class OfficialTemplateRecord {
  const OfficialTemplateRecord({required this.id, required this.community, required this.category, required this.title, required this.path, required this.extension, this.verified = false, this.sourceUrl = ''});
  final String id;
  final String community;
  final String category;
  final String title;
  final String path;
  final String extension;
  final bool verified;
  final String sourceUrl;
}
