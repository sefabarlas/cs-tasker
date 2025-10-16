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

    // YENİLENDİ: `sideColor` mantığı artık sadece önceliğe odaklanıyor.
    final Color sideColor;
    switch (task.priority) {
      case Priority.high:
        sideColor = Colors.red.shade700;
        break;
      case Priority.medium:
        sideColor = Colors.orange.shade700;
        break;
      case Priority.low:
        sideColor = Colors.blue.shade700;
        break;
      case Priority.none:
      default:
        // Öncelik yoksa, sadece "bugün" durumunu belirt, gecikmeyi değil.
        sideColor = isToday ? scheme.secondary : scheme.outlineVariant;
        break;
    }
        
    final bgColor = isToday && !task.done
        ? scheme.secondaryContainer.withOpacity(0.3)
        : scheme.surface;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: sideColor,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), bottomLeft: Radius.circular(11)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                decoration: task.done ? TextDecoration.lineThrough : null,
                                // YENİLENDİ: Başlık rengi, gecikme durumunu belirtmek için kullanılıyor.
                                color: task.done
                                    ? scheme.outline
                                    : (isOverdue ? Colors.red.shade700 : scheme.onSurface),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isOverdue)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Tooltip(
                                message: 'Gecikti',
                                child: Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red.shade600),
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
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.75)),
                        ),
                      ],

                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (task.due != null)
                            _MiniChip(
                              icon: Icons.event,
                              label: _formatDateSmart(task.due!),
                              backgroundColor: isOverdue ? Colors.red.withOpacity(.15) : (isToday ? scheme.secondaryContainer : scheme.surfaceVariant),
                              textColor: isOverdue ? Colors.red.shade700 : (isToday ? scheme.onSecondaryContainer : scheme.onSurfaceVariant),
                            ),
                          if (task.repeat != RepeatRule.none)
                            _MiniChip(
                              icon: Icons.repeat,
                              label: _repeatText(task.repeat),
                              backgroundColor: scheme.surfaceContainerHighest,
                              textColor: scheme.onSurfaceVariant,
                            ),
                          ...task.tags.map(
                            (tag) => _MiniChip(
                              label: '#${tag.name}',
                              textColor: scheme.primary,
                              isOutlined: true,
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

// _MiniChip ve diğer helper fonksiyonları aynı kalıyor...
class _MiniChip extends StatelessWidget {
  const _MiniChip({this.icon, required this.label, required this.textColor, this.backgroundColor, this.isOutlined = false});
  final IconData? icon;
  final String label;
  final Color textColor;
  final Color? backgroundColor;
  final bool isOutlined;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : backgroundColor,
        border: isOutlined ? Border.all(color: textColor.withOpacity(0.8)) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: textColor), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: textColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
String _two(int n) => n.toString().padLeft(2, '0');
String _formatDateSmart(DateTime d) {
  final now = DateTime.now();
  bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  if (sameDay(d, now)) return '${_two(d.hour)}:${_two(d.minute)}';
  if (d.difference(now).inDays.abs() < 7) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return '${days[d.weekday - 1]} ${_two(d.hour)}:${_two(d.minute)}';
  }
  return '${_two(d.day)}.${_two(d.month)}.${d.year}';
}
String _repeatText(RepeatRule? r) {
  switch (r) {
    case RepeatRule.daily: return 'Günlük';
    case RepeatRule.weekly: return 'Haftalık';
    case RepeatRule.monthly: return 'Aylık';
    default: return 'Yok';
  }
}