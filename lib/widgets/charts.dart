import 'package:flutter/material.dart';
import 'package:mrx_charts/mrx_charts.dart';

class SalesData {
  final String month;
  final int sales;

  SalesData({required this.month, required this.sales});
}

class SalesChartWidget extends StatelessWidget {
  final List<SalesData> salesData;
  final String title;
  final Color chartColor;
  final double maxYValue;

SalesChartWidget({
  Key? key,
  required this.salesData,
  this.title = 'Sales Report',
  
  this.chartColor = Colors.brown,
  this.maxYValue = 12000.0,
}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Monthly Sales Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Chart(
                layers: [
                  // Line Layer
                  ChartLineLayer(
                    items: salesData.asMap().entries.map((entry) {
                      return ChartLineDataItem(
                        x: entry.key.toDouble() + 1,
                        value: entry.value.sales.toDouble(),
                      );
                    }).toList(),
                    settings: const ChartLineSettings(
                      color: Colors.brown,
                      thickness: 4,
                    ),
                  ),

                  // X and Y Axis
                  ChartAxisLayer(
                    labelX: (value) {
                      final index = value.toInt() - 1;
                      if (index >= 0 && index < salesData.length) {
                        return salesData[index].month;
                      }
                      return '';
                    },
                    labelY: (value) => value.toInt().toString(),
                    settings: ChartAxisSettings(
                      x: ChartAxisSettingsAxis(
                        frequency: 1.0,
                        max: salesData.length.toDouble(),
                        min: 1.0,
                        textStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                        ),
                      ),
                      y: ChartAxisSettingsAxis(
                        frequency: 2000.0,
                        max: maxYValue,
                        min: 0.0,
                        textStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}