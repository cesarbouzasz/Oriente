import 'package:flutter/material.dart';

enum AppLanguage { spanish, galician, english, portuguese, french, italian, german, chinese }

class LanguageOption {
  const LanguageOption(this.language, this.name, this.nativeName, this.flag);
  final AppLanguage language;
  final String name;
  final String nativeName;
  final String flag;
}

class AppLanguages {
  static const options = <LanguageOption>[
    LanguageOption(AppLanguage.spanish, 'Spanish', 'Español', '🇪🇸'),
    LanguageOption(AppLanguage.galician, 'Galician', 'Galego', '🟦'),
    LanguageOption(AppLanguage.english, 'English', 'English', '🇬🇧'),
    LanguageOption(AppLanguage.portuguese, 'Portuguese', 'Português', '🇵🇹'),
    LanguageOption(AppLanguage.french, 'French', 'Français', '🇫🇷'),
    LanguageOption(AppLanguage.italian, 'Italian', 'Italiano', '🇮🇹'),
    LanguageOption(AppLanguage.german, 'German', 'Deutsch', '🇩🇪'),
    LanguageOption(AppLanguage.chinese, 'Chinese', '中文', '🇨🇳'),
  ];
  static AppLanguage fromCode(String value) => AppLanguage.values.firstWhere((item) => item.name == value, orElse: () => AppLanguage.spanish);
}

class AppStrings {
  AppStrings(this.language);
  final AppLanguage language;
  static const _es = {'app': 'Cercano Oriente', 'search': 'Buscar', 'attention': 'Atención directa', 'evaluation': 'Evaluación', 'coordination': 'Coordinación', 'centers': 'Centros', 'settings': 'Configuración', 'design': 'Configuración de Diseño y Estilo', 'designSubtitle': 'Personaliza la apariencia y el diseño de tu aplicación', 'language': 'Idioma', 'navigation': 'Navegación', 'calendar': 'Calendario', 'notes': 'Notas', 'preview': 'Vista previa', 'save': 'Guardar cambios'};
  String get(String key) => _es[key] ?? key;
}

class LanguageFlag extends StatelessWidget {
  const LanguageFlag({required this.language, super.key});
  final AppLanguage language;
  @override
  Widget build(BuildContext context) => Text(AppLanguages.options.firstWhere((item) => item.language == language).flag, style: const TextStyle(fontSize: 22));
}
