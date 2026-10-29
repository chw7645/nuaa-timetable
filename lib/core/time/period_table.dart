import '../config/app_config.dart';

/// 单节课的展示数据。
///
/// 教务系统 `unitCount = 13` 的网格行顺序固定为：
/// 第一节…第四节、午一节、午二节、第五节…第十一节，
/// 中间两行是"午间加课"专用行，官方作息表未定义时刻。
class PeriodSlot {
  const PeriodSlot({
    required this.short,
    required this.label,
    this.start,
    this.end,
  });

  /// 紧凑编号，用于课表格子与小组件展示（如 `7`、`午一`）。
  final String short;

  /// 完整名称（如 `第七节`、`午一节`）。
  final String label;

  final String? start;
  final String? end;

  bool get isNoon => start == null || end == null;

  String get spanText => isNoon ? '午间' : '$start-$end';

  int? get startMinutes => isNoon ? null : _toMinutes(start!);

  int? get endMinutes => isNoon ? null : _toMinutes(end!);

  static int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}

/// 作息轨道。
enum CampusTrack {
  /// 将军路 / 明故宫校区：上午 08:00 起，7-8 节 16:15-18:00。
  main,

  /// 天目湖校区：上午 08:30 起，7-8 节 16:00-17:45。
  tianmuhu,
}

/// 节次时刻表。行号（0 基）与教务网格行一一对应。
///
/// 数据来源：南京航空航天大学教务处《校历 / 上课时间》（2026-2027 学年）。
class PeriodTable {
  const PeriodTable(this.slots, {required this.track});

  final List<PeriodSlot> slots;
  final CampusTrack track;

  static const PeriodTable mainCampus =
      PeriodTable(_mainSlots, track: CampusTrack.main);

  static const PeriodTable tianmuhuCampus =
      PeriodTable(_tianmuhuSlots, track: CampusTrack.tianmuhu);

  /// 按课程所在校区选择作息。
  static PeriodTable forCampus(String? campus) =>
      campus == '天目湖' ? tianmuhuCampus : mainCampus;

  /// 设置项：`auto` / `main` / `tianmuhu`。
  static PeriodTable of(String? setting, {String? dominantCampus}) {
    return switch (setting) {
      AppConfig.trackMain => mainCampus,
      AppConfig.trackTianmuhu => tianmuhuCampus,
      _ => forCampus(dominantCampus),
    };
  }

  static const List<PeriodSlot> _mainSlots = <PeriodSlot>[
    PeriodSlot(short: '1', label: '第一节', start: '08:00', end: '08:50'),
    PeriodSlot(short: '2', label: '第二节', start: '08:55', end: '09:45'),
    PeriodSlot(short: '3', label: '第三节', start: '10:15', end: '11:05'),
    PeriodSlot(short: '4', label: '第四节', start: '11:10', end: '12:00'),
    PeriodSlot(short: '午一', label: '午一节'),
    PeriodSlot(short: '午二', label: '午二节'),
    PeriodSlot(short: '5', label: '第五节', start: '14:00', end: '14:50'),
    PeriodSlot(short: '6', label: '第六节', start: '14:55', end: '15:45'),
    PeriodSlot(short: '7', label: '第七节', start: '16:15', end: '17:05'),
    PeriodSlot(short: '8', label: '第八节', start: '17:10', end: '18:00'),
    PeriodSlot(short: '9', label: '第九节', start: '18:45', end: '19:35'),
    PeriodSlot(short: '10', label: '第十节', start: '19:40', end: '20:30'),
    PeriodSlot(short: '11', label: '第十一节', start: '20:35', end: '21:25'),
  ];

  /// 天目湖校区：上午晚 30 分钟，下午第七节提前到 16:00。
  static const List<PeriodSlot> _tianmuhuSlots = <PeriodSlot>[
    PeriodSlot(short: '1', label: '第一节', start: '08:30', end: '09:20'),
    PeriodSlot(short: '2', label: '第二节', start: '09:25', end: '10:15'),
    PeriodSlot(short: '3', label: '第三节', start: '10:30', end: '11:20'),
    PeriodSlot(short: '4', label: '第四节', start: '11:25', end: '12:15'),
    PeriodSlot(short: '午一', label: '午一节'),
    PeriodSlot(short: '午二', label: '午二节'),
    PeriodSlot(short: '5', label: '第五节', start: '14:00', end: '14:50'),
    PeriodSlot(short: '6', label: '第六节', start: '14:55', end: '15:45'),
    PeriodSlot(short: '7', label: '第七节', start: '16:00', end: '16:50'),
    PeriodSlot(short: '8', label: '第八节', start: '16:55', end: '17:45'),
    PeriodSlot(short: '9', label: '第九节', start: '18:45', end: '19:35'),
    PeriodSlot(short: '10', label: '第十节', start: '19:40', end: '20:30'),
    PeriodSlot(short: '11', label: '第十一节', start: '20:35', end: '21:25'),
  ];

  int get rowCount => slots.length;

  PeriodSlot slotOf(int row) => slots[row.clamp(0, slots.length - 1)];

  bool isNoonRow(int row) => slotOf(row).isNoon;

  /// 节次区间文案，如 `7-8`。
  String labelSpan(int startRow, int endRow) {
    final a = slotOf(startRow).short;
    if (endRow <= startRow) return a;
    final b = slotOf(endRow).short;
    return a == b ? a : '$a-$b';
  }

  /// 时间段文案，如 `16:15-18:00`；午间加课返回 `午间`。
  String spanText(int startRow, int endRow) {
    final first = slotOf(startRow);
    final last = slotOf(endRow);
    if (first.isNoon || last.isNoon) return '午间';
    return '${first.start}-${last.end}';
  }

  int? startMinutes(int row) => slotOf(row).startMinutes;

  int? endMinutes(int row) => slotOf(row).endMinutes;

  /// 课程实际占用的"有课节次"行（剔除午间占位行），渲染时按段绘制。
  List<int> classRowsOf(int startRow, int endRow) {
    final rows = <int>[];
    for (var row = startRow; row <= endRow && row < rowCount; row++) {
      if (!isNoonRow(row)) rows.add(row);
    }
    return rows;
  }

  /// 把行区间按午间行切成连续段，避免课程色块盖住午休占位行。
  List<List<int>> segmentsOf(int startRow, int endRow) {
    final segments = <List<int>>[];
    List<int>? current;
    for (var row = startRow; row <= endRow && row < rowCount; row++) {
      if (isNoonRow(row)) {
        current = null;
        continue;
      }
      if (current == null) {
        current = <int>[row];
        segments.add(current);
      } else {
        current.add(row);
      }
    }
    return segments;
  }

  String get trackLabel => switch (track) {
        CampusTrack.main => '将军路 / 明故宫',
        CampusTrack.tianmuhu => '天目湖',
      };
}
