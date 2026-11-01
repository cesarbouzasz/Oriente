import 'package:sqlite3/sqlite3.dart';

void createOrientationSchema(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS centers (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      address TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS groups (
      id TEXT PRIMARY KEY NOT NULL,
      center_id TEXT NOT NULL REFERENCES centers(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS students (
      id TEXT PRIMARY KEY NOT NULL,
      group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      birth_date TEXT NOT NULL DEFAULT '',
      course TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT '',
      attention_level INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS professionals (
      id TEXT PRIMARY KEY NOT NULL,
      center_id TEXT NOT NULL REFERENCES centers(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      role TEXT NOT NULL,
      notes TEXT NOT NULL DEFAULT '',
      attention_level INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS orientation_events (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      event_date TEXT NOT NULL,
      end_date TEXT,
      student_id TEXT REFERENCES students(id) ON DELETE SET NULL,
      professional_id TEXT REFERENCES professionals(id) ON DELETE SET NULL,
      center_id TEXT REFERENCES centers(id) ON DELETE SET NULL,
      group_id TEXT REFERENCES groups(id) ON DELETE SET NULL,
      resource TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'pending',
      color INTEGER NOT NULL DEFAULT 0,
      recurrence TEXT NOT NULL DEFAULT '',
      reminder_minutes INTEGER NOT NULL DEFAULT 60,
      notes TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS orientator_notes (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      color INTEGER NOT NULL DEFAULT 0,
      done INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS service_types (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      duration_minutes INTEGER NOT NULL DEFAULT 60,
      confidential INTEGER NOT NULL DEFAULT 1,
      reminder_minutes INTEGER NOT NULL DEFAULT 60,
      template_path TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS service_form_fields (
      id TEXT PRIMARY KEY NOT NULL,
      service_type_id TEXT NOT NULL REFERENCES service_types(id) ON DELETE CASCADE,
      label TEXT NOT NULL,
      field_type TEXT NOT NULL,
      required INTEGER NOT NULL DEFAULT 0,
      confidential INTEGER NOT NULL DEFAULT 1,
      options TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS app_preferences (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS official_templates (
      id TEXT PRIMARY KEY NOT NULL,
      community TEXT NOT NULL,
      category TEXT NOT NULL,
      title TEXT NOT NULL,
      path TEXT NOT NULL,
      extension TEXT NOT NULL,
      verified INTEGER NOT NULL DEFAULT 0,
      source_url TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS student_case_events (
      id TEXT PRIMARY KEY NOT NULL,
      student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      event_type TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      event_date TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS legal_contacts (
      id TEXT PRIMARY KEY NOT NULL,
      student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      relationship TEXT NOT NULL,
      phone TEXT NOT NULL DEFAULT '',
      email TEXT NOT NULL DEFAULT '',
      legal_role TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS student_communications (
      id TEXT PRIMARY KEY NOT NULL,
      student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      channel TEXT NOT NULL,
      recipient TEXT NOT NULL DEFAULT '',
      summary TEXT NOT NULL,
      agreements TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'pending',
      communication_date TEXT NOT NULL,
      follow_up_date TEXT
    );
    CREATE TABLE IF NOT EXISTS document_versions (
      id TEXT PRIMARY KEY NOT NULL,
      student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      document_type TEXT NOT NULL,
      title TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      status TEXT NOT NULL DEFAULT 'draft',
      file_path TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS audit_log (
      id TEXT PRIMARY KEY NOT NULL,
      event_type TEXT NOT NULL,
      entity_type TEXT NOT NULL DEFAULT '',
      entity_id TEXT NOT NULL DEFAULT '',
      details TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS backup_records (
      id TEXT PRIMARY KEY NOT NULL,
      path TEXT NOT NULL,
      sha256 TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      verified INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS evaluations (
      id TEXT PRIMARY KEY NOT NULL,
      student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      instrument TEXT NOT NULL,
      area TEXT NOT NULL DEFAULT '',
      applied_at TEXT NOT NULL,
      direct_score TEXT NOT NULL DEFAULT '',
      scaled_score TEXT NOT NULL DEFAULT '',
      percentile TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS student_protocols (
      id TEXT PRIMARY KEY NOT NULL,
      student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      protocol_type TEXT NOT NULL,
      phase TEXT NOT NULL DEFAULT 'Detección',
      status TEXT NOT NULL DEFAULT 'active',
      due_date TEXT,
      notes TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS absences (
      id TEXT PRIMARY KEY NOT NULL,
      student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      absence_date TEXT NOT NULL,
      classification TEXT NOT NULL DEFAULT 'injustificada',
      minutes INTEGER NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS group_interventions (
      id TEXT PRIMARY KEY NOT NULL,
      student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      program TEXT NOT NULL,
      session_date TEXT NOT NULL,
      attendance TEXT NOT NULL DEFAULT 'present',
      observation TEXT NOT NULL DEFAULT '',
      material TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS institutional_identity (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      center_name TEXT NOT NULL DEFAULT '',
      center_code TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      signer_name TEXT NOT NULL DEFAULT '',
      signer_role TEXT NOT NULL DEFAULT '',
      logo_path TEXT NOT NULL DEFAULT '',
      seal_path TEXT NOT NULL DEFAULT '',
      signature_path TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS signing_profiles (
      id TEXT PRIMARY KEY NOT NULL,
      label TEXT NOT NULL,
      subject TEXT NOT NULL,
      issuer TEXT NOT NULL,
      serial_number TEXT NOT NULL,
      not_before TEXT NOT NULL,
      not_after TEXT NOT NULL,
      certificate_path TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_students_name ON students(name);
    CREATE INDEX IF NOT EXISTS idx_events_date ON orientation_events(event_date);
    CREATE INDEX IF NOT EXISTS idx_notes_done ON orientator_notes(done);
    CREATE INDEX IF NOT EXISTS idx_case_events_student_date ON student_case_events(student_id, event_date);
    CREATE INDEX IF NOT EXISTS idx_contacts_student ON legal_contacts(student_id);
    CREATE INDEX IF NOT EXISTS idx_communications_student_date ON student_communications(student_id, communication_date);
    CREATE INDEX IF NOT EXISTS idx_documents_student ON document_versions(student_id, document_type, version);
    CREATE INDEX IF NOT EXISTS idx_signing_profiles_active ON signing_profiles(active);
    CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log(created_at);
    CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_log(entity_type, entity_id);
    CREATE INDEX IF NOT EXISTS idx_backup_created ON backup_records(created_at);
  ''');
  _ensureColumn(db, 'students', 'birth_date', "TEXT NOT NULL DEFAULT ''");
  _ensureColumn(db, 'students', 'course', "TEXT NOT NULL DEFAULT ''");
  _ensureColumn(db, 'students', 'attention_level', 'INTEGER NOT NULL DEFAULT 0');
  _ensureColumn(db, 'professionals', 'attention_level', 'INTEGER NOT NULL DEFAULT 0');
  _ensureColumn(db, 'orientation_events', 'end_date', 'TEXT');
  _ensureColumn(db, 'orientation_events', 'professional_id', 'TEXT');
  _ensureColumn(db, 'orientation_events', 'center_id', 'TEXT');
  _ensureColumn(db, 'orientation_events', 'group_id', 'TEXT');
  _ensureColumn(db, 'orientation_events', 'resource', "TEXT NOT NULL DEFAULT ''");
  _ensureColumn(db, 'orientation_events', 'status', "TEXT NOT NULL DEFAULT 'pending'");
  _ensureColumn(db, 'orientation_events', 'color', 'INTEGER NOT NULL DEFAULT 0');
  _ensureColumn(db, 'orientation_events', 'recurrence', "TEXT NOT NULL DEFAULT ''");
  _ensureColumn(db, 'orientation_events', 'reminder_minutes', 'INTEGER NOT NULL DEFAULT 60');
  db.execute("INSERT OR IGNORE INTO service_types(id, name, duration_minutes, confidential, reminder_minutes) VALUES ('service-initial', 'Entrevista inicial', 60, 1, 1440), ('service-followup', 'Seguimiento individual', 45, 1, 60), ('service-family', 'Reunión con familia', 60, 1, 1440), ('service-tutor', 'Coordinación con tutor', 45, 1, 60), ('service-adaptation', 'Revisión de adaptación', 45, 1, 60), ('service-assessment', 'Valoración psicopedagógica', 90, 1, 1440)");
  db.execute("INSERT OR IGNORE INTO app_preferences(key, value) VALUES ('navigation', 'grid'), ('calendar', 'week'), ('notes', 'paper'), ('seed_color', 'ff087e8b'), ('font_scale', '1'), ('community', 'Andalucía'), ('language', 'spanish'), ('lock_enabled', '1'), ('lock_minutes', '10'), ('lock_on_background', '1')");
  _ensureColumn(db, 'document_versions', 'signature_status', "TEXT NOT NULL DEFAULT 'unsigned'");
  _ensureColumn(db, 'document_versions', 'signature_profile_id', "TEXT NOT NULL DEFAULT ''");
  _ensureColumn(db, 'document_versions', 'signature_subject', "TEXT NOT NULL DEFAULT ''");
  _ensureColumn(db, 'document_versions', 'signed_at', 'TEXT');
  _ensureColumn(db, 'document_versions', 'sha256', "TEXT NOT NULL DEFAULT ''");
  _ensureColumn(db, 'document_versions', 'parent_version_id', "TEXT NOT NULL DEFAULT ''");
  _ensureColumn(db, 'document_versions', 'content_hash', "TEXT NOT NULL DEFAULT ''");
  _ensureColumn(db, 'document_versions', 'reviewed_at', 'TEXT');
  _ensureColumn(db, 'document_versions', 'reviewed_by', "TEXT NOT NULL DEFAULT ''");
  _ensureColumn(db, 'document_versions', 'archived_at', 'TEXT');
}

void _ensureColumn(Database db, String table, String column, String definition) {
  final columns = db.select('PRAGMA table_info($table)').map((row) => row['name']).toSet();
  if (!columns.contains(column)) db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
}
