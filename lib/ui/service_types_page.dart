import 'package:flutter/material.dart';

import '../db/encrypted_database.dart';
import '../db/orientation_repository.dart';

class ServiceTypesPage extends StatelessWidget {
  const ServiceTypesPage({required this.database, super.key});
  final EncryptedDatabase database;
  @override
  Widget build(BuildContext context) {
    final items = OrientationRepository(database).serviceTypes();
    return Scaffold(appBar: AppBar(title: const Text('Tipos de sesión')), body: ListView(padding: const EdgeInsets.all(20), children: [if (items.isEmpty) const Card(child: ListTile(leading: Icon(Icons.tune), title: Text('No hay tipos configurados'), subtitle: Text('Puedes añadirlos cuando el módulo de formularios esté disponible.'))), ...items.map((item) => ListTile(title: Text(item.name), subtitle: Text('${item.durationMinutes} minutos')))]));
  }
}
