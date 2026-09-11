class Chapter {
  final int num;
  final String title;
  final List<String> topics;
  final List<int> objectives;

  const Chapter({
    required this.num,
    required this.title,
    required this.topics,
    required this.objectives,
  });

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        num: j['num'] as int,
        title: j['title'] as String,
        topics: (j['topics'] as List).map((e) => e as String).toList(),
        objectives: (j['objectives'] as List).map((e) => e as int).toList(),
      );

  String get label => 'Chapter ${num.toString().padLeft(2, '0')}';
}

class Objective {
  final int id;
  final String section;
  final String text;
  final List<int> chapters;

  const Objective({
    required this.id,
    required this.section,
    required this.text,
    required this.chapters,
  });

  factory Objective.fromJson(Map<String, dynamic> j) => Objective(
        id: j['id'] as int,
        section: j['section'] as String,
        text: j['text'] as String,
        chapters: (j['chapters'] as List).map((e) => e as int).toList(),
      );
}

class Syllabus {
  final String edition;
  final List<Chapter> chapters;
  final List<Objective> objectives;

  const Syllabus({
    required this.edition,
    required this.chapters,
    required this.objectives,
  });

  factory Syllabus.fromJson(Map<String, dynamic> j) => Syllabus(
        edition: j['edition'] as String,
        chapters: (j['chapters'] as List)
            .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
            .toList(),
        objectives: (j['objectives'] as List)
            .map((e) => Objective.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Chapter chapter(int n) => chapters.firstWhere((c) => c.num == n);

  Objective objective(int id) => objectives.firstWhere((o) => o.id == id);

  /// Objectives grouped by their official heading, in exam-objective order.
  Map<String, List<Objective>> get objectivesBySection {
    final map = <String, List<Objective>>{};
    for (final o in objectives) {
      map.putIfAbsent(o.section, () => []).add(o);
    }
    return map;
  }
}
