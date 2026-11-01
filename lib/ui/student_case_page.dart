import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

import '../db/encrypted_database.dart';
import '../db/orientation_repository.dart';
import '../models/orientation_models.dart';
import '../models/signing_models.dart';
import '../services/report_export_service.dart';
import '../services/pades_signing_service.dart';

class StudentCasePage extends StatefulWidget {
  const StudentCasePage({required this.database, required this.student, super.key});
  final EncryptedDatabase database;
  final Student student;
  @override
  State<StudentCasePage> createState() => _StudentCasePageState();
}

class _StudentCasePageState extends State<StudentCasePage> {
  late final OrientationRepository _repo = OrientationRepository(widget.database);
  final _reports = ReportExportService();
  final _pades = PadesSigningService();

  Future<void> _exportCaseReport() async {
    try {
      await _reports.exportStudentCasePdf(student: widget.student, timeline: _repo.caseTimeline(widget.student.id), contacts: _repo.legalContacts(widget.student.id), communications: _repo.communications(widget.student.id), documents: _repo.documentVersions(widget.student.id), evaluations: _repo.evaluations(widget.student.id), protocols: _repo.protocols(widget.student.id), absences: _repo.absences(widget.student.id), groups: _repo.groupInterventions(widget.student.id), identity: _repo.identity());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe PDF generado y guardado localmente.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo generar el informe: $error')));
    }
  }

