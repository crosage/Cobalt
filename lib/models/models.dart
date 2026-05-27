/// 论文数据模型

class Paper {
  final String id;
  final String conference;
  final String title;
  final List<String> authors;
  final String abstract;
  final String pdfUrl;
  final String pageUrl;
  final String arxivUrl;
  final String pages;
  String readStatus; // unread / reading / read
  double progress;
  int noteCount;
  bool hasAnalysis;
  bool hasTranslation;

  // 详情页额外字段
  String? analysis;
  String? translation;
  Map<String, String>? sections;
  List<Note>? notes;
  String? llmModel;
  int? tokenCount;
  String? translationModel;
  int? translationTokenCount;
  String? translationCreatedAt;
  String? analysisJobStatus;
  String? translationJobStatus;

  Paper({
    required this.id,
    required this.conference,
    required this.title,
    this.authors = const [],
    this.abstract = '',
    this.pdfUrl = '',
    this.pageUrl = '',
    this.arxivUrl = '',
    this.pages = '',
    this.readStatus = 'unread',
    this.progress = 0.0,
    this.noteCount = 0,
    this.hasAnalysis = false,
    this.hasTranslation = false,
    this.analysis,
    this.translation,
    this.sections,
    this.notes,
    this.llmModel,
    this.tokenCount,
    this.translationModel,
    this.translationTokenCount,
    this.translationCreatedAt,
    this.analysisJobStatus,
    this.translationJobStatus,
  });

  factory Paper.fromJson(Map<String, dynamic> json) {
    return Paper(
      id: json['id'] ?? '',
      conference: json['conference'] ?? '',
      title: json['title'] ?? '',
      authors: (json['authors'] as List?)?.cast<String>() ?? [],
      abstract: json['abstract'] ?? '',
      pdfUrl: json['pdf_url'] ?? '',
      pageUrl: json['page_url'] ?? '',
      arxivUrl: json['arxiv_url'] ?? '',
      pages: json['pages'] ?? '',
      readStatus: json['read_status'] ?? 'unread',
      progress: (json['progress'] ?? 0.0).toDouble(),
      noteCount: json['note_count'] ?? 0,
      hasAnalysis: json['has_analysis'] ?? false,
      hasTranslation: json['has_translation'] ?? false,
      analysis: json['analysis'],
      translation: json['translation'],
      sections: (json['sections'] as Map?)?.cast<String, String>(),
      notes: (json['notes'] as List?)?.map((n) => Note.fromJson(n)).toList(),
      llmModel: json['llm_model'],
      tokenCount: json['token_count'],
      translationModel: json['translation_model'],
      translationTokenCount: json['translation_token_count'],
      translationCreatedAt: json['translation_created_at'],
      analysisJobStatus: json['analysis_job_status'],
      translationJobStatus: json['translation_job_status'],
    );
  }

  String get authorsShort {
    if (authors.isEmpty) return '';
    if (authors.length <= 3) return authors.join(', ');
    return '${authors[0]} et al. (${authors.length})';
  }

  bool get isRead => readStatus == 'read';
  bool get isReading => readStatus == 'reading';
}

class Note {
  final int id;
  final String paperId;
  String content;
  final String createdAt;
  final String updatedAt;

  Note({
    required this.id,
    this.paperId = '',
    required this.content,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? 0,
      paperId: json['paper_id'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

class Conference {
  final String id;
  final bool synced;
  final int paperCount;
  final String? lastSync;

  Conference({
    required this.id,
    this.synced = false,
    this.paperCount = 0,
    this.lastSync,
  });

  factory Conference.fromJson(Map<String, dynamic> json) {
    return Conference(
      id: json['id'] ?? '',
      synced: json['synced'] ?? false,
      paperCount: json['paper_count'] ?? 0,
      lastSync: json['last_sync'],
    );
  }
}

class ResearchPaper {
  final String paperId;
  final String title;
  final List<String> authors;
  final String venue;
  final String year;
  final String abstract;
  final String snippet;
  final String section;
  final String retrievalSource;
  final bool pdfAvailable;
  final double? score;

  ResearchPaper({
    required this.paperId,
    required this.title,
    this.authors = const [],
    this.venue = '',
    this.year = '',
    this.abstract = '',
    this.snippet = '',
    this.section = '',
    this.retrievalSource = '',
    this.pdfAvailable = false,
    this.score,
  });

  factory ResearchPaper.fromJson(Map<String, dynamic> json) {
    return ResearchPaper(
      paperId: (json['paper_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      authors: _parseAuthors(json['authors']),
      venue: (json['venue'] ?? '').toString(),
      year: (json['year'] ?? '').toString(),
      abstract: (json['abstract'] ?? '').toString(),
      snippet: (json['snippet'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
      retrievalSource: (json['retrieval_source'] ?? '').toString(),
      pdfAvailable: json['pdf_available'] == true,
      score:
          json['score'] is num
              ? (json['score'] as num).toDouble()
              : double.tryParse(json['score']?.toString() ?? ''),
    );
  }

  static List<String> _parseAuthors(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is String) return item;
          if (item is Map) {
            return (item['name'] ?? item['full_name'] ?? '').toString();
          }
          return item.toString();
        })
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }

  String get authorsShort {
    if (authors.isEmpty) return '';
    if (authors.length <= 3) return authors.join(', ');
    return '${authors[0]} et al. (${authors.length})';
  }

  String get venueYear {
    final parts = [venue, year].where((v) => v.trim().isNotEmpty).toList();
    return parts.join(' ');
  }

  String get previewText {
    final text = snippet.trim().isNotEmpty ? snippet : abstract;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class Stats {
  final int totalPapers;
  final int read;
  final int reading;
  final int unread;
  final int analyzed;
  final int notes;
  final Map<String, int> byConference;

  Stats({
    this.totalPapers = 0,
    this.read = 0,
    this.reading = 0,
    this.unread = 0,
    this.analyzed = 0,
    this.notes = 0,
    this.byConference = const {},
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      totalPapers: json['total_papers'] ?? 0,
      read: json['read'] ?? 0,
      reading: json['reading'] ?? 0,
      unread: json['unread'] ?? 0,
      analyzed: json['analyzed'] ?? 0,
      notes: json['notes'] ?? 0,
      byConference: (json['by_conference'] as Map?)?.cast<String, int>() ?? {},
    );
  }
}
