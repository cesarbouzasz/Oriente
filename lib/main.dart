import 'package:flutter/material.dart';

import 'ui/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CercanoOrienteApp());
}

class CercanoOrienteApp extends StatelessWidget {
  const CercanoOrienteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff087e8b),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Cercano Oriente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
