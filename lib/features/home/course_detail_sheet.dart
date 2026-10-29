import 'package:flutter/material.dart';

import '../../core/time/period_table.dart';
import '../../data/models/course_session.dart';
import '../../data/models/timetable_snapshot.dart';
import '../../theme/app_semantic_colors.dart';

/// 课程详情：展示同一门课的全部上课安排。
Future<void> showCourseDetail(
  BuildContext context, {
  required CourseSession session,
  required TimetableSnapshot snapshot,
  required PeriodTable periodTable,
}) {
  final semantic = context.semantic;
  final sameCourse = snapshot.sessions
      .where((s) => s.code == session.code && s.name == session.name)
      .toList()
    ..sort((a, b) {
      final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
      return byDay != 0 ? byDay : a.startRow.compareTo(b.startRow);
    });

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: semantic.cardBackground,
    builder: (ctx) {
      final maxHeight = MediaQuery.of(ctx).size.height * 0.75;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.semantic.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      session.name,
                      style: ctx.texts.titleLarge?.copyWith(
                        color: ctx.semantic.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  if (session.hasCredit) ...<Widget>[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: ctx.semantic.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        session.creditText,
                        style: ctx.texts.labelMedium?.copyWith(
                          color: ctx.semantic.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                <String>[
                  if (session.category.isNotEmpty) session.category,
                  if (session.courseCode.isNotEmpty)
                    '课程代码 ${session.courseCode}',
                  if (session.teacher.isNotEmpty) session.teacher,
                ].join(' · '),
                style: ctx.texts.bodySmall?.copyWith(
                  color: ctx.semantic.textTertiary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '上课安排',
                style: ctx.texts.labelLarge?.copyWith(
                  color: ctx.semantic.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sameCourse.length,
                  separatorBuilder: (_, _) => Divider(
                    color: ctx.semantic.gridLine,
                    height: 20,
                  ),
                  itemBuilder: (_, index) {
                    final item = sameCourse[index];
                    return _SessionRow(
                      item: item,
                      periodTable: PeriodTable.forCampus(item.campus),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.item, required this.periodTable});

  final CourseSession item;
  final PeriodTable periodTable;

  static const List<String> _weekdayNames = <String>[
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final span = periodTable.spanText(item.startRow, item.endRow);
    final label = periodTable.labelSpan(item.startRow, item.endRow);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _weekdayNames[(item.dayOfWeek - 1).clamp(0, 6)],
                style: context.texts.bodyMedium?.copyWith(
                  color: semantic.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$label · $span',
                style: context.texts.bodySmall?.copyWith(
                  color: semantic.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.place.isEmpty ? '地点待定' : item.place,
                style: context.texts.bodyMedium?.copyWith(
                  color: semantic.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.campus.isEmpty
                    ? item.weekText
                    : '${item.weekText} · ${item.campus}',
                style: context.texts.bodySmall?.copyWith(
                  color: semantic.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
