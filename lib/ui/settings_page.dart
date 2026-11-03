import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';

import '../db/encrypted_database.dart';
import '../db/orientation_repository.dart';
import '../core/app_languages.dart';
import '../models/orientation_models.dart';
import '../models/signing_models.dart';
import '../services/backup_service.dart';
import '../services/educational_template_catalog.dart';
import '../services/file_selection_service.dart';
import '../services/pin_unlock_service.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.database, required this.databasePath, this.initialPreferences, this.onSaved, super.key});
  final EncryptedDatabase database;
  final String databasePath;
  final AppPreferences? initialPreferences;
  final ValueChanged<AppPreferences>? onSaved;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _backup = BackupService();
  final _files = FileSelectionService();
  final _pinService = PinUnlockService();
  late final _repository = OrientationRepository(widget.database);
  double _fontScale = 1;
  Color _seedColor = const Color(0xff087e8b);
  String? _message;
  String _navigation = 'grid';
  String _calendar = 'week';
  String _notes = 'paper';
  String _community = EducationalTemplateCatalog.communities.first;
  String _templateCategory = 'Todos';
  bool _showTemplateWarning = true;
  AppLanguage _language = AppLanguage.spanish;
  bool _lockEnabled = true;
  int _lockMinutes = 10;
  bool _lockOnBackground = true;
  final _centerName = TextEditingController();
  final _centerCode = TextEditingController();
  final _address = TextEditingController();
  final _signerName = TextEditingController();
  final _signerRole = TextEditingController();
  final _logoPath = TextEditingController();
  final _sealPath = TextEditingController();
  final _signaturePath = TextEditingController();

  @override
  void initState() {
    super.initState();
    final preferences = widget.initialPreferences ?? _repository.preferences();
    _navigation = preferences.navigation;
    _calendar = preferences.calendar;
    _notes = preferences.notes;
    _seedColor = Color(preferences.seedColor);
    _fontScale = preferences.fontScale;
    _community = preferences.community;
    _language = AppLanguages.fromCode(preferences.language);
    _lockEnabled = preferences.lockEnabled;
    _lockMinutes = preferences.lockMinutes;
    _lockOnBackground = preferences.lockOnBackground;
    final identity = _repository.identity();
    _centerName.text = identity.centerName;
    _centerCode.text = identity.centerCode;
    _address.text = identity.address;
    _signerName.text = identity.signerName;
    _signerRole.text = identity.signerRole;
    _logoPath.text = identity.logoPath;
    _sealPath.text = identity.sealPath;
    _signaturePath.text = identity.signaturePath;
  }

  @override
  void dispose() {
    for (final controller in [_centerName, _centerCode, _address, _signerName, _signerRole, _logoPath, _sealPath, _signaturePath]) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _makeBackup() async {
    try {
      final directory = await _backup.chooseBackupDirectory();
      if (directory == null) return;
      final backup = await _backup.createBackup(databasePath: widget.databasePath, destinationDirectory: directory);
      final bytes = await backup.readAsBytes();
      _repository.recordBackup(path: backup.path, sha256: sha256.convert(bytes).toString(), sizeBytes: bytes.length);
      _repository.logAudit(eventType: 'backup_created', entityType: 'database', details: backup.path);
      if (mounted) setState(() => _message = 'Copia cifrada verificada y registrada.');
    } catch (error) {
      if (mounted) setState(() => _message = 'No se pudo crear el backup: $error');
    }
  }

  Future<void> _restore() async {
    final backup = await _files.chooseBackupFile();
    if (backup == null || !mounted) return;
    final pinController = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Restaurar copia'), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Introduce el PIN local para autorizar la restauración.'), const SizedBox(height: 12), TextField(controller: pinController, obscureText: true, keyboardType: TextInputType.number, maxLength: 5, decoration: const InputDecoration(labelText: 'PIN de 5 dígitos'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurar'))])) ?? false;
    if (!confirmed || await _pinService.unlock(pinController.text) == null) {
      if (mounted) setState(() => _message = 'Restauración cancelada: PIN incorrecto o no configurado.');
      return;
    }
    try {
      await widget.database.close();
      await _backup.restoreBackup(backupPath: backup, databasePath: widget.databasePath);
      if (mounted) {
        await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Copia restaurada'), content: const Text('La base cifrada ha sido restaurada y verificada. Debes volver a iniciar sesión para abrirla de forma segura.'), actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Continuar'))]));
        if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
      }
    } catch (error) {
      if (mounted) {
        await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Restauración no completada'), content: Text('La conexión se ha cerrado por seguridad. $error'), actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Volver al acceso'))]));
        if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
      }
    }
  }

  void _saveConfiguration() {
    final preferences = AppPreferences(navigation: _navigation, calendar: _calendar, notes: _notes, seedColor: _seedColor.value, fontScale: _fontScale, community: _community, language: _language.name, lockEnabled: _lockEnabled, lockMinutes: _lockMinutes, lockOnBackground: _lockOnBackground);
    _repository.savePreferences(preferences);
    _repository.saveIdentity(InstitutionalIdentity(centerName: _centerName.text.trim(), centerCode: _centerCode.text.trim(), address: _address.text.trim(), signerName: _signerName.text.trim(), signerRole: _signerRole.text.trim(), logoPath: _logoPath.text.trim(), sealPath: _sealPath.text.trim(), signaturePath: _signaturePath.text.trim()));
    widget.onSaved?.call(preferences);
    setState(() => _message = 'Configuración guardada en la base SQLCipher.');
  }

  Future<void> _pickIdentityFile(TextEditingController target, List<String> extensions) async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: extensions);
    if (result != null && result.isNotEmpty && result.single.path != null) setState(() => target.text = result.single.path!);
  }

  Future<void> _registerTemplate(EducationalTemplate template) async {
    final file = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['docx', 'odt', 'xlsx']);
    if (file == null || file.isEmpty) return;
    final selected = file.single;
    if (selected.path == null) {
      setState(() => _message = 'No se pudo registrar la plantilla: el selector no proporcionó una ruta local.');
      return;
    }
    _repository.registerOfficialTemplate(community: template.community, category: template.category, title: template.title, path: selected.path!, extension: selected.name.split('.').last.toLowerCase());
    if (mounted) setState(() => _message = 'Plantilla local registrada para ${template.community}.');
  }

  @override
  Widget build(BuildContext context) { final strings = AppStrings(_language); return ListView(padding: const EdgeInsets.all(24), children: [
    Text(strings.get('design'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    Text(strings.get('designSubtitle'), style: Theme.of(context).textTheme.bodyLarge),
    const SizedBox(height: 24),
    _SectionCard(title: strings.get('language'), subtitle: 'Español · Galego · English · Português · Français · Italiano · Deutsch · 中文', child: DropdownButtonFormField<AppLanguage>(value: _language, decoration: InputDecoration(labelText: strings.get('language')), items: AppLanguages.options.map((item) => DropdownMenuItem(value: item.language, child: Row(children: [LanguageFlag(language: item.language), const SizedBox(width: 10), Text('${item.nativeName} — ${item.name}')]))) .toList(), onChanged: (value) { if (value != null) setState(() => _language = value); })),
    const SizedBox(height: 18),
    _SectionCard(title: strings.get('navigation'), subtitle: 'Elige cómo quieres acceder a las funciones de Cercano Oriente', child: _ChoiceGrid<String>(selected: _navigation, values: const ['grid', 'tabs', 'drawer'], labels: const ['Botones grandes', 'Menú de pestañas', 'Menú desplegable'], previews: const [_GridPreview(), _TabsPreview(), _DrawerPreview()], onChanged: (value) => setState(() => _navigation = value))),
    const SizedBox(height: 18),
    _SectionCard(title: strings.get('calendar'), subtitle: 'Selecciona la vista más cómoda para tu agenda', child: _ChoiceGrid<String>(small: true, selected: _calendar, values: const ['month', 'week', 'agenda'], labels: const ['Mes completo', 'Vista semanal', 'Agenda / lista'], previews: const [_MonthPreview(), _WeekPreview(), _AgendaPreview()], onChanged: (value) => setState(() => _calendar = value))),
    const SizedBox(height: 18),
    _SectionCard(title: strings.get('notes'), subtitle: 'Elige cómo se mostrarán tus recordatorios privados', child: _ChoiceGrid<String>(small: true, selected: _notes, values: const ['paper', 'minimal', 'cork'], labels: const ['Papel clásico', 'Moderno minimalista', 'Corcho retro'], previews: const [_PaperPreview(), _MinimalPreview(), _CorkPreview()], onChanged: (value) => setState(() => _notes = value))),
    const SizedBox(height: 18),
    _SectionCard(title: 'Identidad institucional y firma visual', subtitle: 'Se incorpora al PDF. No sustituye una firma criptográfica PAdES.', child: Column(children: [TextField(controller: _centerName, decoration: const InputDecoration(labelText: 'Nombre del centro')), TextField(controller: _centerCode, decoration: const InputDecoration(labelText: 'Código del centro')), TextField(controller: _address, decoration: const InputDecoration(labelText: 'Dirección')), TextField(controller: _signerName, decoration: const InputDecoration(labelText: 'Nombre del orientador')), TextField(controller: _signerRole, decoration: const InputDecoration(labelText: 'Cargo')), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton.icon(onPressed: () => _pickIdentityFile(_logoPath, ['png', 'jpg', 'jpeg']), icon: const Icon(Icons.image_outlined), label: const Text('Seleccionar logo')), OutlinedButton.icon(onPressed: () => _pickIdentityFile(_sealPath, ['png', 'jpg', 'jpeg']), icon: const Icon(Icons.verified_outlined), label: const Text('Seleccionar sello')), OutlinedButton.icon(onPressed: () => _pickIdentityFile(_signaturePath, ['png', 'jpg', 'jpeg']), icon: const Icon(Icons.draw_outlined), label: const Text('Seleccionar firma'))]), if (_logoPath.text.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text('Logo: ${_logoPath.text}', maxLines: 1, overflow: TextOverflow.ellipsis)), if (_sealPath.text.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text('Sello: ${_sealPath.text}', maxLines: 1, overflow: TextOverflow.ellipsis)), if (_signaturePath.text.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text('Firma: ${_signaturePath.text}', maxLines: 1, overflow: TextOverflow.ellipsis))])),
    const SizedBox(height: 18),
    _TemplateSection(community: _community, category: _templateCategory, showWarning: _showTemplateWarning, onCommunity: (value) => setState(() => _community = value), onCategory: (value) => setState(() => _templateCategory = value), onWarning: (value) => setState(() => _showTemplateWarning = value), onUse: _registerTemplate),
    const SizedBox(height: 18),
    _SectionCard(title: 'Combinaciones e Integración', subtitle: 'Comprueba el resultado antes de guardarlo', child: Wrap(spacing: 12, runSpacing: 12, children: [OutlinedButton.icon(onPressed: _preview, icon: const Icon(Icons.visibility_outlined), label: Text(strings.get('preview'))), FilledButton.icon(onPressed: _saveConfiguration, icon: const Icon(Icons.check), label: Text(strings.get('save')))])),
    const SizedBox(height: 18),
    _SectionCard(title: 'Accesibilidad y seguridad', subtitle: 'Ajustes locales de la interfaz y protección de sesión', child: Column(children: [DropdownButtonFormField<Color>(value: _seedColor, decoration: const InputDecoration(labelText: 'Color de acento'), items: const [DropdownMenuItem(value: Color(0xff087e8b), child: Text('Turquesa')), DropdownMenuItem(value: Color(0xff6a4c93), child: Text('Violeta')), DropdownMenuItem(value: Color(0xff2d6a4f), child: Text('Verde'))], onChanged: (value) { if (value != null) setState(() => _seedColor = value); }), Row(children: [const Text('Tamaño del texto'), Expanded(child: Slider(value: _fontScale, min: .85, max: 1.25, divisions: 4, label: '${(_fontScale * 100).round()}%', onChanged: (value) => setState(() => _fontScale = value)))]), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Bloqueo automático por inactividad'), subtitle: const Text('Cierra la sesión y la base cifrada al agotarse el tiempo'), value: _lockEnabled, onChanged: (value) => setState(() => _lockEnabled = value)), if (_lockEnabled) DropdownButtonFormField<int>(value: _lockMinutes, decoration: const InputDecoration(labelText: 'Tiempo sin actividad'), items: const [DropdownMenuItem(value: 1, child: Text('1 minuto')), DropdownMenuItem(value: 5, child: Text('5 minutos')), DropdownMenuItem(value: 10, child: Text('10 minutos')), DropdownMenuItem(value: 15, child: Text('15 minutos')), DropdownMenuItem(value: 30, child: Text('30 minutos')), DropdownMenuItem(value: 60, child: Text('1 hora'))], onChanged: (value) { if (value != null) setState(() => _lockMinutes = value); }), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Bloquear al cambiar de ventana'), subtitle: const Text('También bloquea al minimizar o dejar la aplicación en segundo plano'), value: _lockOnBackground, onChanged: _lockEnabled ? (value) => setState(() => _lockOnBackground = value) : null)])),
    const SizedBox(height: 18),
    _SectionCard(title: 'Base de datos y copias de seguridad', subtitle: 'La base permanece cifrada y local', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.lock), title: const Text('Base SQLCipher'), subtitle: Text(widget.databasePath, maxLines: 2, overflow: TextOverflow.ellipsis)), Wrap(spacing: 8, runSpacing: 8, children: [FilledButton.icon(onPressed: _makeBackup, icon: const Icon(Icons.backup), label: const Text('Crear backup')), OutlinedButton.icon(onPressed: _restore, icon: const Icon(Icons.restore), label: const Text('Restaurar backup'))])])),
    if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
  ]); }

  Future<void> _preview() => showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Vista Previa de la Combinación'), content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [_GridPreview(), const SizedBox(height: 12), _WeekPreview(), const SizedBox(height: 12), _PaperPreview()])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]));
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});
  final String title; final String subtitle; final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 18), child])));
}

