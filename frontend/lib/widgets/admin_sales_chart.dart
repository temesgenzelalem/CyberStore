import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminSalesChart extends StatelessWidget {
  final List<dynamic> dailySales;
  const AdminSalesChart({super.key, required this.dailySales});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
          lineBarsData: [
            LineChartBarData(
              spots: dailySales.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), double.parse(entry.value['sales'].toString()));
              }).toList(),
              isCurved: true,
              color: Theme.of(context).primaryColor,
              barWidth: 4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Theme.of(context).primaryColor.withOpacity(0.3)),
            ),
          ],
        ),
      ),
    );
  }
}
