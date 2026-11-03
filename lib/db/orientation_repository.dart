import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../models/orientation_models.dart';
import '../models/signing_models.dart';
import 'encrypted_database.dart';

class OrientationRepository {
  OrientationRepository(this._encrypted);
  final EncryptedDatabase _encrypted;
  final _uuid = const Uuid();
  Database get _db => _encrypted.database;

  List<Student> students({String query = ''}) {
    final rows = _db.select('SELECT id, name, group_id, birth_date, course, notes, attention_level FROM students WHERE name LIKE ? COLLATE NOCASE ORDER BY name LIMIT 200', ['%$query%']);
    return rows.map((r) => Student(id: r['id'] as String, name: r['name'] as String, groupId: r['group_id'] as String, birthDate: r['birth_date'] as String? ?? '', course: r['course'] as String? ?? '', notes: r['notes'] as String? ?? '', attentionLevel: (r['attention_level'] as int?) ?? 0)).toList();
  }

  String createStudent({required String name, required String groupId, String birthDate = '', String course = '', String notes = '', int attentionLevel = 0}) {
    final id = _uuid.v4();
    _db.execute('INSERT INTO students(id, group_id, name, birth_date, course, notes, attention_level, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [id, groupId, name.trim(), birthDate, course, notes, attentionLevel.clamp(0, 2), DateTime.now().toUtc().toIso8601String()]);
    return id;
  }

  void updateStudent(Student student) => _db.execute('UPDATE students SET group_id = ?, name = ?, birth_date = ?, course = ?, notes = ?, attention_level = ? WHERE id = ?', [student.groupId, student.name.trim(), student.birthDate, student.course, student.notes, student.attentionLevel.clamp(0, 2), student.id]);
  void deleteStudent(String id) => _db.execute('DELETE FROM students WHERE id = ?', [id]);

  List<Professional> professionals({String query = ''}) {
    final rows = _db.select('SELECT id, name, center_id, role, notes, attention_level FROM professionals WHERE name LIKE ? COLLATE NOCASE ORDER BY name LIMIT 200', ['%$query%']);
    return rows.map((r) => Professional(id: r['id'] as String, name: r['name'] as String, centerId: r['center_id'] as String, role: r['role'] as String, notes: r['notes'] as String? ?? '', attentionLevel: (r['attention_level'] as int?) ?? 0)).toList();
  }

  String createProfessional({required String name, required String centerId, required String role, String notes = '', int attentionLevel = 0}) {
    final id = _uuid.v4();
    _db.execute('INSERT INTO professionals(id, name, center_id, role, notes, attention_level) VALUES (?, ?, ?, ?, ?, ?)', [id, centerId, name.trim(), role.trim(), notes, attentionLevel.clamp(0, 2)]);
    return id;
  }

  void updateProfessional(Professional professional) => _db.execute('UPDATE professionals SET center_id = ?, name = ?, role = ?, notes = ?, attention_level = ? WHERE id = ?', [professional.centerId, professional.name.trim(), professional.role.trim(), professional.notes, professional.attentionLevel.clamp(0, 2), professional.id]);
  void deleteProfessional(String id) => _db.execute('DELETE FROM professionals WHERE id = ?', [id]);

  List<OrientationAppointment> appointments({DateTime? from, DateTime? to, String? professionalId, String? centerId, String? groupId, String? resource, String? status}) {
    final rows = _db.select('SELECT id, title, event_date, end_date, student_id, professional_id, center_id, group_id, resource, status, color, recurrence, reminder_minutes, notes FROM orientation_events WHERE event_date >= ? AND event_date < ? AND (? IS NULL OR professional_id = ?) AND (? IS NULL OR center_id = ?) AND (? IS NULL OR group_id = ?) AND (? IS NULL OR resource = ?) AND (? IS NULL OR status = ?) ORDER BY event_date', [(from ?? DateTime(2000)).toUtc().toIso8601String(), (to ?? DateTime(2100)).toUtc().toIso8601String(), professionalId, professionalId, centerId, centerId, groupId, groupId, resource, resource, status, status]);
    return rows.map((r) => OrientationAppointment(id: r['id'] as String, title: r['title'] as String, date: DateTime.parse(r['event_date'] as String).toLocal(), end: r['end_date'] == null ? null : DateTime.parse(r['end_date'] as String).toLocal(), studentId: r['student_id'] as String?, professionalId: r['professional_id'] as String?, centerId: r['center_id'] as String?, groupId: r['group_id'] as String?, resource: r['resource'] as String? ?? '', status: r['status'] as String? ?? 'pending', color: (r['color'] as int?) ?? 0, recurrence: r['recurrence'] as String? ?? '', reminderMinutes: (r['reminder_minutes'] as int?) ?? 60, notes: r['notes'] as String? ?? '')).toList();
  }

  String createAppointment({required String title, required DateTime date, DateTime? end, String? studentId, String? professionalId, String? centerId, String? groupId, String resource = '', String status = 'pending', int color = 0, String recurrence = '', int reminderMinutes = 60, String notes = ''}) {
    final id = _uuid.v4();
    _db.execute('INSERT INTO orientation_events(id, title, event_date, end_date, student_id, professional_id, center_id, group_id, resource, status, color, recurrence, reminder_minutes, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [id, title.trim(), date.toUtc().toIso8601String(), end?.toUtc().toIso8601String(), studentId, professionalId, centerId, groupId, resource, status, color.clamp(0, 8), recurrence, reminderMinutes.clamp(0, 10080), notes]);
    return id;
  }

  void updateAppointment(OrientationAppointment item) => _db.execute('UPDATE orientation_events SET title = ?, event_date = ?, end_date = ?, student_id = ?, professional_id = ?, center_id = ?, group_id = ?, resource = ?, status = ?, color = ?, recurrence = ?, reminder_minutes = ?, notes = ? WHERE id = ?', [item.title, item.date.toUtc().toIso8601String(), item.end?.toUtc().toIso8601String(), item.studentId, item.professionalId, item.centerId, item.groupId, item.resource, item.status, item.color, item.recurrence, item.reminderMinutes, item.notes, item.id]);
  void deleteAppointment(String id) => _db.execute('DELETE FROM orientation_events WHERE id = ?', [id]);
  bool hasOverlap({required DateTime start, required DateTime end, String? professionalId, String? resource, String? excludeId}) => _db.select('SELECT id FROM orientation_events WHERE id != ? AND (? IS NULL OR professional_id = ?) AND (? = \'\' OR resource = ?) AND event_date < ? AND COALESCE(end_date, event_date) > ? LIMIT 1', [excludeId ?? '', professionalId, professionalId, resource ?? '', resource ?? '', end.toUtc().toIso8601String(), start.toUtc().toIso8601String()]).isNotEmpty;

  List<OrientatorNote> notes({bool includeDone = true}) {
    final rows = _db.select('SELECT id, title, body, color, done FROM orientator_notes ${includeDone ? '' : 'WHERE done = 0'} ORDER BY done, updated_at DESC');
    return rows.map((r) => OrientatorNote(id: r['id'] as String, title: r['title'] as String, body: r['body'] as String, color: (r['color'] as int?) ?? 0, done: (r['done'] as int? ?? 0) == 1)).toList();
  }

  String createNote({required String title, required String body, int color = 0}) {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('INSERT INTO orientator_notes(id, title, body, color, done, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?)', [id, title.trim(), body.trim(), color.clamp(0, 4), now, now]);
    return id;
  }

  void updateNote(OrientatorNote note) => _db.execute('UPDATE orientator_notes SET title = ?, body = ?, color = ?, done = ?, updated_at = ? WHERE id = ?', [note.title.trim(), note.body.trim(), note.color.clamp(0, 4), note.done ? 1 : 0, DateTime.now().toUtc().toIso8601String(), note.id]);
  void deleteNote(String id) => _db.execute('DELETE FROM orientator_notes WHERE id = ?', [id]);

  List<OrientationServiceType> serviceTypes() => _db.select('SELECT id, name, duration_minutes, confidential, reminder_minutes, template_path FROM service_types ORDER BY name').map((r) => OrientationServiceType(id: r['id'] as String, name: r['name'] as String, durationMinutes: r['duration_minutes'] as int, confidential: (r['confidential'] as int) == 1, reminderMinutes: r['reminder_minutes'] as int, templatePath: r['template_path'] as String)).toList();

  String createServiceType({required String name, int durationMinutes = 60, bool confidential = true, int reminderMinutes = 60, String templatePath = ''}) {
    final id = _uuid.v4();
    _db.execute('INSERT INTO service_types(id, name, duration_minutes, confidential, reminder_minutes, template_path) VALUES (?, ?, ?, ?, ?, ?)', [id, name.trim(), durationMinutes, confidential ? 1 : 0, reminderMinutes, templatePath]);
    return id;
  }

  void addServiceField({required String serviceTypeId, required String label, required String type, bool required = false, bool confidential = true, String options = ''}) => _db.execute('INSERT INTO service_form_fields(id, service_type_id, label, field_type, required, confidential, options) VALUES (?, ?, ?, ?, ?, ?, ?)', [_uuid.v4(), serviceTypeId, label.trim(), type, required ? 1 : 0, confidential ? 1 : 0, options]);

  List<ServiceFormField> serviceFields(String serviceTypeId) => _db.select('SELECT id, service_type_id, label, field_type, required, confidential, options FROM service_form_fields WHERE service_type_id = ? ORDER BY rowid', [serviceTypeId]).map((r) => ServiceFormField(id: r['id'] as String, serviceTypeId: r['service_type_id'] as String, label: r['label'] as String, type: r['field_type'] as String, required: (r['required'] as int) == 1, confidential: (r['confidential'] as int) == 1, options: r['options'] as String)).toList();

  AppPreferences preferences() {
    final values = {for (final row in _db.select('SELECT key, value FROM app_preferences')) row['key'] as String: row['value'] as String};
    return AppPreferences(navigation: values['navigation'] ?? 'grid', calendar: values['calendar'] ?? 'week', notes: values['notes'] ?? 'paper', seedColor: int.tryParse(values['seed_color'] ?? '', radix: 16) ?? 0xff087e8b, fontScale: double.tryParse(values['font_scale'] ?? '') ?? 1, community: values['community'] ?? 'Andalucía', language: values['language'] ?? 'spanish', lockEnabled: values['lock_enabled'] != '0', lockMinutes: (int.tryParse(values['lock_minutes'] ?? '') ?? 10).clamp(1, 120).toInt(), lockOnBackground: values['lock_on_background'] != '0');
  }

  void savePreferences(AppPreferences preferences) {
    final values = {'navigation': preferences.navigation, 'calendar': preferences.calendar, 'notes': preferences.notes, 'seed_color': preferences.seedColor.toRadixString(16), 'font_scale': preferences.fontScale.toString(), 'community': preferences.community, 'language': preferences.language, 'lock_enabled': preferences.lockEnabled ? '1' : '0', 'lock_minutes': preferences.lockMinutes.clamp(1, 120).toString(), 'lock_on_background': preferences.lockOnBackground ? '1' : '0'};
    for (final entry in values.entries) {
      _db.execute('INSERT INTO app_preferences(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', [entry.key, entry.value]);
    }
  }

  List<OfficialTemplateRecord> officialTemplates({String? community, String? category}) {
    final rows = _db.select('SELECT id, community, category, title, path, extension, verified, source_url FROM official_templates WHERE (? IS NULL OR community = ?) AND (? IS NULL OR category = ?) ORDER BY title', [community, community, category, category]);
    return rows.map((r) => OfficialTemplateRecord(id: r['id'] as String, community: r['community'] as String, category: r['category'] as String, title: r['title'] as String, path: r['path'] as String, extension: r['extension'] as String, verified: (r['verified'] as int? ?? 0) == 1, sourceUrl: r['source_url'] as String? ?? '')).toList();
  }

  void registerOfficialTemplate({required String community, required String category, required String title, required String path, required String extension, bool verified = false, String sourceUrl = ''}) {
    final id = 'official-${community.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${category.toLowerCase()}';
    _db.execute('INSERT INTO official_templates(id, community, category, title, path, extension, verified, source_url, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET title = excluded.title, path = excluded.path, extension = excluded.extension, verified = excluded.verified, source_url = excluded.source_url, updated_at = excluded.updated_at', [id, community, category, title, path, extension, verified ? 1 : 0, sourceUrl, DateTime.now().toUtc().toIso8601String()]);
  }

  List<Map<String, Object?>> caseTimeline(String studentId) => _rows('SELECT id, event_type, title, description, event_date FROM student_case_events WHERE student_id = ? ORDER BY event_date DESC', [studentId]);
  void addCaseEvent({required String studentId, required String type, required String title, String description = '', DateTime? date}) => _db.execute('INSERT INTO student_case_events(id, student_id, event_type, title, description, event_date, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)', [_uuid.v4(), studentId, type, title, description, (date ?? DateTime.now()).toUtc().toIso8601String(), DateTime.now().toUtc().toIso8601String()]);

  List<Map<String, Object?>> legalContacts(String studentId) => _rows('SELECT id, name, relationship, phone, email, legal_role, notes FROM legal_contacts WHERE student_id = ? ORDER BY name', [studentId]);
  void addLegalContact({required String studentId, required String name, required String relationship, String phone = '', String email = '', String legalRole = '', String notes = ''}) => _db.execute('INSERT INTO legal_contacts(id, student_id, name, relationship, phone, email, legal_role, notes, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [_uuid.v4(), studentId, name, relationship, phone, email, legalRole, notes, DateTime.now().toUtc().toIso8601String()]);

  List<Map<String, Object?>> communications(String studentId) => _rows('SELECT id, channel, recipient, summary, agreements, status, communication_date, follow_up_date FROM student_communications WHERE student_id = ? ORDER BY communication_date DESC', [studentId]);
  void addCommunication({required String studentId, required String channel, required String recipient, required String summary, String agreements = '', String status = 'pending', DateTime? followUp}) => _db.execute('INSERT INTO student_communications(id, student_id, channel, recipient, summary, agreements, status, communication_date, follow_up_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [_uuid.v4(), studentId, channel, recipient, summary, agreements, status, DateTime.now().toUtc().toIso8601String(), followUp?.toUtc().toIso8601String()]);

  List<Map<String, Object?>> documentVersions(String studentId) => _rows('SELECT id, document_type, title, version, status, file_path, created_at, updated_at FROM document_versions WHERE student_id = ? ORDER BY updated_at DESC', [studentId]);
  void addDocumentVersion({required String studentId, required String type, required String title, required int version, required String status, String path = ''}) => _db.execute('INSERT INTO document_versions(id, student_id, document_type, title, version, status, file_path, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [_uuid.v4(), studentId, type, title, version, status, path, DateTime.now().toUtc().toIso8601String(), DateTime.now().toUtc().toIso8601String()]);
  void addSignedDocumentVersion({required String studentId, required String type, required String title, required int version, required String path, required String profileId, required String subject, required String sha256}) => _db.execute("INSERT INTO document_versions(id, student_id, document_type, title, version, status, file_path, created_at, updated_at, signature_status, signature_profile_id, signature_subject, signed_at, sha256) VALUES (?, ?, ?, ?, ?, 'signed', ?, ?, ?, 'pades-bes', ?, ?, ?, ?)", [_uuid.v4(), studentId, type, title, version, path, DateTime.now().toUtc().toIso8601String(), DateTime.now().toUtc().toIso8601String(), profileId, subject, DateTime.now().toUtc().toIso8601String(), sha256]);
  void setDocumentStatus(String id, String status) => transitionDocumentStatus(id: id, status: status);

  void logAudit({required String eventType, String entityType = '', String entityId = '', String details = ''}) {
    _ensureAuditTables();
    _db.execute('INSERT INTO audit_log(id, event_type, entity_type, entity_id, details, created_at) VALUES (?, ?, ?, ?, ?, ?)', [_uuid.v4(), eventType, entityType, entityId, details, DateTime.now().toUtc().toIso8601String()]);
  }

  List<Map<String, Object?>> auditLog({int limit = 200}) => _rows('SELECT id, event_type, entity_type, entity_id, details, created_at FROM audit_log ORDER BY created_at DESC LIMIT ?', [limit.clamp(1, 1000)]);

  void recordBackup({required String path, required String sha256, required int sizeBytes, bool verified = true}) {
    _ensureAuditTables();
    _db.execute('INSERT INTO backup_records(id, path, sha256, size_bytes, created_at, verified) VALUES (?, ?, ?, ?, ?, ?)', [_uuid.v4(), path, sha256, sizeBytes, DateTime.now().toUtc().toIso8601String(), verified ? 1 : 0]);
  }

  void _ensureAuditTables() {
    _db.execute('CREATE TABLE IF NOT EXISTS audit_log (id TEXT PRIMARY KEY NOT NULL, event_type TEXT NOT NULL, entity_type TEXT NOT NULL DEFAULT \'\', entity_id TEXT NOT NULL DEFAULT \'\', details TEXT NOT NULL DEFAULT \'\', created_at TEXT NOT NULL)');
    _db.execute('CREATE TABLE IF NOT EXISTS backup_records (id TEXT PRIMARY KEY NOT NULL, path TEXT NOT NULL, sha256 TEXT NOT NULL, size_bytes INTEGER NOT NULL, created_at TEXT NOT NULL, verified INTEGER NOT NULL DEFAULT 0)');
  }

  String createDocumentVersion({required String studentId, required String type, required String title, String path = '', String contentHash = '', String parentVersionId = ''}) {
    final previous = _db.select('SELECT COALESCE(MAX(version), 0) AS version FROM document_versions WHERE student_id = ? AND document_type = ? AND title = ?', [studentId, type, title]).first['version'] as int;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('INSERT INTO document_versions(id, student_id, document_type, title, version, status, file_path, created_at, updated_at, parent_version_id, content_hash) VALUES (?, ?, ?, ?, ?, \'draft\', ?, ?, ?, ?, ?)', [id, studentId, type, title, previous + 1, path, now, now, parentVersionId, contentHash]);
    logAudit(eventType: 'document_created', entityType: 'document_version', entityId: id, details: 'draft:v${previous + 1}');
    return id;
  }

  void transitionDocumentStatus({required String id, required String status, String reviewedBy = ''}) {
    const allowed = {'draft': {'in_review'}, 'in_review': {'draft', 'validated'}, 'validated': {'final'}, 'final': {'signed', 'archived'}, 'signed': {'archived'}, 'archived': <String>{}};
    final row = _db.select('SELECT status FROM document_versions WHERE id = ?', [id]);
    if (row.isEmpty) throw StateError('La versión documental no existe.');
    final current = row.first['status'] as String;
    if (!allowed.containsKey(current) || !allowed[current]!.contains(status)) throw StateError('Transición documental no permitida: $current → $status.');
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('UPDATE document_versions SET status = ?, updated_at = ?, reviewed_at = CASE WHEN ? IN (\'validated\', \'final\') THEN ? ELSE reviewed_at END, reviewed_by = CASE WHEN ? IN (\'validated\', \'final\') THEN ? ELSE reviewed_by END, archived_at = CASE WHEN ? = \'archived\' THEN ? ELSE archived_at END WHERE id = ?', [status, now, status, now, status, reviewedBy, status, now, id]);
    logAudit(eventType: 'document_status_changed', entityType: 'document_version', entityId: id, details: '$current → $status');
  }

  List<Map<String, Object?>> evaluations(String studentId) => _rows('SELECT id, instrument, area, applied_at, direct_score, scaled_score, percentile, notes FROM evaluations WHERE student_id = ? ORDER BY applied_at DESC', [studentId]);
  void addEvaluation({required String studentId, required String instrument, required String area, required String directScore, required String scaledScore, required String percentile, required String notes}) => _db.execute('INSERT INTO evaluations(id, student_id, instrument, area, applied_at, direct_score, scaled_score, percentile, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [_uuid.v4(), studentId, instrument, area, DateTime.now().toUtc().toIso8601String(), directScore, scaledScore, percentile, notes]);

  List<Map<String, Object?>> protocols(String studentId) => _rows('SELECT id, protocol_type, phase, status, due_date, notes, updated_at FROM student_protocols WHERE student_id = ? ORDER BY updated_at DESC', [studentId]);
  void addProtocol({required String studentId, required String type, required String phase, required String status, String notes = ''}) => _db.execute('INSERT INTO student_protocols(id, student_id, protocol_type, phase, status, notes, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)', [_uuid.v4(), studentId, type, phase, status, notes, DateTime.now().toUtc().toIso8601String()]);

  List<Map<String, Object?>> absences(String studentId) => _rows('SELECT id, absence_date, classification, minutes, notes FROM absences WHERE student_id = ? ORDER BY absence_date DESC', [studentId]);
  void addAbsence({required String studentId, required String classification, int minutes = 0, String notes = ''}) => _db.execute('INSERT INTO absences(id, student_id, absence_date, classification, minutes, notes) VALUES (?, ?, ?, ?, ?, ?)', [_uuid.v4(), studentId, DateTime.now().toUtc().toIso8601String(), classification, minutes, notes]);

  List<Map<String, Object?>> groupInterventions(String studentId) => _rows('SELECT id, program, session_date, attendance, observation, material FROM group_interventions WHERE student_id = ? ORDER BY session_date DESC', [studentId]);
  void addGroupIntervention({required String studentId, required String program, required String attendance, required String observation, required String material}) => _db.execute('INSERT INTO group_interventions(id, student_id, program, session_date, attendance, observation, material) VALUES (?, ?, ?, ?, ?, ?, ?)', [_uuid.v4(), studentId, program, DateTime.now().toUtc().toIso8601String(), attendance, observation, material]);

  List<Map<String, Object?>> _rows(String sql, [List<Object?> parameters = const []]) => _db.select(sql, parameters).map((row) => Map<String, Object?>.from(row)).toList();

  InstitutionalIdentity identity() {
    final rows = _rows('SELECT center_name, center_code, address, signer_name, signer_role, logo_path, seal_path, signature_path FROM institutional_identity WHERE id = 1');
    if (rows.isEmpty) return const InstitutionalIdentity();
    final row = rows.first;
    return InstitutionalIdentity(centerName: row['center_name'] as String? ?? '', centerCode: row['center_code'] as String? ?? '', address: row['address'] as String? ?? '', signerName: row['signer_name'] as String? ?? '', signerRole: row['signer_role'] as String? ?? '', logoPath: row['logo_path'] as String? ?? '', sealPath: row['seal_path'] as String? ?? '', signaturePath: row['signature_path'] as String? ?? '');
  }

  void saveIdentity(InstitutionalIdentity identity) => _db.execute('INSERT INTO institutional_identity(id, center_name, center_code, address, signer_name, signer_role, logo_path, seal_path, signature_path) VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET center_name = excluded.center_name, center_code = excluded.center_code, address = excluded.address, signer_name = excluded.signer_name, signer_role = excluded.signer_role, logo_path = excluded.logo_path, seal_path = excluded.seal_path, signature_path = excluded.signature_path', [identity.centerName, identity.centerCode, identity.address, identity.signerName, identity.signerRole, identity.logoPath, identity.sealPath, identity.signaturePath]);

  void saveSigningProfile(SigningProfile profile) {
    _db.execute('UPDATE signing_profiles SET active = 0');
    _db.execute('INSERT INTO signing_profiles(id, label, subject, issuer, serial_number, not_before, not_after, certificate_path, active, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?) ON CONFLICT(id) DO UPDATE SET label = excluded.label, subject = excluded.subject, issuer = excluded.issuer, serial_number = excluded.serial_number, not_before = excluded.not_before, not_after = excluded.not_after, certificate_path = excluded.certificate_path, active = 1', [profile.id, profile.label, profile.subject, profile.issuer, profile.serialNumber, profile.notBefore.toUtc().toIso8601String(), profile.notAfter.toUtc().toIso8601String(), profile.certificatePath, DateTime.now().toUtc().toIso8601String()]);
  }

  List<SigningProfile> signingProfiles() => _db.select('SELECT id, label, subject, issuer, serial_number, not_before, not_after, certificate_path, active FROM signing_profiles ORDER BY active DESC, label').map((r) => SigningProfile(id: r['id'] as String, label: r['label'] as String, subject: r['subject'] as String, issuer: r['issuer'] as String, serialNumber: r['serial_number'] as String, notBefore: DateTime.parse(r['not_before'] as String), notAfter: DateTime.parse(r['not_after'] as String), certificatePath: r['certificate_path'] as String, active: (r['active'] as int? ?? 0) == 1)).toList();
}
