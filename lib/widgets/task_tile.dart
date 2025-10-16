// lib/widgets/task_tile.dart
import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.onTap,
  });

  final Task task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final now = DateTime.now();
    final due = task.due;

    final isOverdue = due != null && !task.done && due.isBefore(now);
    final isToday = due != null &&
        DateTime(due.year, due.month, due.day) ==
            DateTime(now.year, now.month, now.day);

    final sideColor = isOverdue
        ? Colors.red
        : (isToday ? scheme.secondary : scheme.outlineVariant);

    final bgColor = isToday && !task.done
        ? scheme.secondaryContainer.withOpacity(0.35)
        : scheme.surface;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: bgColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: sideColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                decoration: task.done
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.done
                                    ? theme.textTheme.titleMedium?.color
                                        ?.withOpacity(0.6)
                                    : (isOverdue
                                        ? Colors.red.shade700
                                        : theme
                                            .textTheme.titleMedium?.color),
                              ),
                            ),
                          ),
                          if (isOverdue)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Tooltip(
                                message: 'Gecikti',
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if ((task.note ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.note!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.75),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4, // Etiketler için satır aralığı
                        children: [
                          if (task.due != null)
                            _MiniChip(
                              icon: Icons.event,
                              label: _formatDateSmart(task.due!),
                              color: isOverdue
                                  ? Colors.red.withOpacity(.15)
                                  : isToday
                                      ? scheme.secondaryContainer
                                      : scheme.surfaceVariant,
                              onColor: isOverdue
                                  ? Colors.red.shade700
                                  : (isToday
                                      ? scheme.onSecondaryContainer
                                      : scheme.onSurfaceVariant),
                            ),
                          if (task.repeat != RepeatRule.none)
                            _MiniChip(
                              icon: Icons.repeat,
                              label: _repeatText(task.repeat),
                              color: scheme.tertiaryContainer,
                              onColor: scheme.onTertiaryContainer,
                            ),
                          ...task.tags.map(
                            (tag) => _MiniChip(
                              icon: Icons.label_outline,
                              label: tag.name,
                              color: scheme.surfaceVariant,
                              onColor: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: onColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: onColor),
          ),
        ],
      ),
    );
  }
}

// -------- helpers --------

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDateSmart(DateTime d) {
  final now = DateTime.now();
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  if (sameDay(d, now)) {
    return '${_two(d.hour)}:${_two(d.minute)}';
  }

  if (d.difference(now).inDays.abs() < 7) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return '${days[d.weekday - 1]} ${_two(d.hour)}:${_two(d.minute)}';
  }

  return '${_two(d.day)}.${_two(d.month)}.${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}

String _repeatText(RepeatRule? r) {
  switch (r) {
    case RepeatRule.daily:
      return 'Günlük';
    case RepeatRule.weekly:
      return 'Haftalık';
    case RepeatRule.monthly:
      return 'Aylık';
    case RepeatRule.none:
    case null:
      return 'Yok';
  }
}