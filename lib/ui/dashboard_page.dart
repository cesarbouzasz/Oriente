import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';

import '../db/encrypted_database.dart';
import '../db/orientation_repository.dart';
import '../core/app_languages.dart';
import '../models/orientation_models.dart';
import '../services/ics_calendar_service.dart';
import '../services/local_reminder_service.dart';
import 'agenda_toolbar.dart';
import 'records_pages.dart';
import 'settings_page.dart';
import 'service_types_page.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.database, required this.databasePath, super.key});
  final EncryptedDatabase database;
  final String databasePath;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  int _selected = 0;
  late final OrientationRepository _preferencesRepository = OrientationRepository(widget.database);
  AppPreferences _preferences = const AppPreferences();
  AppLanguage _language = AppLanguage.spanish;
  Timer? _lockTimer;
  bool _locking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preferences = _preferencesRepository.preferences();
    _language = AppLanguages.fromCode(_preferences.language);
    _preferencesRepository.logAudit(eventType: 'dashboard_opened', entityType: 'session');
    _resetLockTimer();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.inactive) && _preferences.lockOnBackground && _preferences.lockEnabled) {
      _lock();
    } else if (state == AppLifecycleState.resumed) {
      _resetLockTimer();
    }
  }

  void _resetLockTimer() {
    if (!mounted || _locking || !_preferences.lockEnabled) {
      _lockTimer?.cancel();
      return;
    }
    _lockTimer?.cancel();
    _lockTimer = Timer(Duration(minutes: _preferences.lockMinutes), _lock);
  }

  Future<void> _lock() async {
    if (_locking || !mounted) return;
    _locking = true;
    _lockTimer?.cancel();
    _preferencesRepository.logAudit(eventType: 'session_locked', entityType: 'session', details: 'Bloqueo automático o cambio de aplicación');
    await widget.database.close();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  void _applyPreferences(AppPreferences value) { setState(() { _preferences = value; _language = AppLanguages.fromCode(value.language); }); _resetLockTimer(); }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OverviewPage(database: widget.database, initialCalendar: _preferences.calendar, notesStyle: _preferences.notes, onOpenCenters: () => setState(() => _selected = 3)),
      _SectionPage(title: 'Evaluación y Diagnóstico', icon: Icons.fact_check, items: const ['Pruebas psicopedagógicas', 'Informes', 'Dictámenes'], footer: FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ServiceTypesPage(database: widget.database))), icon: const Icon(Icons.tune), label: const Text('Configurar tipos de sesión'))),
      const _SectionPage(title: 'Coordinación', icon: Icons.groups, items: ['Tutorías', 'Familias', 'Servicios externos']),
      _CentersPage(database: widget.database),
      SettingsPage(database: widget.database, databasePath: widget.databasePath, initialPreferences: _preferences, onSaved: _applyPreferences),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      final content = AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: KeyedSubtree(key: ValueKey(_selected), child: pages[_selected]));
      final strings = AppStrings(_language);
      return Listener(onPointerDown: (_) => _resetLockTimer(), child: Scaffold(
        appBar: AppBar(title: Text(strings.get('app')), actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search), tooltip: strings.get('search'))]),
        drawer: _preferences.navigation == 'drawer' ? Drawer(child: SafeArea(child: ListView(children: [const DrawerHeader(child: Text('Navegación')), ..._drawerItems()]))) : null,
        body: _preferences.navigation == 'grid' ? _gridShell(content, desktop) : desktop ? Row(children: [NavigationRail(selectedIndex: _selected, onDestinationSelected: (v) => setState(() => _selected = v), labelType: NavigationRailLabelType.all, destinations: _destinations()), Expanded(child: content)]) : content,
        bottomNavigationBar: _preferences.navigation == 'tabs' && !desktop ? NavigationBar(selectedIndex: _selected, onDestinationSelected: (v) => setState(() => _selected = v), destinations: _destinations().map((d) => NavigationDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: (d.label as Text).data ?? '')).toList()) : null,
      ));
    });
  }

  Widget _gridShell(Widget content, bool desktop) {
    if (desktop) return Row(children: [SizedBox(width: 250, child: GridView.count(crossAxisCount: 1, padding: const EdgeInsets.all(12), childAspectRatio: 3.2, children: _gridItems())), Expanded(child: content)]);
    return Column(children: [SizedBox(height: 104, child: GridView.count(crossAxisCount: 3, padding: const EdgeInsets.all(8), childAspectRatio: 1.55, children: _gridItems())), Expanded(child: content)]);
  }

  List<Widget> _gridItems() { final s = AppStrings(_language); final labels = [s.get('attention'), s.get('evaluation'), s.get('coordination'), s.get('centers'), s.get('settings')]; return List.generate(_destinations().length, (index) => Card(child: InkWell(onTap: () => setState(() => _selected = index), borderRadius: BorderRadius.circular(14), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [_destinations()[index].selectedIcon, const SizedBox(height: 3), Text(labels[index])])))); }

  List<Widget> _drawerItems() { final s = AppStrings(_language); final labels = [s.get('attention'), s.get('evaluation'), s.get('coordination'), s.get('centers'), s.get('settings')]; return List.generate(_destinations().length, (index) => ListTile(leading: _destinations()[index].selectedIcon, title: Text(labels[index]), selected: _selected == index, onTap: () { setState(() => _selected = index); Navigator.pop(context); })); }

  List<NavigationRailDestination> _destinations() { final s = AppStrings(_language); return [
    NavigationRailDestination(icon: const Icon(Icons.support_agent), label: Text(s.get('attention')), selectedIcon: const Icon(Icons.support_agent)),
    NavigationRailDestination(icon: const Icon(Icons.fact_check_outlined), label: Text(s.get('evaluation')), selectedIcon: const Icon(Icons.fact_check)),
    NavigationRailDestination(icon: const Icon(Icons.groups_outlined), label: Text(s.get('coordination')), selectedIcon: const Icon(Icons.groups)),
    NavigationRailDestination(icon: const Icon(Icons.school_outlined), label: Text(s.get('centers')), selectedIcon: const Icon(Icons.school)),
    NavigationRailDestination(icon: const Icon(Icons.settings_outlined), label: Text(s.get('settings')), selectedIcon: const Icon(Icons.settings)),
  ]; }
}

