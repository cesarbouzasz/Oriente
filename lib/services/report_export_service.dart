import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/orientation_models.dart';
import '../models/signing_models.dart';

class ReportExportService {
  Future<Uri?> exportStudentPdf(Student student) async {
    final document = pw.Document();
    document.addPage(pw.Page(build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Ficha de alumno', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 16),
      pw.Text('Nombre: ${student.name}'),
      pw.Text('Curso/grupo: ${student.course.isEmpty ? student.groupId : student.course}'),
      pw.Text('Fecha de nacimiento: ${student.birthDate}'),
      pw.SizedBox(height: 12),
      pw.Text('Observaciones: ${student.notes}'),
    ])));
    return _save('ficha_${_safe(student.name)}.pdf', await document.save());
  }

  Future<Uri?> exportStudentCasePdf({required Student student, required List<Map<String, Object?>> timeline, required List<Map<String, Object?>> contacts, required List<Map<String, Object?>> communications, required List<Map<String, Object?>> documents, required List<Map<String, Object?>> evaluations, required List<Map<String, Object?>> protocols, required List<Map<String, Object?>> absences, required List<Map<String, Object?>> groups, InstitutionalIdentity? identity}) async => _save('informe_caso_${_safe(student.name)}.pdf', await buildStudentCasePdf(student: student, timeline: timeline, contacts: contacts, communications: communications, documents: documents, evaluations: evaluations, protocols: protocols, absences: absences, groups: groups, identity: identity));

  Future<Uint8List> buildStudentCasePdf({required Student student, required List<Map<String, Object?>> timeline, required List<Map<String, Object?>> contacts, required List<Map<String, Object?>> communications, required List<Map<String, Object?>> documents, required List<Map<String, Object?>> evaluations, required List<Map<String, Object?>> protocols, required List<Map<String, Object?>> absences, required List<Map<String, Object?>> groups, InstitutionalIdentity? identity}) async {
    final document = pw.Document();
    final logo = await _loadImage(identity?.logoPath);
    final signature = await _loadImage(identity?.signaturePath);
    final seal = await _loadImage(identity?.sealPath);
    document.addPage(pw.MultiPage(margin: const pw.EdgeInsets.all(32), header: (context) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 12), child: pw.Text('Informe de seguimiento del caso', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))), footer: (context) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Página ${context.pageNumber}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))), build: (_) => [
      if (logo != null) pw.Image(logo, height: 45),
      if (identity != null && identity.centerName.isNotEmpty) pw.Text('${identity.centerName}${identity.centerCode.isEmpty ? '' : ' · ${identity.centerCode}'}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      if (identity != null && identity.address.isNotEmpty) pw.Text(identity.address, style: const pw.TextStyle(fontSize: 9)),
      pw.Text('Informe completo del caso', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text('Generado: ${DateTime.now().toLocal().toIso8601String()}'),
      pw.SizedBox(height: 16),
      pw.Text('Identificación del alumno', style: _heading),
      pw.Text('Nombre: ${student.name}'),
      pw.Text('Curso/grupo: ${student.course.isEmpty ? student.groupId : student.course}'),
      if (student.birthDate.isNotEmpty) pw.Text('Fecha de nacimiento: ${student.birthDate}'),
      if (student.notes.isNotEmpty) pw.Text('Observaciones: ${student.notes}'),
      ..._caseSection('Línea de tiempo e historial', timeline, (row) => '${row['event_date']} · ${row['event_type']}\n${row['title']}\n${row['description']}'),
      ..._caseSection('Tutores legales y contactos', contacts, (row) => '${row['name']} · ${row['relationship']}\nTel: ${row['phone']} · Email: ${row['email']}\nRol legal: ${row['legal_role']}\n${row['notes']}'),
      ..._caseSection('Comunicaciones y seguimiento', communications, (row) => '${row['communication_date']} · ${row['channel']} · ${row['recipient']}\nEstado: ${row['status']}\n${row['summary']}\nAcuerdos: ${row['agreements']}'),
      ..._caseSection('Versiones de documentos', documents, (row) => '${row['title']} · v${row['version']} · ${row['status']}\nTipo: ${row['document_type']}\nArchivo local: ${row['file_path']}'),
      ..._caseSection('Evaluación psicopedagógica', evaluations, (row) => '${row['instrument']} · ${row['area']}\nDirecta: ${row['direct_score']} · Escalar: ${row['scaled_score']} · Percentil: ${row['percentile']}\n${row['notes']}'),
      ..._caseSection('Protocolos y actuaciones', protocols, (row) => '${row['protocol_type']} · Fase: ${row['phase']} · Estado: ${row['status']}\n${row['notes']}'),
      ..._caseSection('Absentismo', absences, (row) => '${row['absence_date']} · ${row['classification']} · ${row['minutes']} minutos\n${row['notes']}'),
      ..._caseSection('Intervención grupal', groups, (row) => '${row['session_date']} · ${row['program']} · ${row['attendance']}\n${row['observation']}\nMaterial: ${row['material']}'),
      pw.SizedBox(height: 18),
      pw.SizedBox(height: 12),
      if (signature != null || seal != null || (identity?.signerName.isNotEmpty ?? false)) pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [if (signature != null) pw.Image(signature, width: 110, height: 45), if (seal != null) pw.Padding(padding: const pw.EdgeInsets.only(left: 18), child: pw.Image(seal, width: 65, height: 65)), if (identity != null && identity.signerName.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(left: 18), child: pw.Text('${identity.signerName}\n${identity.signerRole}'))]),
      pw.SizedBox(height: 18),
      pw.Text('Documento generado localmente. Contiene datos personales y psicopedagógicos sensibles; debe conservarse en una ubicación protegida.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ]));
    return document.save();
  }

  static final _heading = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800);

  List<pw.Widget> _caseSection(String title, List<Map<String, Object?>> rows, String Function(Map<String, Object?>) text) => [
    pw.SizedBox(height: 18),
    pw.Text(title, style: _heading),
    pw.SizedBox(height: 6),
    if (rows.isEmpty) pw.Text('Sin registros.', style: const pw.TextStyle(color: PdfColors.grey600)) else ...rows.map((row) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 8), padding: const pw.EdgeInsets.all(7), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(3)), child: pw.Text(text(row)))),
  ];

  Future<pw.MemoryImage?> _loadImage(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return pw.MemoryImage(await file.readAsBytes());
  }

  Future<Uri?> exportStudentMarkdown(Student student) => _saveText('ficha_${_safe(student.name)}.md', '''# Ficha de alumno

- **Nombre:** ${student.name}
- **Curso/grupo:** ${student.course.isEmpty ? student.groupId : student.course}
- **Fecha de nacimiento:** ${student.birthDate}

## Observaciones

${student.notes}
''');

  Future<Uri?> exportProfessionalMarkdown(Professional professional) => _saveText('profesional_${_safe(professional.name)}.md', '''# Ficha de profesional

- **Nombre:** ${professional.name}
- **Rol:** ${professional.role}
- **Centro:** ${professional.centerId}

## Notas

${professional.notes}
''');

  Future<Uri?> exportProfessionalPdf(Professional professional) async {
    final document = pw.Document();
    document.addPage(pw.Page(build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Ficha de profesional', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 16),
      pw.Text('Nombre: ${professional.name}'),
      pw.Text('Rol: ${professional.role}'),
      pw.Text('Centro: ${professional.centerId}'),
      pw.SizedBox(height: 12),
      pw.Text('Notas: ${professional.notes}'),
    ])));
    return _save('profesional_${_safe(professional.name)}.pdf', await document.save());
  }

  Future<Uri?> _saveText(String name, String content) => _save(name, Uint8List.fromList(utf8.encode(content)));
  Future<Uri?> _save(String name, Uint8List bytes) => FilePicker.saveFile(fileName: name, bytes: bytes);
  String _safe(String value) => value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ_-]+'), '_').toLowerCase();
}
