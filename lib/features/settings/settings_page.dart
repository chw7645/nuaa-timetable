import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_config.dart';
import '../../data/semester_calendar.dart';
import '../../state/app_scope.dart';
import '../../theme/app_semantic_colors.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/app_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final semantic = context.semantic;
    final mode = controller.theme.mode;

    return Scaffold(
      backgroundColor: semantic.canvas,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: semantic.accent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppSemanticColors.onColor(semantic.accent)),
            ),
            const SizedBox(width: 12),
            Text(
              '设置',
              style: context.texts.titleLarge?.copyWith(
                color: semantic.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _SectionTitle('账号'),
          _Card(
            children: <Widget>[
              _InfoRow(label: '学号', value: _usernameOf(context)),
              _InfoRow(
                label: '学期',
                value: _semesterOf(context),
              ),
              _InfoRow(
                label: '抓取方式',
                value: '教务系统一次取全（完整课表）',
              ),
              _InfoRow(
                label: '上课安排',
                value: _sessionCountOf(context),
              ),
              _InfoRow(label: '课程门数', value: _courseCountOf(context)),
              _InfoRow(label: '学分合计', value: _totalCreditsOf(context)),
              _InfoRow(label: '最近更新', value: _updatedAtOf(context)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.busy
                            ? null
                            : () => _refresh(context),
                        icon: controller.busy
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: semantic.accent,
                                ),
                              )
                            : Icon(Icons.refresh_rounded,
                                size: 17, color: semantic.accent),
                        label: Text(
                          controller.busy
                              ? (controller.status ?? '正在更新')
                              : '立即更新课表',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: semantic.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          side: BorderSide(color: semantic.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _clearAll(context),
                        icon: Icon(Icons.logout_rounded,
                            size: 17, color: semantic.danger),
                        label: Text(
                          '退出登录',
                          style: TextStyle(
                            fontSize: 13,
                            color: semantic.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          side: BorderSide(
                            color: semantic.danger.withValues(alpha: 0.6),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('学期与周次'),
          _Card(
            children: <Widget>[
              _TermRow(
                title: '第 1 周周一',
                value: _termStartOf(context),
              ),
              Divider(height: 1, color: semantic.gridLine),
              _TermRow(
                title: '本周',
                value: _currentWeekOf(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('显示与主题'),
          _Card(
            children: <Widget>[
              _Tile(
                icon: Icons.brightness_6_outlined,
                title: '主题模式',
                subtitle: '${ThemeController.label(mode)} · '
                    '${ThemeController.description(mode)}',
                onTap: () => _showThemeDialog(context),
              ),
              Divider(height: 1, color: semantic.gridLine),
              _ThemeColorTile(),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('上课提醒'),
          _Card(
            children: <Widget>[
              _SwitchTile(),
              Divider(height: 1, color: semantic.gridLine),
              _Tile(
                icon: Icons.alarm_outlined,
                title: '提前提醒时间',
                subtitle: '${controller.reminderMinutes} 分钟',
                onTap: () => _showReminderDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('节次时刻'),
          _Card(
            children: <Widget>[
              _Tile(
                icon: Icons.schedule_outlined,
                title: '作息时间',
                subtitle: '${controller.periodTable.trackLabel}'
                    '${controller.periodTrack == AppConfig.trackAuto ? '（按校区自动）' : '（手动指定）'}',
                onTap: () => _showTrackDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('桌面小组件'),
          _Card(
            children: <Widget>[
              _Tile(
                icon: Icons.widgets_outlined,
                title: '添加桌面小组件',
                subtitle: '长按桌面空白处 → 小组件 → 南航课程表',
                onTap: () => AppDialog.show(
                  context,
                  title: '添加桌面小组件',
                  message: '长按桌面空白处 → 选择「小组件 / 小部件」→ 找到「南航课程表」'
                      '→ 按住拖到桌面即可。\n\n'
                      '小组件会在换日、下课时、以及每次更新课表后自动刷新；'
                      '深色模式与主题色会自动跟随 App。',
                  confirmText: '知道了',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('数据'),
          _Card(
            children: <Widget>[
              _Tile(
                icon: Icons.sync_rounded,
                title: '更新课表',
                subtitle: controller.busy
                    ? (controller.status ?? '正在更新')
                    : _cacheText(context),
                onTap: controller.busy ? null : () => _refresh(context),
              ),
              Divider(height: 1, color: semantic.gridLine),
              _Tile(
                icon: Icons.delete_outline_rounded,
                title: '清除凭据与课表缓存',
                subtitle: '退出登录并删除本机保存的学号、密码与课表',
                danger: true,
                onTap: () => _clearAll(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('关于'),
          _Card(
            children: <Widget>[
              _VersionTile(),
              Divider(height: 1, color: semantic.gridLine),
              _Tile(
                icon: Icons.table_rows_outlined,
                title: '课表网格',
                subtitle: '${controller.periodTable.rowCount} 行 · '
                    '${controller.periodTable.trackLabel}作息'
                    '${controller.periodTrack == AppConfig.trackAuto ? '（自动匹配）' : '（手动指定）'}',
              ),
              Divider(height: 1, color: semantic.gridLine),
              _Tile(
                icon: Icons.calendar_today_outlined,
                title: '学期第 1 周',
                subtitle: _calendarText(context),
              ),
              Divider(height: 1, color: semantic.gridLine),
              _Tile(
                icon: Icons.info_outline_rounded,
                title: '数据来源',
                subtitle: '南京航空航天大学教务系统（aao-eas.nuaa.edu.cn）',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _usernameOf(BuildContext context) {
    final controller = AppScope.read(context);
    return controller.credentials.load()?.username ?? '未登录';
  }

  String _semesterOf(BuildContext context) {
    final snapshot = AppScope.read(context).snapshot;
    if (snapshot == null) return '暂无数据';
    final name = snapshot.semester.name;
    return name.isEmpty ? 'id ${snapshot.semester.id}' : '$name（id ${snapshot.semester.id}）';
  }

  String _sessionCountOf(BuildContext context) {
    final snapshot = AppScope.read(context).snapshot;
    return snapshot == null ? '0 条' : '${snapshot.sessions.length} 条';
  }

  String _courseCountOf(BuildContext context) {
    final snapshot = AppScope.read(context).snapshot;
    return snapshot == null ? '—' : '${snapshot.courseCount} 门';
  }

  String _totalCreditsOf(BuildContext context) {
    final snapshot = AppScope.read(context).snapshot;
    if (snapshot == null) return '—';
    final text = snapshot.totalCreditsText;
    return text.isEmpty ? '暂无数据' : text;
  }

  String _updatedAtOf(BuildContext context) {
    final snapshot = AppScope.read(context).snapshot;
    if (snapshot == null) return '—';
    final t = snapshot.fetchedAt;
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  String _termStartOf(BuildContext context) {
    final snapshot = AppScope.read(context).snapshot;
    if (snapshot == null) return '暂无数据';
    final d = snapshot.semester.week1Monday;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _currentWeekOf(BuildContext context) {
    final controller = AppScope.read(context);
    final snapshot = controller.snapshot;
    if (snapshot == null) return '—';
    final week = snapshot.semester.calendar.weekOf(DateTime.now());
    if (week < 1) return '未开学';
    if (week > snapshot.semester.weekCount) return '已结束';
    return '第 $week 周';
  }

  String _cacheText(BuildContext context) {
    final controller = AppScope.read(context);
    final snapshot = controller.snapshot;
    if (snapshot == null) return '尚无缓存';
    final t = snapshot.fetchedAt;
    return '上次更新 ${t.month}月${t.day}日 ${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  String _calendarText(BuildContext context) {
    final controller = AppScope.read(context);
    final snapshot = controller.snapshot;
    if (snapshot == null) return '暂无数据';
    final d = snapshot.semester.week1Monday;
    final known = SemesterCalendar.knownEntries.containsKey(snapshot.semester.id);
    return '${d.year}年${d.month}月${d.day}日（周一）'
        '${known ? '' : ' · 由规则推断，仅供参考'}';
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

  Future<void> _clearAll(BuildContext context) async {
    final controller = AppScope.read(context);
    final confirmed = await AppDialog.confirm(
      context,
      title: '清除本机数据',
      message: '将清除本机保存的凭据与课表缓存，确定继续？',
      confirmText: '清除',
      destructive: true,
    );
    if (!confirmed) return;
    await controller.logout();
    if (!context.mounted) return;
    AppDialog.toast(context, '已清除本机数据');
  }

  /// 主题切换提示弹窗。
  ///
  /// 这里刻意不使用任何硬编码颜色：标题、正文、选中态全部取自
  /// `AppSemanticColors`，因此深色模式下不会出现"深底深字"。
  Future<void> _showThemeDialog(BuildContext context) async {
    final controller = AppScope.read(context);
    final current = controller.theme.mode;

    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) {
        final semantic = ctx.semantic;
        return AlertDialog(
          backgroundColor: semantic.dialogBackground,
          surfaceTintColor: Colors.transparent,
          title: Text(
            '主题模式',
            style: ctx.texts.titleMedium?.copyWith(
              color: semantic.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '浅色 / 深色可手动指定，也可跟随系统的深浅色设置自动切换',
                style: ctx.texts.bodySmall?.copyWith(
                  color: semantic.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              ...ThemeMode.values.map((mode) {
                final isSelected = mode == current;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isSelected
                        ? semantic.accent.withValues(alpha: 0.12)
                        : semantic.canvas,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(ctx).pop(mode),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              switch (mode) {
                                ThemeMode.system => Icons.brightness_auto_rounded,
                                ThemeMode.light => Icons.light_mode_rounded,
                                ThemeMode.dark => Icons.dark_mode_rounded,
                              },
                              size: 20,
                              color: isSelected
                                  ? semantic.accent
                                  : semantic.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    ThemeController.label(mode),
                                    style: ctx.texts.bodyMedium?.copyWith(
                                      color: semantic.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ThemeController.description(mode),
                                    style: ctx.texts.bodySmall?.copyWith(
                                      color: semantic.textTertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  size: 20, color: semantic.accent),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                foregroundColor: ctx.semantic.textSecondary,
              ),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (selected == null || selected == current) return;
    await controller.setThemeMode(selected);
  }

  Future<void> _showReminderDialog(BuildContext context) async {
    final controller = AppScope.read(context);
    final options = <int>[0, 5, 10, 15, 20, 30];
    final selected = await _showOptionDialog<int>(
      context,
      title: '提前提醒时间',
      message: '在课程开始前多久发送提醒（0 表示准点提醒）',
      options: options,
      current: controller.reminderMinutes,
      labelOf: (v) => v == 0 ? '准点提醒' : '$v 分钟',
    );
    if (selected != null) {
      await controller.setReminderMinutes(selected);
    }
  }

  Future<void> _showTrackDialog(BuildContext context) async {
    final controller = AppScope.read(context);
    final selected = await _showOptionDialog<String>(
      context,
      title: '作息时间',
      message: '时间取自教务处官方作息表：将军路/明故宫上午 08:00 起，'
          '天目湖上午 08:30 起、第七节 16:00 开始。默认按课程所在校区自动匹配。',
      options: const <String>[
        AppConfig.trackAuto,
        AppConfig.trackMain,
        AppConfig.trackTianmuhu,
      ],
      current: controller.periodTrack,
      labelOf: (v) => switch (v) {
        AppConfig.trackMain => '将军路 / 明故宫（08:00 起）',
        AppConfig.trackTianmuhu => '天目湖（08:30 起）',
        _ => '自动（按课程校区）',
      },
    );
    if (selected != null) {
      await controller.setPeriodTrack(selected);
    }
  }

  Future<T?> _showOptionDialog<T>(
    BuildContext context, {
    required String title,
    required String message,
    required List<T> options,
    required T current,
    required String Function(T) labelOf,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) {
        final semantic = ctx.semantic;
        return AlertDialog(
          backgroundColor: semantic.dialogBackground,
          surfaceTintColor: Colors.transparent,
          title: Text(
            title,
            style: ctx.texts.titleMedium?.copyWith(
              color: semantic.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message,
                style: ctx.texts.bodySmall?.copyWith(
                  color: semantic.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              ...options.map((option) {
                final isSelected = option == current;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    labelOf(option),
                    style: ctx.texts.bodyMedium?.copyWith(
                      color: semantic.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: semantic.accent)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(option),
                );
              }),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                foregroundColor: semantic.textSecondary,
              ),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
      child: Row(
        children: <Widget>[
          // 左侧强调竖条：与原版一致，让分区标题在长列表里有明确锚点。
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
            text,
            style: context.texts.titleSmall?.copyWith(
              color: semantic.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Container(
      decoration: BoxDecoration(
        color: semantic.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: semantic.gridLine),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: semantic.textPrimary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon,
                size: 20,
                color: danger ? semantic.danger : semantic.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: context.texts.bodyMedium?.copyWith(
                      color: danger ? semantic.danger : semantic.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: context.texts.bodySmall?.copyWith(
                        color: semantic.textTertiary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: semantic.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final semantic = context.semantic;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(Icons.notifications_active_outlined,
              size: 20, color: semantic.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '上课提醒',
                  style: context.texts.bodyMedium?.copyWith(
                    color: semantic.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '提前若干分钟以通知形式提醒，午间加课未定义时刻不提醒',
                  style: context.texts.bodySmall?.copyWith(
                    color: semantic.textTertiary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: controller.remindersEnabled,
            onChanged: (value) async {
              final ok = await controller.setRemindersEnabled(value);
              if (!ok && context.mounted) {
                await AppDialog.show(
                  context,
                  title: '无法开启提醒',
                  message: '请在系统设置中允许通知与精确闹钟权限后重试',
                  destructive: true,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? '读取中…'
            : 'v${info.version} (${info.buildNumber})';
        return _Tile(
          icon: Icons.apps_rounded,
          title: '南航课程表',
          subtitle: version,
        );
      },
    );
  }
}


/// 主题色选择：色块网格 + 名称，选中即时生效。
class _ThemeColorTile extends StatelessWidget {
  const _ThemeColorTile();

  @override
  Widget build(BuildContext context) {
    final theme = AppScope.of(context).theme;
    final semantic = context.semantic;
    return _Tile(
      icon: Icons.palette_outlined,
      title: '主题颜色',
      subtitle: theme.seedName,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: ThemePalette.all.map((p) {
          final selected = p.seed.toARGB32() == theme.seed.toARGB32();
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              width: selected ? 16 : 12,
              height: selected ? 16 : 12,
              decoration: BoxDecoration(
                color: p.seed,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: semantic.textPrimary, width: 1.5)
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
      onTap: () => _showColorDialog(context, theme),
    );
  }

  Future<void> _showColorDialog(BuildContext context, ThemeController theme) async {
    final controller = AppScope.read(context);
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        final semantic = ctx.semantic;
        return AlertDialog(
          backgroundColor: semantic.dialogBackground,
          surfaceTintColor: Colors.transparent,
          title: Text(
            '主题颜色',
            style: ctx.texts.titleMedium?.copyWith(
              color: semantic.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '主题色会同时影响强调色、今日高亮与桌面小组件',
                style: ctx.texts.bodySmall?.copyWith(
                  color: semantic.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ThemePalette.all.map((p) {
                  final selected = p.seed.toARGB32() == theme.seed.toARGB32();
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(ctx).pop(p.seed),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: p.seed,
                            borderRadius: BorderRadius.circular(12),
                            border: selected
                                ? Border.all(
                                    color: semantic.textPrimary, width: 2)
                                : null,
                          ),
                          child: selected
                              ? Icon(Icons.check_rounded,
                                  color: AppSemanticColors.onColor(p.seed),
                                  size: 22)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          style: ctx.texts.labelSmall?.copyWith(
                            color: selected
                                ? semantic.textPrimary
                                : semantic.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                foregroundColor: ctx.semantic.textSecondary,
              ),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      await theme.setSeed(picked);
      if (controller.snapshot != null) {
        await controller.refreshWidgetAppearance();
      }
    }
  }
}

/// 账号信息行：左侧标签、右侧值，行间细分隔线。
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Container(
      // 分隔线左右缩进，与原版一致：线条只覆盖内容区，不顶到卡片圆角。
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: semantic.gridLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: context.texts.bodyMedium?.copyWith(
              color: semantic.textSecondary,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.texts.bodyMedium?.copyWith(
                color: semantic.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 学期与周次行：标题 + 数值。
class _TermRow extends StatelessWidget {
  const _TermRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.texts.titleSmall?.copyWith(
                    color: semantic.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: context.texts.bodySmall?.copyWith(
                    color: semantic.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.event_outlined, size: 20, color: semantic.accent),
        ],
      ),
    );
  }
}
