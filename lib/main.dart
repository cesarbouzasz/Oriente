import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'services/local_reminder_service.dart';
import 'ui/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await LocalReminderService.instance.initialize();
  } catch (_) {
    // La agenda sigue funcionando aunque el sistema no permita notificaciones.
  }
  runApp(const CercanoOrienteApp());
}

class CercanoOrienteApp extends StatelessWidget {
  const CercanoOrienteApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Cercano Oriente',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const LoginPage(),
      );
}
