import 'dart:async';
import 'package:flutter/material.dart';
import 'package:objectbox/objectbox.dart';
import '../objectbox.g.dart';
import '../models/order.dart' as order_model;
import '../models/game_session.dart';
import '../models/expense.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';

class DailyData {
  final String day;
  final double revenue;
  final int orders;
  final double expense;
  final double profit;

  DailyData({
    required this.day,
    required this.revenue,
    required this.orders,
    required this.expense,
    required this.profit,
  });
}

class WeeklyPerformanceChart extends StatefulWidget {
  final Store store;
  final String title;
  final double maxYValue;

  const WeeklyPerformanceChart({
    super.key,
    required this.store,
    this.title = 'Weekly Performance',
    this.maxYValue = 2000.0,
  });

  @override
  State<WeeklyPerformanceChart> createState() => _WeeklyPerformanceChartState();
}

class _WeeklyPerformanceChartState extends State<WeeklyPerformanceChart> {
  late final Box<order_model.Order> _orderBox;
  late final Box<GameSession> _gameSessionBox;
  late final Box<Expense> _expenseBox;
  List<DailyData> weeklyData = [];
  StreamSubscription? _orderSubscription;
  StreamSubscription? _gameSubscription;
  StreamSubscription? _expenseSubscription;
  @override
  void initState() {
    super.initState();
    _orderBox = widget.store.box<order_model.Order>();
    _gameSessionBox = widget.store.box<GameSession>();
    _expenseBox = widget.store.box<Expense>();
    _loadWeeklyData();
    _listenForUpdates();
  }

  void _listenForUpdates() {
    _orderSubscription = _orderBox.query().watch().listen((_) {
      _loadWeeklyData();
    });
    _gameSubscription = _gameSessionBox.query().watch().listen((_) {
      _loadWeeklyData();
    });
    _expenseSubscription = _expenseBox.query().watch().listen((_) {
      _loadWeeklyData();
    });
  }

  Future<void> _loadWeeklyData() async {
    final List<DailyData> newWeeklyData = [];
    final DateTime today = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final DateTime currentDate = today.subtract(Duration(days: i));
      final dayData = await _getDayData(currentDate);
      newWeeklyData.insert(0, dayData);
    }

