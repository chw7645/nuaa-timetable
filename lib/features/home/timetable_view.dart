import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/time/period_table.dart';
import '../../core/time/week_calendar.dart';
import '../../data/models/course_session.dart';
import '../../data/models/timetable_snapshot.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/app_semantic_colors.dart';
import '../../widgets/app_dialog.dart';
import 'course_detail_sheet.dart';
import 'grid_metrics.dart';

/// 周课表：周次选择 + 网格 / 列表两种视图，左右滑动切周。
///
/// 流畅性要点（与"跟手"直接相关）：
/// 1. 滚动/翻页 physics 一律继承平台默认（Android 为 Clamping），
///    不硬套 `BouncingScrollPhysics`，否则边界会"拉出去再弹回来"。
/// 2. 翻页时只重建顶部区域（工具栏 / 周次条 / 信息行 / 表头），
///    分页器实例被缓存复用，避免 setState 连带重建整屏 20 个课程块。
/// 3. 周次写入控制器时走静默通道，不触发全局 notifyListeners。
class TimetableView extends StatefulWidget {
  const TimetableView({super.key});

  @override
  State<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends State<TimetableView> {
  PageController? _pageController;
  ScrollController? _chipsController;

  /// 当前展示周。页面内唯一真源，翻页只改它。
  int _week = 1;
  bool _gridMode = true;

  /// 分页器缓存：只有快照 / 视图模式 / 今天变化时才重建。
  Widget? _pager;
  int? _pagerSignature;

  /// 是否正在横向拖拽（由方向门控的识别器驱动）。
  bool _swiping = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageController != null) return;
    final controller = AppScope.of(context);
    final weekCount = controller.snapshot?.semester.weekCount ?? 1;
    final initial = controller.week.clamp(1, weekCount);
    _week = initial;
    _pageController = PageController(initialPage: initial - 1);
    _chipsController = ScrollController(initialScrollOffset: _chipsOffset(initial));
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _chipsController?.dispose();
    super.dispose();
  }

  double _chipsOffset(int week) {
    // itemExtent + separator 的固定步长，用于把当前周滚进可视区。
    final index = (week - 1).clamp(0, 999);
    return (index * _WeekChips.step - 120).clamp(0.0, double.infinity);
  }

  void _animateTo(int week, AppController controller) {
    final weekCount = controller.snapshot?.semester.weekCount ?? 1;
    final target = week.clamp(1, weekCount);
    if (target == _week) return;
    _pageController?.animateToPage(
      target - 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSwipeStart(DragStartDetails details) {
    _swiping = true;
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    final position = _pageController?.position;
    if (!_swiping || position == null) return;
    final delta = details.primaryDelta ?? 0;
    // 直接改 pixels 而不是 animateTo：拖动必须 1:1 跟手。
    position.jumpTo(
      (position.pixels - delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (!_swiping) return;
    _swiping = false;
    final position = _pageController?.position;
    if (position == null) return;
    final width = position.viewportDimension;
    if (width <= 0) return;

    final weekCount =
        AppScope.read(context).snapshot?.semester.weekCount ?? 1;
    final page = position.pixels / width;
    final velocity = details.primaryVelocity ?? 0;

    // 甩得够快就按方向翻一页，否则就近吸附。
    final int target = velocity.abs() > 350
        ? (velocity < 0 ? page.floor() + 1 : page.ceil() - 1)
        : page.round();

    _pageController!.animateToPage(
      target.clamp(0, weekCount - 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSwipeCancel() {
    _swiping = false;
  }

  void _onPageChanged(int index) {
    final week = index + 1;
    if (week == _week) return;
    setState(() => _week = week);
    // 静默同步：不 notifyListeners，避免整棵树在翻页瞬间重建造成掉帧。
    AppScope.read(context).syncWeekSilently(week);
    _scrollChipsTo(week);
  }

  void _scrollChipsTo(int week) {
    final controller = _chipsController;
    if (controller == null || !controller.hasClients) return;
    final offset = _chipsOffset(week);
    controller.animateTo(
      offset.clamp(0.0, controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectWeek(int week, AppController controller) {
    _animateTo(week, controller);
    _scrollChipsTo(week);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final snapshot = controller.snapshot;
    final semantic = context.semantic;

    if (snapshot == null || _pageController == null) {
      return Scaffold(
        body: Center(
          child: Text('还没有课表数据，下拉或到设置中更新',
              style: TextStyle(color: semantic.textSecondary)),
        ),
      );
    }

    final today = DateTime.now();
    final todayWeek = snapshot.semester.calendar.weekOf(today);
    final sessions = snapshot.sessionsOf(_week);

    return Scaffold(
      backgroundColor: semantic.canvas,
      appBar: AppBar(
        titleSpacing: 18,
        // 默认 56 会吃掉近一整节课的高度；54 仍是可点击的合理下限。
        toolbarHeight: 54,
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
              '周课表',
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
      body: Column(
        children: <Widget>[
          _WeekToolbar(
            canPrev: _week > 1,
            canNext: _week < snapshot.semester.weekCount,
            onPrev: () => _animateTo(_week - 1, controller),
            onNext: () => _animateTo(_week + 1, controller),
            onToday:
                todayWeek >= 1 ? () => _selectWeek(todayWeek, controller) : null,
            gridMode: _gridMode,
            onModeChanged: (grid) {
              if (grid == _gridMode) return;
              setState(() => _gridMode = grid);
            },
          ),
          _WeekChips(
            controller: _chipsController,
            weekCount: snapshot.semester.weekCount,
            current: _week,
            todayWeek: todayWeek,
            onSelect: (w) => _selectWeek(w, controller),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 5),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '第 $_week 周：'
                    '${_dateRange(snapshot.semester.calendar, _week)}  '
                    '共 ${sessions.length} 节  ·  左右滑动切周',
                    style: context.texts.bodySmall?.copyWith(
                      color: semantic.textTertiary,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              // 网格区铺白色"纸面"：课程底色是按白底定标的（1.33:1）。
              // 若直接透出灰色画布，对比会降到 1.23:1，块边界就开始糊。
              // 列表模式仍用画布灰，让白色课程卡浮起来。
              color: _gridMode ? semantic.cardBackground : semantic.canvas,
              child: Column(
                children: <Widget>[
                  _DayHeaderRow(
                    calendar: snapshot.semester.calendar,
                    week: _week,
                    today: today,
                    visible: _gridMode,
                    dayCount: snapshot.visibleDayCount,
                  ),
                  Expanded(
                    child:
                        _buildPager(controller, snapshot, today, todayWeek),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 分页器按签名缓存：周次变化时复用同一实例，Flutter 会直接跳过子树重建。
  Widget _buildPager(
    AppController controller,
    TimetableSnapshot snapshot,
    DateTime today,
    int todayWeek,
  ) {
    // 主题（明暗 + 强调色）必须参与签名，否则切换主题后缓存的分页器
    // 不会重建，课表颜色会停留在旧配色。
    final theme = Theme.of(context);
    final signature = Object.hash(
      identityHashCode(snapshot),
      _gridMode,
      todayWeek,
      controller.periodTable.track,
      theme.brightness,
      context.semantic.accent.toARGB32(),
    );
    final cached = _pager;
    if (cached != null && _pagerSignature == signature) return cached;

    // 用自定义识别器接管横向翻页，PageView 自身不再抢手势：
    // 默认的 HorizontalDragGestureRecognizer 只要横向位移越过 touchSlop 就
    // 宣告胜利。手指上下滑时天然带一点横向分量，一旦横向先到阈值，
    // 纵向滚动就被打断、页面横向抖一下再弹回——也就是"上下滑卡手"。
    final pager = RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        _StrictHorizontalDragRecognizer:
            GestureRecognizerFactoryWithHandlers<
                _StrictHorizontalDragRecognizer>(
          () => _StrictHorizontalDragRecognizer(debugOwner: this),
          (_StrictHorizontalDragRecognizer instance) {
            instance
              ..dragStartBehavior = DragStartBehavior.down
              ..onStart = _onSwipeStart
              ..onUpdate = _onSwipeUpdate
              ..onEnd = _onSwipeEnd
              ..onCancel = _onSwipeCancel;
          },
        ),
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: snapshot.semester.weekCount,
        // 内建拖拽关掉，位移由上面的识别器直接写 pixels。
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final pageWeek = index + 1;
        return RefreshIndicator(
          color: context.semantic.accent,
          onRefresh: () => _refresh(context),
          child: _gridMode
              ? _WeekGrid(
                  snapshot: snapshot,
                  week: pageWeek,
                  periodTable: controller.periodTable,
                  todayWeekday:
                      pageWeek == todayWeek ? today.weekday : null,
                )
              : _WeekList(
                  snapshot: snapshot,
                  week: pageWeek,
                  onOpen: (session) => showCourseDetail(
                    context,
                    session: session,
                    snapshot: snapshot,
                    periodTable: PeriodTable.forCampus(session.campus),
                  ),
                ),
          );
        },
      ),
    );

    _pager = pager;
    _pagerSignature = signature;
    return pager;
  }

  static String _dateRange(WeekCalendar calendar, int week) {
    final monday = calendar.mondayOfWeek(week);
    final sunday = monday.add(const Duration(days: 6));
    return '${monday.month}/${monday.day} - ${sunday.month}/${sunday.day}';
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
}

class _WeekToolbar extends StatelessWidget {
  const _WeekToolbar({
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.gridMode,
    required this.onModeChanged,
    this.onToday,
  });

  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onToday;
  final bool gridMode;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 窄屏（<340dp）收起"回到本周"文字，避免整行溢出。
          final compact = constraints.maxWidth < 340;
          return Row(
        children: <Widget>[
          Text(
            '周次',
            style: context.texts.bodyMedium?.copyWith(
              color: semantic.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: canPrev ? onPrev : null,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(3),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.chevron_left_rounded),
            color: semantic.textPrimary,
            disabledColor: semantic.textTertiary,
          ),
          IconButton(
            onPressed: canNext ? onNext : null,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(3),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.chevron_right_rounded),
            color: semantic.textPrimary,
            disabledColor: semantic.textTertiary,
          ),
          const SizedBox(width: 4),
          if (compact)
            IconButton(
              tooltip: '回到本周',
              onPressed: onToday,
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: Icon(Icons.track_changes_rounded,
                  color: semantic.accent),
            )
          else
            TextButton.icon(
              onPressed: onToday,
              icon: Icon(Icons.track_changes_rounded,
                  size: 16, color: semantic.accent),
              label: Text(
                '回到本周',
                style: TextStyle(
                  fontSize: 13,
                  color: semantic.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          const Spacer(),
          _ModeSwitch(gridMode: gridMode, onChanged: onModeChanged, compact: compact),
        ],
      );
        },
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.gridMode,
    required this.onChanged,
    this.compact = false,
  });

  final bool gridMode;
  final ValueChanged<bool> onChanged;

  /// 窄屏下只留图标，隐藏文字。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: semantic.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: semantic.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _modeButton(context, '课表', Icons.grid_view_rounded, true),
          _modeButton(context, '列表', Icons.view_list_rounded, false),
        ],
      ),
    );
  }

  Widget _modeButton(
      BuildContext context, String label, IconData icon, bool grid) {
    final semantic = context.semantic;
    final active = gridMode == grid;
    final onColor = AppSemanticColors.onColor(semantic.accent);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(grid),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? semantic.accent : semantic.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon,
                size: 13.5,
                color: active ? onColor : semantic.textSecondary),
            if (!compact) ...<Widget>[
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? onColor : semantic.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekChips extends StatelessWidget {
  const _WeekChips({
    required this.controller,
    required this.weekCount,
    required this.current,
    required this.todayWeek,
    required this.onSelect,
  });

  static const double chipWidth = 48;
  static const double gap = 8;
  static const double step = chipWidth + gap;

  final ScrollController? controller;
  final int weekCount;
  final int current;
  final int todayWeek;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        // 固定步长 + 缓存区，横向滚动不再反复测量 child。
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: weekCount,
        separatorBuilder: (_, _) => const SizedBox(width: gap),
        itemBuilder: (context, index) {
          final week = index + 1;
          return _WeekChip(
            week: week,
            active: week == current,
            isToday: week == todayWeek,
            onTap: () => onSelect(week),
          );
        },
      ),
    );
  }
}

class _WeekChip extends StatelessWidget {
  const _WeekChip({
    required this.week,
    required this.active,
    required this.isToday,
    required this.onTap,
  });

  final int week;
  final bool active;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final onColor = AppSemanticColors.onColor(semantic.accent);
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: _WeekChips.chipWidth,
          decoration: BoxDecoration(
            color: active ? semantic.accent : semantic.cardBackground,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active ? semantic.accent : semantic.cardBorder,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '$week',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: active ? onColor : semantic.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? (active ? onColor : semantic.accent)
                      : semantic.cardBorder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({
    required this.calendar,
    required this.week,
    required this.today,
    required this.visible,
    this.dayCount = 7,
  });

  final WeekCalendar calendar;
  final int week;
  final DateTime today;
  final bool visible;
  final int dayCount;

  static const List<String> _names = <String>['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final semantic = context.semantic;
    final days =
        List<DateTime>.generate(dayCount, (i) => calendar.dateOf(week, i + 1));

    return Container(
      padding: const EdgeInsets.only(bottom: 5, top: 1),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: semantic.gridLine)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: GridMetrics.timeColumnWidth,
            child: Center(
              child: Text(
                '节次',
                style: context.texts.labelMedium?.copyWith(
                  color: semantic.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          ...List<Widget>.generate(dayCount, (i) {
            final date = days[i];
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            return Expanded(
              child: Column(
                children: <Widget>[
                  Text(
                    '周${_names[i]}',
                    style: TextStyle(
                      color: isToday ? semantic.accent : semantic.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isToday ? semantic.accent : semantic.textTertiary,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 10,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.snapshot,
    required this.week,
    required this.periodTable,
    this.todayWeekday,
  });

  final TimetableSnapshot snapshot;
  final int week;
  final PeriodTable periodTable;
  final int? todayWeekday;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final sessions = snapshot.sessionsOf(week);
    final rows = periodTable.rowCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayCount = snapshot.visibleDayCount;
        final dayWidth =
            (constraints.maxWidth - GridMetrics.timeColumnWidth) / dayCount;
        final totalHeight = rows * GridMetrics.rowHeight;

        return SingleChildScrollView(
          // 始终可滚动（下拉刷新需要）+ 钳制边界：
          // Android 上不会再出现"拉出去再弹回"的回弹感。
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: SizedBox(
            height: totalHeight + 10,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GridPainter(
                        rows: rows,
                        lineColor: semantic.gridLine,
                        timeColumnColor: semantic.periodColumn,
                        todayColumn: (todayWeekday != null &&
                              todayWeekday! <= dayCount)
                          ? todayWeekday
                          : null,
                        todayColor: semantic.todayHighlight,
                        accentColor: semantic.accent,
                        timeColumnWidth: GridMetrics.timeColumnWidth,
                        rowHeight: GridMetrics.rowHeight,
                        dayWidth: dayWidth,
                        dayCount: dayCount,
                      ),
                    ),
                  ),
                ),
                ..._courseCards(context, sessions, dayWidth, dayCount),
                ..._timeLabels(context, rows),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _timeLabels(BuildContext context, int rows) {
    final semantic = context.semantic;
    return List<Widget>.generate(rows, (row) {
      final slot = periodTable.slotOf(row);
      return Positioned(
        left: 0,
        top: row * GridMetrics.rowHeight,
        width: GridMetrics.timeColumnWidth,
        height: GridMetrics.rowHeight,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                // 与原版一致用中文序数（第七节），课程块内仍用紧凑写法（7-8）。
                slot.isNoon ? slot.short : slot.label,
                style: TextStyle(
                  color: slot.isNoon
                      ? semantic.textTertiary
                      : semantic.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: slot.isNoon ? 9.5 : 10.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              if (slot.isNoon)
                Text(
                  '—',
                  style: TextStyle(
                    color: semantic.textTertiary,
                    fontSize: 9.5,
                    height: 1.15,
                  ),
                )
              else ...<Widget>[
                Text(
                  slot.start!,
                  style: TextStyle(
                    color: semantic.textTertiary,
                    fontSize: 9,
                    height: 1.15,
                  ),
                ),
                Text(
                  slot.end!,
                  style: TextStyle(
                    color: semantic.textTertiary,
                    fontSize: 9,
                    height: 1.15,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  /// 每个课程块只覆盖其"有课节次"行：跨午间占位行时切成多段。
  List<Widget> _courseCards(
    BuildContext context,
    List<CourseSession> sessions,
    double dayWidth,
    int dayCount,
  ) {
    final semantic = context.semantic;
    final colorIndexes = snapshot.courseColorIndexes;
    final byDay = List<List<CourseSession>>.generate(
      dayCount,
      (_) => <CourseSession>[],
    );
    for (final s in sessions) {
      if (s.dayOfWeek < 1 || s.dayOfWeek > dayCount) continue;
      byDay[s.dayOfWeek - 1].add(s);
    }

    final widgets = <Widget>[];
    for (var day = 0; day < dayCount; day++) {
      final list = byDay[day]..sort((a, b) {
          final byRow = a.startRow.compareTo(b.startRow);
          return byRow != 0 ? byRow : a.endRow.compareTo(b.endRow);
        });
      if (list.isEmpty) continue;

      final clusters = <List<CourseSession>>[];
      for (final s in list) {
        if (clusters.isNotEmpty &&
            s.startRow <=
                clusters.last
                    .map((e) => e.endRow)
                    .reduce((a, b) => a > b ? a : b)) {
          clusters.last.add(s);
        } else {
          clusters.add(<CourseSession>[s]);
        }
      }

      for (final cluster in clusters) {
        final laneEnds = <int>[];
        final laneOf = <CourseSession, int>{};
        for (final s in cluster) {
          var lane = laneEnds.indexWhere((end) => end < s.startRow);
          if (lane == -1) {
            laneEnds.add(s.endRow);
            lane = laneEnds.length - 1;
          } else {
            laneEnds[lane] = s.endRow;
          }
          laneOf[s] = lane;
        }
        final laneCount = laneEnds.length;
        final blockWidth = dayWidth / laneCount;

        for (final s in cluster) {
          final lane = laneOf[s]!;
          final left = GridMetrics.timeColumnWidth +
              day * dayWidth +
              lane * blockWidth +
              GridMetrics.blockGap;
          final color = semantic
              .courseBackgroundAt(colorIndexes[s.name] ?? 0);
          final segments = periodTable.segmentsOf(s.startRow, s.endRow);
          final hasGap = segments.length > 1;

          for (var i = 0; i < segments.length; i++) {
            final segment = segments[i];
            final top = GridMetrics.topOf(segment.first);
            final height = GridMetrics.heightOf(segment.length);
            widgets.add(Positioned(
              key: ValueKey<String>(
                  'block-${s.key}-${segment.first}-${segment.last}'),
              left: left,
              top: top,
              width: blockWidth - GridMetrics.blockGap * 2,
              height: height,
              child: _CourseBlock(
                session: s,
                background: color,
                foreground: semantic.courseForeground,
                periodTable: periodTable,
                maxHeight: height,
                showTime: !hasGap || i == 0,
                onTap: () => showCourseDetail(
                  context,
                  session: s,
                  snapshot: snapshot,
                  periodTable: periodTable,
                ),
              ),
            ));
          }
        }
      }
    }
    return widgets;
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.session,
    required this.background,
    required this.foreground,
    required this.periodTable,
    required this.maxHeight,
    required this.onTap,
    this.showTime = true,
  });

  final CourseSession session;
  final Color background;
  final Color foreground;
  final PeriodTable periodTable;
  final double maxHeight;
  final VoidCallback onTap;
  final bool showTime;

  /// 单行 meta 的高度（字号 10 + 行高 1.35）。
  static const double _metaLine = 12.2;

  @override
  Widget build(BuildContext context) {
    final span = periodTable.spanText(session.startRow, session.endRow);
    // 单节块空间有限，只放课名；跨两节及以上再逐行追加信息。
    final compact = maxHeight < 90;

    final nameFont = compact ? 11.0 : 12.0;
    final nameLines = compact ? 2 : 3;
    final nameHeight = nameFont * 1.24 * nameLines;

    final metas = <String>[
      if (showTime && span.isNotEmpty) span,
      if (session.place.isNotEmpty) _shortPlace(session.place),
      if (session.teacher.isNotEmpty) session.teacher,
    ];
    final creditText = session.creditText;
    final detailBudget = maxHeight - 12 - nameHeight;
    final detailLines = (detailBudget / _metaLine).floor().clamp(0, 4);

    final visible = <String>[];
    for (final text in metas) {
      if (visible.length >= detailLines) break;
      visible.add(text);
    }
    // 学分优先占位：空间不够时挤掉最后一条 meta，保证学分始终可见。
    if (creditText.isNotEmpty && detailLines > 0) {
      if (visible.length >= detailLines && visible.isNotEmpty) {
        visible.removeLast();
      }
      visible.add(creditText);
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(GridMetrics.radius),
      // 不做裁剪：文字已 ellipsis，省掉一层 clip layer 让滚动更轻。
      clipBehavior: Clip.none,
      child: InkWell(
        borderRadius: BorderRadius.circular(GridMetrics.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                session.name,
                maxLines: nameLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: nameFont,
                  height: 1.24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final text in visible)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text == creditText
                          ? foreground.withValues(alpha: 0.92)
                          : foreground.withValues(alpha: 0.72),
                      fontSize: 9.5,
                      height: 1.3,
                      fontWeight: text == creditText
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortPlace(String place) {
    final bracket = place.indexOf('(');
    return bracket > 0 ? place.substring(0, bracket) : place;
  }
}

/// 列表视图的一行：日期分组标题或课程卡。
sealed class _ListRow {
  const _ListRow();
}

class _DateRow extends _ListRow {
  const _DateRow({required this.day, required this.date});
  final int day;
  final DateTime date;
}

class _CourseRow extends _ListRow {
  const _CourseRow(this.session);
  final CourseSession session;
}

class _WeekList extends StatelessWidget {
  const _WeekList({
    required this.snapshot,
    required this.week,
    required this.onOpen,
  });

  final TimetableSnapshot snapshot;
  final int week;
  final ValueChanged<CourseSession> onOpen;

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
    final colorIndexes = snapshot.courseColorIndexes;
    final calendar = snapshot.semester.calendar;
    final rows = <_ListRow>[];

    for (var day = 1; day <= 7; day++) {
      final sessions = snapshot.sessionsOfDay(week, day);
      if (sessions.isEmpty) continue;
      rows.add(_DateRow(day: day, date: calendar.dateOf(week, day)));
      for (final s in sessions) {
        rows.add(_CourseRow(s));
      }
    }

    if (rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                '本周没有课程',
                style: context.texts.bodyMedium?.copyWith(
                  color: semantic.textSecondary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return switch (row) {
          _DateRow(:final day, :final date) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: <Widget>[
                  Text(
                    _weekdayNames[day - 1],
                    style: context.texts.titleSmall?.copyWith(
                      color: semantic.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${date.month}/${date.day}',
                    style: context.texts.bodySmall?.copyWith(
                      color: semantic.textTertiary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          _CourseRow(:final session) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: _ListCard(
                session: session,
                colorIndex: colorIndexes[session.name] ?? 0,
                onTap: () => onOpen(session),
              ),
            ),
        };
      },
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.session,
    required this.colorIndex,
    required this.onTap,
  });

  final CourseSession session;
  final int colorIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final table = PeriodTable.forCampus(session.campus);
    final barColor = semantic.courseAccentAt(colorIndex);
    final startSlot = table.slotOf(session.startRow);
    final endSlot = table.slotOf(session.endRow);

    return Material(
      color: semantic.cardBackground,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.none,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: semantic.cardBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                session.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.bodyMedium?.copyWith(
                                  color: semantic.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                            if (session.hasCredit)
                              _CreditBadge(
                                text: session.creditText,
                                color: semantic.accent,
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '第${table.labelSpan(session.startRow, session.endRow)}节 '
                          '${startSlot.start ?? '—'}-${endSlot.end ?? '—'}'
                          '${session.place.isEmpty ? '' : ' · ${session.place}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodySmall?.copyWith(
                            color: semantic.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 18, color: semantic.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 学分徽标：浅色底 + 强调色文字，用于列表与详情。
class _CreditBadge extends StatelessWidget {
  const _CreditBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.rows,
    required this.lineColor,
    required this.timeColumnColor,
    required this.todayColumn,
    required this.todayColor,
    required this.accentColor,
    required this.timeColumnWidth,
    required this.rowHeight,
    required this.dayWidth,
    required this.dayCount,
  });

  final int rows;
  final Color lineColor;
  final Color timeColumnColor;
  final int? todayColumn;
  final Color todayColor;
  final Color accentColor;
  final double timeColumnWidth;
  final double rowHeight;
  final double dayWidth;
  final int dayCount;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, timeColumnWidth, rows * rowHeight),
      Paint()..color = timeColumnColor,
    );

    final column = todayColumn;
    if (column != null && column >= 1 && column <= 7) {
      final left = timeColumnWidth + (column - 1) * dayWidth;
      canvas.drawRect(
        Rect.fromLTWH(left, 0, dayWidth, rows * rowHeight),
        Paint()..color = todayColor,
      );
      canvas.drawRect(
        Rect.fromLTWH(left, 0, 2, rows * rowHeight),
        Paint()..color = accentColor.withValues(alpha: 0.55),
      );
    }

    for (var r = 0; r <= rows; r++) {
      final y = r * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    for (var d = 0; d <= dayCount; d++) {
      final x = timeColumnWidth + d * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, rows * rowHeight), line);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.rows != rows ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.todayColumn != todayColumn ||
      oldDelegate.todayColor != todayColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.dayWidth != dayWidth ||
      oldDelegate.dayCount != dayCount;
}

/// 只在「横向位移明显大于纵向」时才认定的横向拖拽识别器。
///
/// 系统默认的 [HorizontalDragGestureRecognizer] 只比较横向位移与 touchSlop
/// （约 18dp）。人手上下滑时几乎不可能完全垂直，快速滑动时横向分量很容易
/// 在头几帧就超过阈值——此时横向识别器抢先 accept，纵向滚动被踢出竞技场，
/// 表现为「想上下滑，页面却横着抖一下再弹回」。
///
/// 这里在原有阈值之上再加一道方向判据：横向分量必须达到纵向分量的
/// [_dominanceRatio] 倍以上。纵向为主的滑动因此根本不会让横向识别器胜出，
/// 手势自然落到内层的纵向滚动上。
class _StrictHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  _StrictHorizontalDragRecognizer({super.debugOwner});

  /// 横向分量至少要是纵向分量的多少倍，才认为是"想翻页"。
  static const double _dominanceRatio = 1.35;

  Offset? _downPosition;
  Offset? _lastPosition;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _downPosition = event.position;
    _lastPosition = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) _lastPosition = event.position;
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    final down = _downPosition;
    final last = _lastPosition;
    if (down != null && last != null) {
      final delta = last - down;
      final horizontal = delta.dx.abs();
      final vertical = delta.dy.abs();
      if (horizontal < vertical * _dominanceRatio) return false;
    }
    return super.hasSufficientGlobalDistanceToAccept(
      pointerDeviceKind,
      deviceTouchSlop,
    );
  }
}