enum AgendaMode { day, week, month }

class _OverviewPage extends StatefulWidget {
  const _OverviewPage({required this.database, required this.onOpenCenters, this.initialCalendar = 'week', this.notesStyle = 'paper'});
  final EncryptedDatabase database;
  final VoidCallback onOpenCenters;
  final String initialCalendar;
  final String notesStyle;
  @override
  State<_OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<_OverviewPage> {
  late final OrientationRepository _repository = OrientationRepository(widget.database);
  late AgendaMode _mode;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<OrientationAppointment> _appointments = const [];
  String? _statusFilter;
  String _professionalFilter = '';
  String _centerFilter = '';
  String _groupFilter = '';
  String _resourceFilter = '';
  final _ics = IcsCalendarService();

  @override
  void initState() {
    super.initState();
    _mode = {'day': AgendaMode.day, 'month': AgendaMode.month}[widget.initialCalendar] ?? AgendaMode.week;
    final start = DateTime(_focusedDay.year, _focusedDay.month - 2);
    final end = DateTime(_focusedDay.year, _focusedDay.month + 3);
    _appointments = _repository.appointments(from: start, to: end, status: _statusFilter, professionalId: _professionalFilter.isEmpty ? null : _professionalFilter, centerId: _centerFilter.isEmpty ? null : _centerFilter, groupId: _groupFilter.isEmpty ? null : _groupFilter, resource: _resourceFilter.isEmpty ? null : _resourceFilter);
  }

  void _reload() {
    final start = DateTime(_focusedDay.year, _focusedDay.month - 2);
    final end = DateTime(_focusedDay.year, _focusedDay.month + 3);
    setState(() => _appointments = _repository.appointments(from: start, to: end, status: _statusFilter, professionalId: _professionalFilter.isEmpty ? null : _professionalFilter, centerId: _centerFilter.isEmpty ? null : _centerFilter, groupId: _groupFilter.isEmpty ? null : _groupFilter, resource: _resourceFilter.isEmpty ? null : _resourceFilter));
  }

  @override
  void didUpdateWidget(covariant _OverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCalendar != widget.initialCalendar) {
      setState(() => _mode = {'day': AgendaMode.day, 'month': AgendaMode.month}[widget.initialCalendar] ?? AgendaMode.week);
    }
  }

  List<OrientationAppointment> _eventsForDay(DateTime day) => _appointments.where((item) => isSameDay(item.date, day)).toList();