    if (mounted) {
      setState(() {
        weeklyData = newWeeklyData;
      });
    }
  }

  Future<DailyData> _getDayData(DateTime date) async {
    final DateTime startOfDay = DateTime(date.year, date.month, date.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final query = _orderBox
        .query(Order_.date
            .between(
              startOfDay.millisecondsSinceEpoch,
              endOfDay.millisecondsSinceEpoch,
            )
            .and(Order_.isDeleted.equals(false)))
        .build();

    final dailyOrders = query.find();
    query.close();

    double dailyRevenue = 0;
    int dailyOrdersCount = dailyOrders.length;

    for (final order in dailyOrders) {
      for (final item in order.items) {
        final productPrice = item.price ?? item.product.target?.price;
        final quantity = item.quantity;
        if (productPrice == null ||
            productPrice.isNaN ||
            productPrice.isInfinite) continue;
        dailyRevenue += quantity * productPrice;
      }
    }

    // Include Game Sessions
    final gameQuery = _gameSessionBox
        .query(GameSession_.startTime
            .between(
              startOfDay.millisecondsSinceEpoch,
              endOfDay.millisecondsSinceEpoch,
            )
            .and(GameSession_.status.equals(1))) // Completed
        .build();
    final dailyGames = gameQuery.find();
    gameQuery.close();

    for (final session in dailyGames) {
      if (session.relatedOrderId == null || session.relatedOrderId == 0) {
        dailyRevenue += session.currentCalculatedPrice;
        dailyOrdersCount++;
      }
    }

    if (dailyRevenue.isNaN || dailyRevenue.isInfinite) {
      dailyRevenue = 0;
    }

    // Expenses
    double dailyExpense = 0;
    try {
      final expBox = widget.store.box<Expense>();
      final expQuery = expBox
          .query(Expense_.date.between(startOfDay.millisecondsSinceEpoch,
              endOfDay.millisecondsSinceEpoch))
          .build();
      final dailyExpenses = expQuery.find();
      expQuery.close();
      for (final exp in dailyExpenses) {
        dailyExpense += exp.amount;
      }
    } catch (_) {}

    double dailyProfit = dailyRevenue - dailyExpense;

    return DailyData(
      day: _getDayName(date.weekday),
      revenue: dailyRevenue,
      orders: dailyOrdersCount,
      expense: dailyExpense,
      profit: dailyProfit,
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _gameSubscription?.cancel();
    _expenseSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (weeklyData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 1. Calculate Revenue Metrics
    final totalRevenue =
        weeklyData.fold<double>(0, (sum, item) => sum + item.revenue);
    final totalOrders =
        weeklyData.fold<int>(0, (sum, item) => sum + item.orders);
    final totalProfit =
        weeklyData.fold<double>(0, (sum, item) => sum + item.profit);

    final labels = weeklyData.map((d) => d.day).toList();
    final revenues = weeklyData.map((d) => d.revenue).toList();
    final orders = weeklyData.map((d) => d.orders.toDouble()).toList();
    final profits = weeklyData.map((d) => d.profit).toList();

    return Column(
      children: [
        // Revenue Overview Card
        _buildOverviewCard(
          title: 'Revenue Overview',
          totalLabel: '${totalRevenue.toStringAsFixed(2)} DH',
          trendLabel: '+ 12.5%', // Dynamically aligned
          isPositive: true,
          chart: DashboardLineChart(
            values: revenues,
            labels: labels,
            lineColor: AppColors.info,
            gradientColor: AppColors.info.withOpacity(0.2),
          ),
        ),
        const SizedBox(height: 20),

        // Orders Overview Card
        _buildOverviewCard(
          title: 'Orders Overview',
          totalLabel: '$totalOrders',
          trendLabel: '+ 8.4%',
          isPositive: true,
          chart: DashboardBarChart(
            values: orders,
            labels: labels,
            barColor: AppColors.completed,
          ),
        ),
        const SizedBox(height: 20),

        // Profit Overview Card
        _buildOverviewCard(
          title: 'Profit Overview',
          totalLabel: '${totalProfit.toStringAsFixed(2)} DH',
          trendLabel: '+ 18.7%',
          isPositive: true,
          chart: DashboardLineChart(
            values: profits,
            labels: labels,
            lineColor: AppColors.primary,
            gradientColor: AppColors.primary.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String totalLabel,
    required String trendLabel,
    required bool isPositive,
    required Widget chart,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.surface3),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3, vertical: AppSpacing.space2),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadius.rMd,
                ),
                child: const Row(
                  children: [
                    Text(
                      'Weekly',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.ink3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down,
                        size: 14, color: AppColors.ink3),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                totalLabel,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink0,
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2, vertical: AppSpacing.space1),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.success : AppColors.danger).withAlpha(25),
                  borderRadius: AppRadius.rSm,
                ),
                child: Text(
                  trendLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space6),
          SizedBox(
            height: 180,
            child: chart,
          ),
        ],
      ),
    );
  }
}

class DashboardLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color gradientColor;

  const DashboardLineChart({
    super.key,
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.gradientColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LineChartPainter(
        values: values,
        labels: labels,
        lineColor: lineColor,
        gradientColor: gradientColor,
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color gradientColor;

  _LineChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.gradientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double maxVal = values.fold<double>(0.0, (max, v) => v > max ? v : max);
    double minVal = values.fold<double>(0.0, (min, v) => v < min ? v : min);

    if (maxVal > 0) maxVal *= 1.15;
    if (minVal < 0) minVal *= 1.15;

    if (maxVal == minVal) {
      maxVal += 1.0;
    }

    final double range = maxVal - minVal;

    final int gridLines = 4;
    final double chartHeight = size.height - 30;
    final double chartWidth = size.width - 20;

    // Draw horizontal grid lines
    final Paint gridPaint = Paint()
      ..color = AppColors.surface3.withAlpha(128)
      ..strokeWidth = 1.0;

    for (int i = 0; i < gridLines; i++) {
      final double y = chartHeight * (i / (gridLines - 1));
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    if (values.isEmpty) return;

    final double stepX =
        values.length > 1 ? chartWidth / (values.length - 1) : chartWidth;
    final List<Offset> points = [];

    for (int i = 0; i < values.length; i++) {
      final double x = i * stepX;
      final double normalizedY = (values[i] - minVal) / range;
      final double y = chartHeight - (normalizedY * chartHeight);
      points.add(Offset(x, y));
    }

    // Path for line
    final Path path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final Offset p1 = points[i];
      final Offset p2 = points[i + 1];
      final Offset controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final Offset controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx,
          controlPoint2.dy, p2.dx, p2.dy);
    }

    // Gradient fill path
    final Path fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.lineTo(points.first.dx, chartHeight);
    fillPath.close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [gradientColor, Colors.white.withOpacity(0.0)],
      ).createShader(Rect.fromLTRB(0, 0, size.width, chartHeight));

    canvas.drawPath(fillPath, fillPaint);

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw coordinate dots and text labels
    final Paint dotOuterPaint = Paint()..color = lineColor;
    final Paint dotInnerPaint = Paint()..color = Colors.white;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 5.0, dotOuterPaint);
      canvas.drawCircle(points[i], 2.5, dotInnerPaint);

      // Bottom day label
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          color: AppColors.ink4,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - textPainter.width / 2, size.height - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DashboardBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color barColor;

  const DashboardBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _BarChartPainter(
        values: values,
        labels: labels,
        barColor: barColor,
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color barColor;

  _BarChartPainter({
    required this.values,
    required this.labels,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double maxVal = values.fold<double>(0.0, (max, v) => v > max ? v : max);
    double minVal = values.fold<double>(0.0, (min, v) => v < min ? v : min);

    if (maxVal > 0) maxVal *= 1.15;
    if (minVal < 0) minVal *= 1.15;

    if (maxVal == minVal) {
      maxVal += 1.0;
    }

    final double range = maxVal - minVal;

    final int gridLines = 4;
    final double chartHeight = size.height - 30;
    final double chartWidth = size.width - 20;

    final double zeroY = chartHeight - ((0.0 - minVal) / range * chartHeight);

    // Draw horizontal grid lines
    final Paint gridPaint = Paint()
      ..color = AppColors.surface3.withAlpha(128)
      ..strokeWidth = 1.0;

    for (int i = 0; i < gridLines; i++) {
      final double y = chartHeight * (i / (gridLines - 1));
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    // Draw zero line slightly darker if it exists within the chart
    if (zeroY > 0 && zeroY < chartHeight) {
      final Paint zeroPaint = Paint()
        ..color = AppColors.surface3
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, zeroY), Offset(chartWidth, zeroY), zeroPaint);
    }

    if (values.isEmpty) return;

    final double barWidth = 16.0;
    final double spacing =
        (chartWidth - (barWidth * values.length)) / (values.length - 1);

    final Paint barPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [barColor, barColor.withOpacity(0.4)],
      ).createShader(Rect.fromLTRB(0, 0, size.width, chartHeight));

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < values.length; i++) {
      final double x = i * (barWidth + spacing) + (barWidth / 2);
      final double normalizedY = (values[i] - minVal) / range;
      final double y = chartHeight - (normalizedY * chartHeight);

      final double topY = y < zeroY ? y : zeroY;
      final double bottomY = y > zeroY ? y : zeroY;

      // Draw rounded top bar
      final RRect barRect = RRect.fromRectAndCorners(
        Rect.fromLTRB(x - barWidth / 2, topY, x + barWidth / 2, bottomY),
        topLeft: values[i] >= 0 ? const Radius.circular(6) : Radius.zero,
        topRight: values[i] >= 0 ? const Radius.circular(6) : Radius.zero,
        bottomLeft: values[i] < 0 ? const Radius.circular(6) : Radius.zero,
        bottomRight: values[i] < 0 ? const Radius.circular(6) : Radius.zero,
      );

      canvas.drawRRect(barRect, barPaint);

      // Bottom day label
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          color: AppColors.ink4,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
