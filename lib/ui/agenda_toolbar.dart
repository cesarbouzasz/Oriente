import 'package:flutter/material.dart';

class AgendaToolbar extends StatelessWidget {
  const AgendaToolbar({super.key, this.status, required this.professional, required this.center, required this.group, required this.resource, required this.onStatus, required this.onProfessional, required this.onCenter, required this.onGroup, required this.onResource, required this.onExport, required this.onImport});
  final String? status;
  final String professional;
  final String center;
  final String group;
  final String resource;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String> onProfessional;
  final ValueChanged<String> onCenter;
  final ValueChanged<String> onGroup;
  final ValueChanged<String> onResource;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String?>(
              value: status,
              hint: const Text('Estado'),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
                DropdownMenuItem(value: 'confirmed', child: Text('Confirmadas')),
              ],
              onChanged: onStatus,
            ),
            _field('Profesional', professional, onProfessional),
            _field('Centro', center, onCenter),
            _field('Grupo', group, onGroup),
            _field('Recurso', resource, onResource),
            OutlinedButton.icon(onPressed: onExport, icon: const Icon(Icons.download), label: const Text('Exportar ICS')),
            OutlinedButton.icon(onPressed: onImport, icon: const Icon(Icons.upload), label: const Text('Importar ICS')),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value, ValueChanged<String> changed) {
    return SizedBox(width: 130, child: TextFormField(initialValue: value, decoration: InputDecoration(labelText: label, isDense: true), onChanged: changed));
  }
}
