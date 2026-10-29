import 'package:flutter/material.dart';

import '../../core/time/period_table.dart';
import '../../data/models/course_session.dart';
import '../../state/app_scope.dart';
import '../../theme/app_semantic_colors.dart';
import '../../widgets/app_dialog.dart';
import '../home/course_detail_sheet.dart';

/// 今日课程页：渐变日期卡 + 当天课程卡片列表。
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  static const List<String> _weekdayNames = <String>[
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final snapshot = controller.snapshot;
    final semantic = context.semantic;

    if (snapshot == null) {
      return Scaffold(
        body: Center(
          child: Text('还没有课表数据',
              style: TextStyle(color: semantic.textSecondary)),
        ),
      );
    }

    final now = DateTime.now();
    final calendar = snapshot.semester.calendar;
    final week = calendar.weekOf(now);
    final inSemester = week >= 1 && week <= snapshot.semester.weekCount;
    final sessions = inSemester
        ? snapshot.sessionsOfDay(week, now.weekday)
        : const <CourseSession>[];
    final campus = snapshot.dominantCampus ?? '';
    final colorIndexes = snapshot.courseColorIndexes;

    return Scaffold(
      backgroundColor: semantic.canvas,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            _AppIcon(color: semantic.accent),
            const SizedBox(width: 12),
            Text(
              '今日课程',
              style: context.texts.titleLarge?.copyWith(
                color: semantic.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '更新课表',
            onPressed: controller.busy ? null : () => _refresh(context),
            icon: controller.busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: semantic.textSecondary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: <Widget>[
          _DateHeader(
            date: now,
            weekdayText: _weekdayNames[now.weekday - 1],
            semesterName: snapshot.semester.name,
            weekText: week >= 1 ? '第 $week 周' : '不在学期内',
            campus: campus,
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 15,
                decoration: BoxDecoration(
                  color: semantic.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '共 ${sessions.length} 节课',
                style: context.texts.titleSmall?.copyWith(
                  color: semantic.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (_todayCredits(sessions) > 0) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  '${_creditLabel(_todayCredits(sessions))}学分',
                  style: context.texts.bodySmall?.copyWith(
                    color: semantic.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            _EmptyToday()
          else
            ...sessions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _TodayCourseCard(
                    session: s,
                    colorIndex: colorIndexes[s.name] ?? 0,
                    periodTable: PeriodTable.forCampus(s.campus),
                    onTap: () => showCourseDetail(
                      context,
                      session: s,
                      snapshot: snapshot,
                      periodTable: PeriodTable.forCampus(s.campus),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _refresh(BuildContext context) async {
    final controller = AppScope.read(context);
    final message = await controller.refresh();
    if (!context.mounted) return;
    if (message != null) {
      await AppDialog.show(context,
          title: '更新失败', message: message, destructive: true);
    } else {
      AppDialog.toast(context, '课表已更新');
    }
  }

  /// 今日课程的学分合计（同一门课只算一次）。
  static double _todayCredits(List<CourseSession> sessions) {
    final seen = <String>{};
    var sum = 0.0;
    for (final s in sessions) {
      final credit = s.credit;
      if (credit == null || credit <= 0) continue;
      if (!seen.add(s.courseCode.isNotEmpty ? s.courseCode : s.name)) continue;
      sum += credit;
    }
    return sum;
  }

  static String _creditLabel(double value) =>
      value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(Icons.calendar_month_rounded,
          size: 18, color: AppSemanticColors.onColor(color)),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.weekdayText,
    required this.semesterName,
    required this.weekText,
    required this.campus,
  });

  final DateTime date;
  final String weekdayText;
  final String semesterName;
  final String weekText;
  final String campus;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final accent = semantic.accent;
    // 渐变头卡固定压暗到 0.50 亮度以下，保证白色文字对比度达标
    // （深色主题的强调色偏亮，直接铺白字会看不清）。
    final hsl = HSLColor.fromColor(accent);
    final base = hsl.withLightness(hsl.lightness.clamp(0.0, 0.50)).toColor();
    final deep = hsl
        .withLightness((hsl.lightness.clamp(0.0, 0.50) - 0.10).clamp(0.0, 1.0))
        .toColor();
    final onHeader = AppSemanticColors.onColor(base);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // 左上深、右下浅，与原版渐变卡方向一致。
          colors: <Color>[deep, base],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: base.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  '${date.month} 月 ${date.day} 日  $weekdayText',
                  style: TextStyle(
                    color: onHeader,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
              ),
              if (campus.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: onHeader.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        campus,
                        style: TextStyle(
                          color: onHeader,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '校区',
                        style: TextStyle(
                          color: onHeader.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            <String>[
              if (semesterName.isNotEmpty) semesterName,
              weekText,
            ].join('  '),
            style: TextStyle(
              color: onHeader.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: <Widget>[
          Icon(Icons.wb_sunny_outlined, size: 36, color: semantic.textTertiary),
          const SizedBox(height: 12),
          Text(
            '今天没有课程安排，好好休息',
            style: context.texts.bodyMedium?.copyWith(
              color: semantic.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCourseCard extends StatelessWidget {
  const _TodayCourseCard({
    required this.session,
    required this.colorIndex,
    required this.periodTable,
    required this.onTap,
  });

  final CourseSession session;
  final int colorIndex;
  final PeriodTable periodTable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final barColor = semantic.courseAccentAt(colorIndex);
    final span = periodTable.spanText(session.startRow, session.endRow);
    final label = periodTable.labelSpan(session.startRow, session.endRow);

    return Material(
      color: semantic.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: semantic.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              session.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.titleMedium?.copyWith(
                                color: semantic.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16.5,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 20, color: semantic.textTertiary),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _MetaRow(
                        icon: Icons.schedule_rounded,
                        text: '第$label节  $span',
                      ),
                      if (session.place.isNotEmpty)
                        _MetaRow(
                          icon: Icons.place_outlined,
                          text: session.place,
                        ),
                      if (session.teacher.isNotEmpty)
                        _MetaRow(
                          icon: Icons.person_outline_rounded,
                          text: session.teacher,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          _Pill(
                            text: session.weekText,
                            background: semantic.canvas,
                            foreground: semantic.textSecondary,
                          ),
                          if (session.hasCredit) ...<Widget>[
                            const SizedBox(width: 8),
                            _Pill(
                              text: session.creditText,
                              background:
                                  semantic.accent.withValues(alpha: 0.10),
                              foreground: semantic.accent,
                            ),
                          ],
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
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: semantic.textTertiary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall?.copyWith(
                color: semantic.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 小胶囊标签：周次、学分等。
class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
    );
  }
}