class _ChoiceGrid<T> extends StatelessWidget {
  const _ChoiceGrid({required this.selected, required this.values, required this.labels, required this.previews, required this.onChanged, this.small = false});
  final T selected; final List<T> values; final List<String> labels; final List<Widget> previews; final ValueChanged<T> onChanged; final bool small;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final width = ((constraints.maxWidth - 24) / 3).clamp(150.0, 360.0).toDouble();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(values.length, (index) => SizedBox(
        width: width,
        child: InkWell(
          onTap: () => onChanged(values[index]),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected == values[index] ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected == values[index] ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant, width: selected == values[index] ? 2 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: small ? 105 : 145, width: double.infinity, child: previews[index]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: Text(labels[index], style: const TextStyle(fontWeight: FontWeight.w700))), if (selected == values[index]) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)]),
            ]),
          ),
        ),
      )),
    );
  });
}

class _GridPreview extends StatelessWidget { const _GridPreview(); @override Widget build(BuildContext context) => _PreviewFrame(child: GridView.count(crossAxisCount: 2, padding: const EdgeInsets.all(12), crossAxisSpacing: 8, mainAxisSpacing: 8, children: List.generate(4, (i) => Card(child: Icon([Icons.people, Icons.event, Icons.description, Icons.settings][i]))))); }
class _TabsPreview extends StatelessWidget { const _TabsPreview(); @override Widget build(BuildContext context) => _PreviewFrame(child: Column(children: [Expanded(child: Center(child: Icon(Icons.dashboard, size: 36, color: Theme.of(context).colorScheme.primary))), const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Icon(Icons.home), Icon(Icons.calendar_month), Icon(Icons.settings)])])); }
class _DrawerPreview extends StatelessWidget { const _DrawerPreview(); @override Widget build(BuildContext context) => _PreviewFrame(child: Row(children: [Container(width: 72, color: Theme.of(context).colorScheme.primaryContainer, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.menu), SizedBox(height: 18), Icon(Icons.people), SizedBox(height: 18), Icon(Icons.event)])), const Expanded(child: Center(child: Icon(Icons.dashboard, size: 40)))])); }
class _MonthPreview extends StatelessWidget { const _MonthPreview(); @override Widget build(BuildContext context) => _PreviewFrame(child: GridView.count(crossAxisCount: 7, padding: const EdgeInsets.all(8), children: List.generate(35, (i) => Center(child: Text('${i % 30 + 1}', style: const TextStyle(fontSize: 10)))))); }
class _WeekPreview extends StatelessWidget { const _WeekPreview(); @override Widget build(BuildContext context) => _PreviewFrame(child: Row(children: List.generate(5, (i) => Expanded(child: Column(children: [const Text('L'), const Divider(), Expanded(child: Container(margin: const EdgeInsets.all(3), color: Colors.transparent, child: Icon(Icons.event, size: 12, color: i == 2 ? Colors.teal : Colors.grey)))]))))); }
class _AgendaPreview extends StatelessWidget { const _AgendaPreview(); @override Widget build(BuildContext context) => _PreviewFrame(child: ListView(children: const [ListTile(leading: Icon(Icons.circle, size: 10), title: Text('09:00  Reunión'), dense: true), ListTile(leading: Icon(Icons.circle, size: 10), title: Text('11:30  Seguimiento'), dense: true), ListTile(leading: Icon(Icons.circle, size: 10), title: Text('16:00  Informe'), dense: true)])); }
class _PaperPreview extends StatelessWidget { const _PaperPreview(); @override Widget build(BuildContext context) => _PreviewFrame(color: const Color(0xfffff3b0), child: const Center(child: Text('Recordatorio', style: TextStyle(fontWeight: FontWeight.bold)))); }
class _MinimalPreview extends StatelessWidget { const _MinimalPreview(); @override Widget build(BuildContext context) => _PreviewFrame(color: const Color(0xffcaffbf), sharp: true, child: const Center(child: Text('Nota limpia'))); }
class _CorkPreview extends StatelessWidget { const _CorkPreview(); @override Widget build(BuildContext context) => _PreviewFrame(color: const Color(0xffb8794b), child: Stack(alignment: Alignment.topCenter, children: [const Icon(Icons.push_pin, color: Colors.red), Center(child: Container(color: const Color(0xffffd6a5), padding: const EdgeInsets.all(8), child: const Text('Idea')))])); }
class _PreviewFrame extends StatelessWidget { const _PreviewFrame({required this.child, this.color, this.sharp = false}); final Widget child; final Color? color; final bool sharp; @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(sharp ? 3 : 14)), clipBehavior: Clip.antiAlias, child: child); }

