// lib/models/task.dart
enum RepeatRule { none, daily, weekly, monthly }

class Task {
  final int? id;
  final String title;
  final String? note;
  final DateTime? due;
  final RepeatRule repeat;
  final bool done;
  final int sort;

  // 🆕 zaman damgaları
  final DateTime createdAt;
  final DateTime? updatedAt;

  Task({
    this.id,
    required this.title,
    this.note,
    this.due,
    this.repeat = RepeatRule.none,
    this.done = false,
    this.sort = 0,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    int? id,
    String? title,
    String? note,
    DateTime? due,
    RepeatRule? repeat,
    bool? done,
    int? sort,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      due: due ?? this.due,
      repeat: repeat ?? this.repeat,
      done: done ?? this.done,
      sort: sort ?? this.sort,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static RepeatRule _repeatFromInt(int? v) {
    switch (v) {
      case 1: return RepeatRule.daily;
      case 2: return RepeatRule.weekly;
      case 3: return RepeatRule.monthly;
      default: return RepeatRule.none;
    }
  }

  static int _repeatToInt(RepeatRule r) {
    switch (r) {
      case RepeatRule.daily: return 1;
      case RepeatRule.weekly: return 2;
      case RepeatRule.monthly: return 3;
      case RepeatRule.none: return 0;
    }
  }

  factory Task.fromMap(Map<String, Object?> m) {
    return Task(
      id: m['id'] as int?,
      title: m['title'] as String,
      note: m['note'] as String?,
      due: (m['due'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(m['due'] as int)
          : null,
      repeat: _repeatFromInt(m['repeat'] as int?),
      done: (m['done'] as int? ?? 0) == 1,
      sort: m['sort'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (m['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: (m['updated_at'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int)
          : null,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'due': due?.millisecondsSinceEpoch,
      'repeat': _repeatToInt(repeat),
      'done': done ? 1 : 0,
      'sort': sort,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

    // ---- Export/Import JSON helpers (dosya için) ----
  Map<String, Object?> toExportJson() {
    return {
      // id’yi isteğe bağlı koyuyoruz (başka cihaza taşırken gerekmez)
      'id': id,
      'title': title,
      'note': note,
      'due': due?.toIso8601String(),
      'repeat': repeat.name, // "none", "daily", "weekly", "monthly"
      'done': done,
      'sort': sort,
    };
  }

  static Task fromExportJson(Map<String, Object?> m) {
    RepeatRule _rep(String? s) {
      switch (s) {
        case 'daily': return RepeatRule.daily;
        case 'weekly': return RepeatRule.weekly;
        case 'monthly': return RepeatRule.monthly;
        default: return RepeatRule.none;
      }
    }

    DateTime? _parseDue(String? iso) {
      if (iso == null || iso.isEmpty) return null;
      return DateTime.tryParse(iso);
    }

    return Task(
      id: m['id'] as int?, // import sırasında yoksa null olabilir
      title: (m['title'] as String?) ?? '',
      note: m['note'] as String?,
      due: _parseDue(m['due'] as String?),
      repeat: _rep(m['repeat'] as String?),
      done: (m['done'] as bool?) ?? false,
      sort: (m['sort'] as int?) ?? 0,
    );
  }

}