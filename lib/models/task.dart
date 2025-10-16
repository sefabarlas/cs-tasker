import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// YENİ: Öncelik seviyeleri için enum eklendi
enum Priority { none, low, medium, high }

class Tag {
  final String id;
  final String name;

  Tag({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

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
  final Priority priority; // YENİ: Priority alanı eklendi

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
    this.priority = Priority.none, // YENİ: Varsayılan değer atandı
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
    Priority? priority, // YENİ
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
      priority: priority ?? this.priority, // YENİ
    );
  }

  // Geri kalan metodlar aynı...
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

  // YENİ: Priority enum'ını integer'a ve tersine çeviren yardımcı metodlar
  static Priority _priorityFromInt(int? v) {
    return Priority.values[v ?? 0];
  }

  static int _priorityToInt(Priority p) {
    return p.index;
  }

  Map<String, Object?> toExportJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'due': due?.toIso8601String(),
      'repeat': repeat.name,
      'done': done,
      'sort': sort,
      'tags': tags.map((tag) => tag.name).toList(),
      'priority': priority.name, // YENİ: Yedeklemeye eklendi
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
    // YENİ: Yedekten okurken priority'yi de al
    Priority _pri(String? s) {
      switch (s) {
        case 'low': return Priority.low;
        case 'medium': return Priority.medium;
        case 'high': return Priority.high;
        default: return Priority.none;
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
      priority: _pri(m['priority'] as String?), // YENİ
    );
  }

  static Task fromDrift(dynamic dTask, {List<Tag> tags = const []}) {
    final repeatRule = _repeatFromInt(dTask.repeat as int?);
    return Task(
      id: dTask.id as String?,
      title: dTask.title as String,
      note: dTask.notes as String?,
      due: (dTask.due as int?) != null ? DateTime.fromMillisecondsSinceEpoch(dTask.due as int) : null,
      repeat: repeatRule,
      done: dTask.done as bool,
      sort: dTask.sort as int,
      createdAt: dTask.createdAtUtc as DateTime,
      updatedAt: dTask.updatedAtUtc as DateTime?,
      tags: tags,
      priority: _priorityFromInt(dTask.priority as int?), // YENİ
    );
  }
}