import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mrx_charts/mrx_charts.dart';
import 'package:objectbox/objectbox.dart';
import '../objectbox.g.dart';
import '../models/order.dart' as order_model;
import '../models/game_session.dart';

class DailyData {
  final String day;
  final double revenue;
  final int orders;

  DailyData({required this.day, required this.revenue, required this.orders});
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
  late final Box<order_model.Ruci> _ruciBox;
  late final Box<GameSession> _gameSessionBox;
  List<DailyData> weeklyData = [];
  StreamSubscription? _orderSubscription;
  StreamSubscription? _gameSubscription;

  @override
  void initState() {
    super.initState();
    _ruciBox = widget.store.box<order_model.Ruci>();
    _gameSessionBox = widget.store.box<GameSession>();
    _loadWeeklyData();
    _listenForUpdates();
  }

  void _listenForUpdates() {
    _orderSubscription = _ruciBox.query().watch().listen((_) {
      _loadWeeklyData();
    });
    _gameSubscription = _gameSessionBox.query().watch().listen((_) {
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

    final query = _ruciBox
        .query(Ruci_.date
            .between(
              startOfDay.millisecondsSinceEpoch,
              endOfDay.millisecondsSinceEpoch,
            )
            .and(Ruci_.isDeleted.equals(false)))
        .build();

    final dailyOrders = query.find();
    query.close();

    if (dailyOrders.isEmpty) {
      return DailyData(
        day: _getDayName(date.weekday),
        revenue: 0,
        orders: 0,
      );
    }

    double dailyRevenue = 0;
    int dailyOrdersCount = dailyOrders.length;

    for (final order in dailyOrders) {
      for (final item in order.items) {
        final productPrice = item.price ?? item.product.target?.price;
        final quantity = item.quantity;
        if (productPrice == null || productPrice.isNaN || productPrice.isInfinite) continue;
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

    return DailyData(
      day: _getDayName(date.weekday),
      revenue: dailyRevenue,
      orders: dailyOrdersCount,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // VALIDATE chart data to prevent NaN errors and avoid rendering with empty data
    final validWeeklyData = weeklyData.where((data) {
      final validRevenue = !(data.revenue.isNaN || data.revenue.isInfinite);
      final validOrders = !(data.orders.isNaN || data.orders.isInfinite);
      return validRevenue && validOrders;
    }).toList();

    // Calculate weekly revenue for max Y value
    double weeklyRevenue = 0;
    for (final data in validWeeklyData) {
      weeklyRevenue += data.revenue;
    }
    final double maxYValue = weeklyRevenue + 200;

    // If no valid data, show a placeholder
    if (validWeeklyData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        child: const Center(
          child: Text('No valid data to display',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Chart(
              layers: [
                // Revenue Bars (Steel Blue)
                ChartBarLayer(
                  items: validWeeklyData.asMap().entries.map((entry) {
                    final value = entry.value.revenue;
                    final safeValue =
                        (value.isNaN || value.isInfinite) ? 0.0 : value;
                    final safeX = (entry.key.toDouble().isNaN ||
                            entry.key.toDouble().isInfinite)
                        ? 0.0
                        : entry.key.toDouble() + 1;
                    return ChartBarDataItem(
                      x: safeX,
                      value: safeValue,
                      color: Theme.of(context).colorScheme.primary,
                    );
                  }).toList(),
                  settings: const ChartBarSettings(
                    thickness: 10,
                    radius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),

                // Orders Bars (Midnight Violet) - offset slightly
                ChartBarLayer(
                  items: validWeeklyData.asMap().entries.map((entry) {
                    final value = entry.value.orders.toDouble();
                    final safeValue =
                        (value.isNaN || value.isInfinite) ? 0.0 : value;
                    final safeX = (entry.key.toDouble().isNaN ||
                            entry.key.toDouble().isInfinite)
                        ? 0.0
                        : entry.key.toDouble() + 1.2;
                    return ChartBarDataItem(
                      x: safeX,
                      value: safeValue,
                      color: Theme.of(context).colorScheme.onSurface,
                    );
                  }).toList(),
                  settings: const ChartBarSettings(
                    thickness: 10,
                    radius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),

                // X and Y Axis
                ChartAxisLayer(
                  labelX: (value) {
                    final index = value.toInt() - 1;
                    if (index >= 0 && index < validWeeklyData.length) {
                      return validWeeklyData[index].day;
                    }
                    return '';
                  },
                  labelY: (value) => value.toInt().toString(),
                  settings: ChartAxisSettings(
                    x: ChartAxisSettingsAxis(
                      frequency: 1.0,
                      max: validWeeklyData.length.toDouble().isNaN ||
                              validWeeklyData.length.toDouble().isInfinite
                          ? 7.0
                          : validWeeklyData.length.toDouble() + 0.5,
                      min: 0.5,
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 10,
                      ),
                    ),
                    y: ChartAxisSettingsAxis(
                      frequency: 400.0,
                      max: maxYValue.isNaN || maxYValue.isInfinite
                          ? 2000.0
                          : maxYValue,
                      min: 0.0,
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                  Theme.of(context).colorScheme.primary, 'Revenue'),
              const SizedBox(width: 20),
              _buildLegendItem(
                  Theme.of(context).colorScheme.onSurface, 'Orders'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