  Future<void> _newAppointment() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2035), initialDate: _selectedDay);
    if (date == null || !mounted) return;
    final startTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (startTime == null || !mounted) return;
    final endTime = await showTimePicker(context: context, initialTime: TimeOfDay(hour: (startTime.hour + 1) % 24, minute: startTime.minute));
    if (endTime == null || !mounted) return;
    var status = 'pending'; var color = 0; var recurrence = ''; var reminder = 60;
    final save = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(title: const Text('Nueva cita'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')), TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notas')), DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'Estado'), items: const [DropdownMenuItem(value: 'pending', child: Text('Pendiente')), DropdownMenuItem(value: 'confirmed', child: Text('Confirmada')), DropdownMenuItem(value: 'completed', child: Text('Realizada')), DropdownMenuItem(value: 'cancelled', child: Text('Cancelada')), DropdownMenuItem(value: 'no_show', child: Text('No presentado'))], onChanged: (value) { if (value != null) setDialog(() => status = value); }), DropdownButtonFormField<int>(value: color, decoration: const InputDecoration(labelText: 'Color de tipo'), items: const [DropdownMenuItem(value: 0, child: Text('Turquesa')), DropdownMenuItem(value: 1, child: Text('Azul')), DropdownMenuItem(value: 2, child: Text('Naranja')), DropdownMenuItem(value: 3, child: Text('Violeta')), DropdownMenuItem(value: 4, child: Text('Rojo'))], onChanged: (value) { if (value != null) setDialog(() => color = value); }), DropdownButtonFormField<String>(value: recurrence, decoration: const InputDecoration(labelText: 'Recurrencia'), items: const [DropdownMenuItem(value: '', child: Text('Sin recurrencia')), DropdownMenuItem(value: 'weekly', child: Text('Semanal'))], onChanged: (value) { if (value != null) setDialog(() => recurrence = value); }), DropdownButtonFormField<int>(value: reminder, decoration: const InputDecoration(labelText: 'Recordatorio'), items: const [DropdownMenuItem(value: 0, child: Text('Sin recordatorio')), DropdownMenuItem(value: 60, child: Text('1 hora antes')), DropdownMenuItem(value: 1440, child: Text('24 horas antes'))], onChanged: (value) { if (value != null) setDialog(() => reminder = value); })])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar'))]))) ?? false;
    if (save && title.text.trim().isNotEmpty) {
      final start = DateTime(date.year, date.month, date.day, startTime.hour, startTime.minute);
      final end = DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);
      if (!end.isAfter(start)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La hora de fin debe ser posterior a la de inicio.')));
        return;
      }
      if (_repository.hasOverlap(start: start, end: end)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Existe un solapamiento con otra cita.')));
        return;
      }
      final id = _repository.createAppointment(title: title.text, date: start, end: end, notes: notes.text, status: status, color: color, recurrence: recurrence, reminderMinutes: reminder);
      await LocalReminderService.instance.scheduleForAppointment(OrientationAppointment(id: id, title: title.text, date: start, end: end, status: status, color: color, recurrence: recurrence, reminderMinutes: reminder, notes: notes.text));
      if (recurrence == 'weekly') {
        for (var week = 1; week <= 12; week++) {
          final nextStart = start.add(Duration(days: week * 7));
          final nextEnd = end.add(Duration(days: week * 7));
          final nextId = _repository.createAppointment(title: title.text, date: nextStart, end: nextEnd, notes: notes.text, status: status, color: color, recurrence: 'weekly', reminderMinutes: reminder);
          await LocalReminderService.instance.scheduleForAppointment(OrientationAppointment(id: nextId, title: title.text, date: nextStart, end: nextEnd, status: status, color: color, recurrence: 'weekly', reminderMinutes: reminder, notes: notes.text));
        }
      }
      _reload();
    }
  }

  Future<void> _exportIcs() async {
    await FilePicker.saveFile(fileName: 'agenda_cercano_oriente.ics', bytes: Uint8List.fromList(_ics.exportEvents(_appointments)));
  }

  Future<void> _importIcs() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['ics']);
    if (file == null) return;
    final result = _ics.importEvents(utf8.decode(await file.readAsBytes()), existing: _appointments);
    if (!mounted) return;
    final proceed = result.duplicates.isEmpty || (await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Eventos duplicados'), content: Text('${result.duplicates.length} evento(s) parecen duplicados. ¿Importar solo los nuevos?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Importar nuevos'))]))) ?? false;
    if (!proceed) return;
    for (final event in result.events) {
      _repository.createAppointment(title: event.title, date: event.date, end: event.end, status: event.status, notes: event.notes);
      await LocalReminderService.instance.scheduleForAppointment(event);
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final wide = constraints.maxWidth >= 1100;
    final agenda = _buildAgenda();
    final notes = _NotesPanel(repository: _repository, style: widget.notesStyle, onChanged: _reload);
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Atención Directa', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), const Text('Citas, seguimiento y recordatorios del orientador.'), const SizedBox(height: 20), Wrap(spacing: 12, runSpacing: 12, children: [_ActionCard(icon: Icons.person_search, title: 'Nueva atención', onTap: () {}), _ActionCard(icon: Icons.event_available, title: 'Nueva cita', onTap: _newAppointment), _ActionCard(icon: Icons.school, title: 'Gestionar centros', onTap: widget.onOpenCenters)])])), if (wide) const SizedBox(width: 24), if (wide) SizedBox(width: 330, child: notes)]), const SizedBox(height: 16), AgendaToolbar(status: _statusFilter, professional: _professionalFilter, center: _centerFilter, group: _groupFilter, resource: _resourceFilter, onStatus: (value) { setState(() => _statusFilter = value); _reload(); }, onProfessional: (value) { _professionalFilter = value; _reload(); }, onCenter: (value) { _centerFilter = value; _reload(); }, onGroup: (value) { _groupFilter = value; _reload(); }, onResource: (value) { _resourceFilter = value; _reload(); }, onExport: _exportIcs, onImport: _importIcs), const SizedBox(height: 12), if (!wide) notes, if (!wide) const SizedBox(height: 20), agenda]);
  });

  Widget _buildAgenda() {
    if (_mode == AgendaMode.day) return _DailyAgenda(date: _selectedDay, events: _eventsForDay(_selectedDay), onAdd: _newAppointment);
    final format = _mode == AgendaMode.month ? CalendarFormat.month : CalendarFormat.week;
    return RepaintBoundary(child: Card(child: Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 18), child: Column(children: [Row(children: [Text('Agenda de citas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const Spacer(), SegmentedButton<AgendaMode>(segments: const [ButtonSegment(value: AgendaMode.day, label: Text('Día')), ButtonSegment(value: AgendaMode.week, label: Text('Semana')), ButtonSegment(value: AgendaMode.month, label: Text('Mes'))], selected: {_mode}, onSelectionChanged: (value) => setState(() => _mode = value.first)), IconButton(onPressed: _newAppointment, icon: const Icon(Icons.add_circle_outline), tooltip: 'Nueva cita')]), TableCalendar<OrientationAppointment>(firstDay: DateTime.utc(2020), lastDay: DateTime.utc(2035), focusedDay: _focusedDay, selectedDayPredicate: (day) => isSameDay(day, _selectedDay), calendarFormat: format, availableCalendarFormats: {format: format == CalendarFormat.month ? 'Mes' : 'Semana'}, eventLoader: _eventsForDay, onDaySelected: (selected, focused) => setState(() { _selectedDay = selected; _focusedDay = focused; }), onPageChanged: (focused) { _focusedDay = focused; _reload(); }), if (_eventsForDay(_selectedDay).isNotEmpty) _DailyAgenda(date: _selectedDay, events: _eventsForDay(_selectedDay), onAdd: _newAppointment)]))));
  }
}

class _DailyAgenda extends StatelessWidget {
  const _DailyAgenda({required this.date, required this.events, required this.onAdd});
  final DateTime date; final List<OrientationAppointment> events; final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(DateFormat('dd/MM/yyyy').format(date), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const Spacer(), IconButton(onPressed: onAdd, icon: const Icon(Icons.add), tooltip: 'Añadir cita')]), if (events.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('No hay citas para este día.')) else ...events.map((event) { final tone = [Colors.teal, Colors.blue, Colors.orange, Colors.purple, Colors.red][event.color.clamp(0, 4)]; final time = event.end == null ? DateFormat('HH:mm').format(event.date) : '${DateFormat('HH:mm').format(event.date)}–${DateFormat('HH:mm').format(event.end!)}'; return ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.event_available, color: tone), title: Text(event.title), subtitle: Text('$time · ${_statusLabel(event.status)}${event.resource.isEmpty ? '' : ' · ${event.resource}'}${event.notes.isEmpty ? '' : '\n${event.notes}'}')); })])));
}

