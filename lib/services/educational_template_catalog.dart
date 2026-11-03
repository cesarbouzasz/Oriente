class EducationalTemplate {
  const EducationalTemplate({required this.community, required this.category, required this.title, required this.description, required this.validation});
  final String community;
  final String category;
  final String title;
  final String description;
  final String validation;
}

class EducationalTemplateCatalog {
  static const communities = ['Andalucía', 'Aragón', 'Asturias', 'Canarias', 'Castilla y León', 'Cataluña', 'Galicia', 'Madrid', 'País Vasco', 'Comunitat Valenciana'];
  static List<EducationalTemplate> forCommunity(String community) => [
    EducationalTemplate(community: community, category: 'Informe', title: 'Informe psicopedagógico — $community', description: 'Modelo local para valoración psicopedagógica.', validation: 'Revisar la versión oficial vigente.'),
    EducationalTemplate(community: community, category: 'Dictamen', title: 'Dictamen de escolarización — $community', description: 'Plantilla de dictamen de escolarización.', validation: 'Revisar requisitos de la administración.'),
    EducationalTemplate(community: community, category: 'Adaptación', title: 'ACIS / adaptación curricular — $community', description: 'Modelo de adaptación curricular individualizada.', validation: 'Confirmar formato del centro.'),
    EducationalTemplate(community: community, category: 'Plan', title: 'Plan de trabajo del orientador — $community', description: 'Planificación y seguimiento de orientación.', validation: 'Revisar curso académico.'),
  ];
}
