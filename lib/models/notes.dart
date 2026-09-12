/// One run of text inside a notes section.
enum NoteBlockType {
  /// A prose paragraph.
  paragraph,

  /// An item in a bulleted list.
  bullet,

  /// A reference to a figure the extractor could not carry over, because the
  /// book renders terminal transcripts as images.
  caption,
}

class NoteBlock {
  final NoteBlockType type;
  final String text;

  const NoteBlock({required this.type, required this.text});

  factory NoteBlock.fromJson(Map<String, dynamic> j) => NoteBlock(
        type: switch (j['type'] as String? ?? 'p') {
          'bullet' => NoteBlockType.bullet,
          'caption' => NoteBlockType.caption,
          _ => NoteBlockType.paragraph,
        },
        text: j['text'] as String? ?? '',
      );
}

/// A heading and the text under it. [level] 1 is a major chapter section,
/// 2 a subsection.
class NoteSection {
  final String heading;
  final int level;
  final List<NoteBlock> blocks;

  const NoteSection({
    required this.heading,
    required this.level,
    required this.blocks,
  });

  factory NoteSection.fromJson(Map<String, dynamic> j) => NoteSection(
        heading: j['heading'] as String? ?? '',
        level: j['level'] as int? ?? 1,
        blocks: (j['blocks'] as List? ?? const [])
            .map((e) => NoteBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  int get wordCount =>
      blocks.fold(0, (sum, b) => sum + b.text.split(RegExp(r'\s+')).length);
}

/// Reading material for one chapter, produced by `tool/extract_notes.py`.
///
/// Optional: the files are generated locally and gitignored, so a build
/// without them simply has no notes and Learn mode shows the bank-derived
/// material on its own.
class ChapterNotes {
  final int chapter;
  final String title;
  final List<NoteSection> sections;

  const ChapterNotes({
    required this.chapter,
    required this.title,
    required this.sections,
  });

  factory ChapterNotes.fromJson(Map<String, dynamic> j) => ChapterNotes(
        chapter: j['chapter'] as int,
        title: j['title'] as String? ?? '',
        sections: (j['sections'] as List? ?? const [])
            .map((e) => NoteSection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  int get wordCount =>
      sections.fold(0, (sum, s) => sum + s.wordCount);
}