class _TemplateSection extends StatelessWidget {
  const _TemplateSection({required this.community, required this.category, required this.showWarning, required this.onCommunity, required this.onCategory, required this.onWarning, required this.onUse});
  final String community; final String category; final bool showWarning; final ValueChanged<String> onCommunity; final ValueChanged<String> onCategory; final ValueChanged<bool> onWarning;
  final ValueChanged<EducationalTemplate> onUse;
  @override
  Widget build(BuildContext context) { final all = EducationalTemplateCatalog.forCommunity(community); final templates = category == 'Todos' ? all : all.where((item) => item.category == category).toList(); return _SectionCard(title: 'Plantillas del sistema educativo español', subtitle: 'Selecciona la Comunidad Autónoma y registra el archivo oficial vigente del centro.', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Wrap(spacing: 12, runSpacing: 12, children: [SizedBox(width: 270, child: DropdownButtonFormField<String>(value: community, decoration: const InputDecoration(labelText: 'Comunidad Autónoma'), items: EducationalTemplateCatalog.communities.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) onCommunity(value); })), SizedBox(width: 190, child: DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Tipo de documento'), items: const [DropdownMenuItem(value: 'Todos', child: Text('Todos')), DropdownMenuItem(value: 'Informe', child: Text('Informes')), DropdownMenuItem(value: 'Dictamen', child: Text('Dictámenes')), DropdownMenuItem(value: 'Adaptación', child: Text('ACIS / adaptaciones')), DropdownMenuItem(value: 'Plan', child: Text('Planes'))], onChanged: (value) { if (value != null) onCategory(value); }))]), const SizedBox(height: 14), ...templates.map((template) => Card(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: ListTile(leading: const Icon(Icons.description_outlined), title: Text(template.title), subtitle: Text('${template.description}\n${template.validation}'), isThreeLine: true, trailing: OutlinedButton(onPressed: () => onUse(template), child: const Text('Registrar archivo'))))), SwitchListTile(contentPadding: EdgeInsets.zero, value: showWarning, onChanged: onWarning, title: const Text('Avisar antes de usar un modelo oficial'), subtitle: const Text('Los formatos autonómicos deben verificarse con la administración educativa vigente.'))])); }
}
