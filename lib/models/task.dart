import 'package:uuid/uuid.dart';

enum RepeatRule { none, daily, weekly, monthly }

class Task {
  final String? id;
  final String title;
  final String? note;
  final DateTime? due;
  final RepeatRule repeat;
  final bool done;
  final int sort;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Tag> tags;

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
    this.tags = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    String? id,
    String? title,
    String? note,
    DateTime? due,
    RepeatRule? repeat,
    bool? done,
    int? sort,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Tag>? tags,
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
      tags: tags ?? this.tags,
    );
  }

  static RepeatRule _repeatFromInt(int? v) {
    switch (v) {
      case 1:
        return RepeatRule.daily;
      case 2:
        return RepeatRule.weekly;
      case 3:
        return RepeatRule.monthly;
      default:
        return RepeatRule.none;
    }
  }

  static int _repeatToInt(RepeatRule r) {
    switch (r) {
      case RepeatRule.daily:
        return 1;
      case RepeatRule.weekly:
        return 2;
      case RepeatRule.monthly:
        return 3;
      case RepeatRule.none:
        return 0;
    }
  }

  factory Task.fromMap(Map<String, Object?> m) {
    return Task(
      id: m['id'] as String?,
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
      tags: [], 
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

  Map<String, Object?> toExportJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'due': due?.toIso8601String(),
      'repeat': repeat.name, // "none", "daily", "weekly", "monthly"
      'done': done,
      'sort': sort,
      'tags': tags.map((tag) => tag.name).toList(),
    };
  }

  static Task fromExportJson(Map<String, Object?> m) {
    RepeatRule _rep(String? s) {
      switch (s) {
        case 'daily':
          return RepeatRule.daily;
        case 'weekly':
          return RepeatRule.weekly;
        case 'monthly':
          return RepeatRule.monthly;
        default:
          return RepeatRule.none;
      }
    }

    DateTime? parseDue(String? iso) {
      if (iso == null || iso.isEmpty) return null;
      return DateTime.tryParse(iso);
    }

    String? parseId(Object? rawId) {
      if (rawId == null) return null;
      if (rawId is int) return rawId.toString();
      if (rawId is String) return rawId;
      return null;
    }

    final tagNames = (m['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    final tags = tagNames.map((name) => Tag(id: _uuid.v4(), name: name)).toList();

    return Task(
      id: parseId(m['id']),
      title: (m['title'] as String?) ?? '',
      note: m['note'] as String?,
      due: parseDue(m['due'] as String?),
      repeat: _rep(m['repeat'] as String?),
      done: (m['done'] as bool?) ?? false,
      sort: (m['sort'] as int?) ?? 0,
      tags: tags,
    );
  }

  static Task fromDrift(dynamic dTask, {List<Tag> tags = const []}) {
    final repeatRule = _repeatFromInt(dTask.repeat as int?);

    return Task(
      id: dTask.id as String?,
      title: dTask.title as String,
      note: dTask.notes as String?,
      due: (dTask.due as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(dTask.due as int)
          : null,
      repeat: repeatRule,
      done: dTask.done as bool,
      sort: dTask.sort as int,
      createdAt: dTask.createdAtUtc as DateTime,
      updatedAt: dTask.updatedAtUtc as DateTime?,
      tags: tags,
    );
  }
}

const _uuid = Uuid(); // YENİ

class Tag {
  final String id;
  final String name;

  Tag({required this.id, required this.name});

  // Eşitlik ve hashCode kontrolü için
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}