  Future<String?> _certificatePassword() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Contraseña del certificado'), content: TextField(controller: controller, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña del archivo .p12/.pfx')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Continuar'))]));
    controller.dispose();
    return password;
  }

  Future<void> _signCaseReport() async {
    final selected = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['p12', 'pfx'], withData: true);
    if (selected == null || selected.files.isEmpty) return;
    final file = selected.files.single;
    final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) return;
    final password = await _certificatePassword();
    if (password == null || password.isEmpty) return;
    try {
      final info = await _pades.inspectCertificate(p12Bytes: bytes, password: password);
      if (!info.vigente || !info.keyUsageOk || info.revocado) throw StateError(info.validationError ?? 'El certificado no está vigente, no permite firma digital/no repudio o está revocado.');
      if (!mounted) return;
      final subject = info.subjectCn ?? 'Titular no identificado';
      final issuer = info.issuerCn ?? 'Emisor no identificado';
      final proceed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Confirmar firma PAdES'), content: Text('Firmante: $subject\nEmisor: $issuer\nVálido hasta: ${info.notAfter?.toLocal() ?? 'desconocido'}\n\nSe generará un documento FINAL firmado. La contraseña no se guardará.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Firmar documento'))])) ?? false;
      if (!proceed) return;
      final identity = _repo.identity();
      final pdf = await _reports.buildStudentCasePdf(student: widget.student, timeline: _repo.caseTimeline(widget.student.id), contacts: _repo.legalContacts(widget.student.id), communications: _repo.communications(widget.student.id), documents: _repo.documentVersions(widget.student.id), evaluations: _repo.evaluations(widget.student.id), protocols: _repo.protocols(widget.student.id), absences: _repo.absences(widget.student.id), groups: _repo.groupInterventions(widget.student.id), identity: identity);
      final signed = await _pades.signPdf(pdfBytes: pdf, p12Bytes: bytes, password: password, signerName: subject, reason: 'Informe de seguimiento del caso', location: identity.centerName);
      final output = await FilePicker.saveFile(fileName: 'informe_caso_${widget.student.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_').toLowerCase()}_firmado.pdf', bytes: signed);
      final profileId = sha256.convert(bytes).toString().substring(0, 32);
      _repo.saveSigningProfile(SigningProfile(id: profileId, label: subject, subject: subject, issuer: issuer, serialNumber: info.serialNumber ?? '', notBefore: info.notBefore ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), notAfter: info.notAfter ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), certificatePath: file.path ?? ''));
      _repo.addSignedDocumentVersion(studentId: widget.student.id, type: 'Informe de seguimiento', title: 'Informe completo del caso', version: 1, path: output?.toString() ?? '', profileId: profileId, subject: subject, sha256: sha256.convert(signed).toString());
      _repo.logAudit(eventType: 'document_signed', entityType: 'student', entityId: widget.student.id, details: 'PAdES-BES · SHA-256 ${sha256.convert(signed)}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF PAdES firmado y registrado como versión final.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo firmar el PDF: $error')));
    }
  }
  Future<Map<String, String>?> _form(BuildContext context, String title, List<(String, String)> fields) async {
    final controllers = {for (final field in fields) field.$1: TextEditingController()};
    final result = await showDialog<Map<String, String>>(context: context, builder: (context) => AlertDialog(title: Text(title), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields.map((field) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controllers[field.$1], maxLines: field.$1 == 'notes' || field.$1 == 'description' || field.$1 == 'summary' || field.$1 == 'observation' ? 3 : 1, decoration: InputDecoration(labelText: field.$2)))).toList())), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, {for (final entry in controllers.entries) entry.key: entry.value.text.trim()}), child: const Text('Guardar'))]));
    for (final controller in controllers.values) { controller.dispose(); }
    return result;
  }

  Future<void> _addTimeline() async {
    final data = await _form(context, 'Nueva actuación en el historial', [('title', 'Título'), ('type', 'Tipo: derivación, entrevista, evaluación…'), ('description', 'Descripción')]);
    if (data == null || data['title']!.isEmpty) return;
    _repo.addCaseEvent(studentId: widget.student.id, type: data['type']!, title: data['title']!, description: data['description']!); setState(() {});
  }

  Future<void> _addContact() async {
    final data = await _form(context, 'Nuevo tutor o contacto legal', [('name', 'Nombre'), ('relationship', 'Relación'), ('phone', 'Teléfono'), ('email', 'Correo electrónico'), ('legalRole', 'Rol legal/custodia'), ('notes', 'Notas')]);
    if (data == null || data['name']!.isEmpty) return;
    _repo.addLegalContact(studentId: widget.student.id, name: data['name']!, relationship: data['relationship']!, phone: data['phone']!, email: data['email']!, legalRole: data['legalRole']!, notes: data['notes']!); setState(() {});
  }

  Future<void> _addCommunication() async {
    final data = await _form(context, 'Registrar comunicación', [('channel', 'Canal: llamada, correo, reunión…'), ('recipient', 'Destinatario'), ('summary', 'Resumen'), ('agreements', 'Acuerdos y próxima acción'), ('status', 'Estado: pendiente, recibida, sin respuesta')]);
    if (data == null || data['summary']!.isEmpty) return;
    _repo.addCommunication(studentId: widget.student.id, channel: data['channel']!, recipient: data['recipient']!, summary: data['summary']!, agreements: data['agreements']!, status: data['status']!.isEmpty ? 'pendiente' : data['status']!); setState(() {});
  }

  Future<void> _addDocument() async {
    final file = await FilePicker.pickFiles(type: FileType.any);
    final data = await _form(context, 'Nueva versión documental', [('type', 'Tipo: informe, dictamen, ACIS, PTI…'), ('title', 'Título')]);
    if (data == null || data['title']!.isEmpty) return;
    _repo.createDocumentVersion(studentId: widget.student.id, type: data['type']!, title: data['title']!, path: file?.files.single.path ?? ''); setState(() {});
  }

  Future<void> _advanceDocument(Map<String, Object?> row) async {
    final status = row['status'] as String? ?? 'draft';
    final next = <String, String>{'draft': 'in_review', 'in_review': 'validated', 'validated': 'final', 'final': 'signed', 'signed': 'archived'}[status];
    if (next == null) return;
    try {
      _repo.transitionDocumentStatus(id: row['id'] as String, status: next, reviewedBy: 'Orientador local');
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se puede avanzar la versión: $error')));
    }
  }

  Future<void> _addEvaluation() async {
    final data = await _form(context, 'Registrar evaluación', [('instrument', 'Instrumento o prueba'), ('area', 'Área evaluada'), ('directScore', 'Puntuación directa'), ('scaledScore', 'Puntuación escalar'), ('percentile', 'Percentil'), ('notes', 'Interpretación/observaciones')]);
    if (data == null || data['instrument']!.isEmpty) return;
    _repo.addEvaluation(studentId: widget.student.id, instrument: data['instrument']!, area: data['area']!, directScore: data['directScore']!, scaledScore: data['scaledScore']!, percentile: data['percentile']!, notes: data['notes']!); setState(() {});
  }

  Future<void> _addProtocol() async {
    final data = await _form(context, 'Activar protocolo', [('type', 'Protocolo: acoso, absentismo, protección…'), ('phase', 'Fase'), ('status', 'Estado: activo, pausado, cerrado'), ('notes', 'Actuaciones y notas')]);
    if (data == null || data['type']!.isEmpty) return;
    _repo.addProtocol(studentId: widget.student.id, type: data['type']!, phase: data['phase']!.isEmpty ? 'Detección' : data['phase']!, status: data['status']!.isEmpty ? 'activo' : data['status']!, notes: data['notes']!); setState(() {});
  }

  Future<void> _addAbsence() async {
    final data = await _form(context, 'Registrar falta', [('classification', 'Clasificación: justificada, injustificada, parcial'), ('minutes', 'Minutos'), ('notes', 'Notas')]);
    if (data == null) return;
    _repo.addAbsence(studentId: widget.student.id, classification: data['classification']!.isEmpty ? 'injustificada' : data['classification']!, minutes: int.tryParse(data['minutes']!) ?? 0, notes: data['notes']!); setState(() {});
  }

  Future<void> _addGroup() async {
    final data = await _form(context, 'Registrar sesión grupal', [('program', 'Programa'), ('attendance', 'Asistencia: presente, ausente'), ('observation', 'Observación del alumno'), ('material', 'Material asociado')]);
    if (data == null || data['program']!.isEmpty) return;
    _repo.addGroupIntervention(studentId: widget.student.id, program: data['program']!, attendance: data['attendance']!.isEmpty ? 'presente' : data['attendance']!, observation: data['observation']!, material: data['material']!); setState(() {});
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(length: 8, child: Scaffold(appBar: AppBar(title: Text(widget.student.name), actions: [IconButton(onPressed: _exportCaseReport, icon: const Icon(Icons.picture_as_pdf), tooltip: 'Generar informe completo PDF'), IconButton(onPressed: _signCaseReport, icon: const Icon(Icons.draw_outlined), tooltip: 'Firmar PDF con certificado PAdES')], bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Línea de tiempo'), Tab(text: 'Contactos'), Tab(text: 'Comunicaciones'), Tab(text: 'Documentos'), Tab(text: 'Evaluación'), Tab(text: 'Protocolos'), Tab(text: 'Absentismo'), Tab(text: 'Grupos')])), body: TabBarView(children: [_timeline(), _contacts(), _communications(), _documents(), _evaluations(), _protocols(), _absences(), _groups()])));

  Widget _panel(String title, IconData icon, List<Map<String, Object?>> items, VoidCallback onAdd, Widget Function(Map<String, Object?>) item) => ListView(padding: const EdgeInsets.all(18), children: [Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))), FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Añadir'))]), const SizedBox(height: 12), if (items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Todavía no hay registros.'))) else ...items.map(item)]);

  Widget _timeline() => _panel('Historial completo del caso', Icons.timeline, _repo.caseTimeline(widget.student.id), _addTimeline, (row) => Card(child: ListTile(leading: const Icon(Icons.event_note), title: Text('${row['title']}'), subtitle: Text('${row['event_type']} · ${row['event_date']}\n${row['description']}'))));
  Widget _contacts() => _panel('Tutores legales y contactos', Icons.family_restroom, _repo.legalContacts(widget.student.id), _addContact, (row) => Card(child: ListTile(leading: const Icon(Icons.person), title: Text('${row['name']} · ${row['relationship']}'), subtitle: Text('${row['phone']}  ${row['email']}\nRol: ${row['legal_role']}\n${row['notes']}'))));
  Widget _communications() => _panel('Comunicaciones y seguimiento', Icons.forum_outlined, _repo.communications(widget.student.id), _addCommunication, (row) => Card(child: ListTile(leading: const Icon(Icons.contact_phone), title: Text('${row['channel']} · ${row['recipient']}'), subtitle: Text('${row['communication_date']} · Estado: ${row['status']}\n${row['summary']}\nAcuerdos: ${row['agreements']}'))));
  Widget _documents() => _panel('Versiones de documentos', Icons.folder_copy_outlined, _repo.documentVersions(widget.student.id), _addDocument, (row) => Card(child: ListTile(onTap: () => _advanceDocument(row), leading: const Icon(Icons.description), title: Text('${row['title']} · v${row['version']}'), subtitle: Text('${row['document_type']} · ${row['status']}\n${row['file_path']}'), trailing: const Icon(Icons.arrow_forward_ios, size: 16))));
  Widget _evaluations() => _panel('Evaluación psicopedagógica', Icons.analytics_outlined, _repo.evaluations(widget.student.id), _addEvaluation, (row) => Card(child: ListTile(leading: const Icon(Icons.assessment), title: Text('${row['instrument']} · ${row['area']}'), subtitle: Text('Directa: ${row['direct_score']} · Escalar: ${row['scaled_score']} · Percentil: ${row['percentile']}\n${row['notes']}'))));
  Widget _protocols() => _panel('Protocolos y actuaciones', Icons.shield_outlined, _repo.protocols(widget.student.id), _addProtocol, (row) => Card(child: ListTile(leading: const Icon(Icons.policy), title: Text('${row['protocol_type']} · ${row['phase']}'), subtitle: Text('Estado: ${row['status']}\n${row['notes']}'))));
  Widget _absences() => _panel('Absentismo', Icons.event_busy, _repo.absences(widget.student.id), _addAbsence, (row) => Card(child: ListTile(leading: const Icon(Icons.warning_amber), title: Text('${row['absence_date']} · ${row['classification']}'), subtitle: Text('${row['minutes']} minutos\n${row['notes']}'))));
  Widget _groups() => _panel('Intervención grupal', Icons.groups_2_outlined, _repo.groupInterventions(widget.student.id), _addGroup, (row) => Card(child: ListTile(leading: const Icon(Icons.groups), title: Text('${row['program']} · ${row['attendance']}'), subtitle: Text('${row['session_date']}\n${row['observation']}\nMaterial: ${row['material']}'))));
}
