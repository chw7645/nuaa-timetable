/// 周课表网格的几何常量。
///
/// 抽成公共常量，让**布局代码**与**几何断言测试**共用同一份真值。
/// 之前测试里各自硬编码 `66`，行高调成 76 后测试仍然"全绿"，
/// 但块的实际位置已经错位——这类漂移必须从结构上避免。
///
/// 尺寸取值目标：360×800 的机型上，网格可视区要能放下 **8 行以上**
/// （上午 4 节 + 午间 + 下午前 2 节），行高因此压到 60。
class GridMetrics {
  const GridMetrics._();

  /// 左侧节次列的宽度（需容纳「第十一节」+ 起止时刻）。
  static const double timeColumnWidth = 50;

  /// 单节行高。
  static const double rowHeight = 60;

  /// 课程块与网格线之间的留白。
  static const double blockGap = 2;

  /// 课程块圆角。
  static const double radius = 9;

  /// 课程块在某一行上的顶部偏移。
  static double topOf(int row) => row * rowHeight + blockGap;

  /// 跨 [span] 行的课程块高度。
  static double heightOf(int span) => span * rowHeight - blockGap * 2;

  /// 由课程块的 top 反推起始行（供测试使用）。
  static int rowOfTop(double top) => ((top - blockGap) / rowHeight).round();

  /// 由课程块的 top + height 反推结束行（含）。
  static int rowOfBottom(double top, double height) {
    final bottom = top + height;
    return ((bottom + blockGap) / rowHeight).round() - 1;
  }
}