String _statusLabel(String status) => {'pending': 'Pendiente', 'confirmed': 'Confirmada', 'completed': 'Realizada', 'cancelled': 'Cancelada', 'no_show': 'No presentado'}[status] ?? status;

class _NotesPanel extends StatefulWidget {
  const _NotesPanel({required this.repository, required this.onChanged, this.style = 'paper'});
  final OrientationRepository repository; final VoidCallback onChanged;
  final String style;
  @override
  State<_NotesPanel> createState() => _NotesPanelState();
}
class _NotesPanelState extends State<_NotesPanel> {
  static const _colors = [Color(0xfffff3b0), Color(0xffffd6a5), Color(0xffcaffbf), Color(0xffbde0fe), Color(0xffe4c1f9)];
  Future<void> _add() async {
    final title = TextEditingController(); final body = TextEditingController(); var color = 0;
    final save = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(title: const Text('Nuevo post-it'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')), TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Recordatorio')), DropdownButtonFormField<int>(value: color, decoration: const InputDecoration(labelText: 'Color'), items: List.generate(_colors.length, (index) => DropdownMenuItem(value: index, child: Text('Color ${index + 1}'))), onChanged: (value) { if (value != null) setDialog(() => color = value); })]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar'))]))) ?? false;
    if (save && title.text.trim().isNotEmpty) { widget.repository.createNote(title: title.text, body: body.text, color: color); setState(() {}); widget.onChanged(); }
  }
  @override
  Widget build(BuildContext context) { final notes = widget.repository.notes(includeDone: true); final cork = widget.style == 'cork'; final minimal = widget.style == 'minimal'; final surface = cork ? const Color(0xffb8794b) : minimal ? const Color(0xffeef7f6) : Theme.of(context).colorScheme.surface; return Card(color: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(minimal ? 4 : 20)), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(cork ? Icons.push_pin : Icons.push_pin_outlined), const SizedBox(width: 8), Text('Notas rápidas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const Spacer(), IconButton(onPressed: _add, icon: const Icon(Icons.add), tooltip: 'Añadir nota')]), const Divider(), if (notes.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Añade un recordatorio puntual.')) else ...notes.take(5).map((note) => _NoteTile(note: note, color: _colors[note.color.clamp(0, _colors.length - 1)], repository: widget.repository, onChanged: () { setState(() {}); widget.onChanged(); }))]))); }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note, required this.color, required this.repository, required this.onChanged});
  final OrientatorNote note; final Color color; final OrientationRepository repository; final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)), child: ListTile(dense: true, leading: Checkbox(value: note.done, onChanged: (value) { repository.updateNote(OrientatorNote(id: note.id, title: note.title, body: note.body, color: note.color, done: value ?? false)); onChanged(); }), title: Text(note.title, style: TextStyle(decoration: note.done ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w700)), subtitle: Text(note.body, maxLines: 3, overflow: TextOverflow.ellipsis), trailing: IconButton(onPressed: () { repository.deleteNote(note.id); onChanged(); }, icon: const Icon(Icons.close, size: 18))));
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.onTap});
  final IconData icon; final String title; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return SizedBox(width: 220, child: Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: scheme.onPrimaryContainer)), const SizedBox(height: 14), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('Acceder ahora', style: Theme.of(context).textTheme.bodySmall)]))))); }
}

class _SectionPage extends StatelessWidget {
  const _SectionPage({required this.title, required this.icon, required this.items, this.footer});
  final String title; final IconData icon; final List<String> items;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [Icon(icon, size: 48), Text(title, style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 16), ...items.map((item) => Card(child: ListTile(leading: Icon(icon), title: Text(item), trailing: const Icon(Icons.chevron_right), onTap: () {}))), if (footer != null) ...[const SizedBox(height: 16), footer!] ]);
}

class _CentersPage extends StatelessWidget {
  const _CentersPage({required this.database});
  final EncryptedDatabase database;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [Text('CENTROS', style: Theme.of(context).textTheme.headlineMedium), const Text('Centros, grupos, alumnos y profesionales asociados.'), const SizedBox(height: 16), FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Añadir centro')), FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecordsPage(database: database))), icon: const Icon(Icons.badge), label: const Text('Gestionar alumnos y profesionales')), const Card(child: ListTile(leading: Icon(Icons.school), title: Text('Sin centros registrados'), subtitle: Text('La estructura está lista para añadir centros y grupos.')))]);
}
