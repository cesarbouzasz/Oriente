import 'package:flutter/material.dart';

import '../db/encrypted_database.dart';
import '../db/orientation_repository.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({required this.database, super.key});
  final EncryptedDatabase database;
  @override
  Widget build(BuildContext context) {
    final repository = OrientationRepository(database);
    final students = repository.students();
    final professionals = repository.professionals();
    return Scaffold(appBar: AppBar(title: const Text('Alumnos y profesionales')), body: ListView(padding: const EdgeInsets.all(20), children: [Text('Alumnos', style: Theme.of(context).textTheme.titleLarge), if (students.isEmpty) const ListTile(title: Text('No hay alumnos registrados')), ...students.map((item) => ListTile(leading: const Icon(Icons.person), title: Text(item.name), subtitle: Text(item.course))), const Divider(), Text('Profesionales', style: Theme.of(context).textTheme.titleLarge), if (professionals.isEmpty) const ListTile(title: Text('No hay profesionales registrados')), ...professionals.map((item) => ListTile(leading: const Icon(Icons.badge), title: Text(item.name), subtitle: Text(item.role))) ]));
  }
}
