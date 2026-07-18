import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/presentation/providers/analytics_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final defaultersState = ref.watch(defaultersProvider);
    final dailyTrendsState = ref.watch(dailyTrendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics & Risk Defaulters", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(defaultersProvider);
          ref.invalidate(dailyTrendsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Chronological Attendance Trends",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
              ),
              const SizedBox(height: 12),
              
              // 1. DYNAMIC TRENDS LINE PLOT
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: SizedBox(
                    height: 200,
                    child: dailyTrendsState.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text("Failed to load trend logs: $e")),
                      data: (trends) {
                        if (trends.isEmpty) {
                          return const Center(child: Text("No trends logs registered."));
                        }
                        
                        final spots = List.generate(trends.length, (i) {
                          return FlSpot(i.toDouble(), trends[i].percentage);
                        });

                        return LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final index = val.toInt();
                                    if (index >= 0 && index < trends.length && index % (trends.length ~/ 3 + 1) == 0) {
                                      // Render date substring
                                      final label = trends[index].label;
                                      final shortLabel = label.length > 5 ? label.substring(label.length - 5) : label;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6.0),
                                        child: Text(shortLabel, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (val, meta) {
                                    return Text("${val.toInt()}%", style: const TextStyle(fontSize: 8, color: Colors.grey));
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: const Color(0xFF1B365D),
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFF1B365D).withAlpha(30),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Text(
                "Predicted High-Risk Defaulters",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
              ),
              const SizedBox(height: 4),
              const Text(
                "Students below the 75% attendance threshold ranked by calculated risk score.",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              // 2. DEFAULTER RISK CARD LIST
              defaultersState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text("Failed to load list: $e")),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text("Zero students falling under shortage metrics. Great!"),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: s.riskScore > 60 ? Colors.red[50] : Colors.orange[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    "${s.riskScore.toInt()}",
                                    style: TextStyle(
                                      color: s.riskScore > 60 ? Colors.red[950] : Colors.orange[950],
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Roll No: ${s.rollNumber} • Year ${s.year}-${s.section}",
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Department: ${s.department}",
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${s.attendancePercentage.toStringAsFixed(1)}%",
                                    style: TextStyle(
                                      color: s.attendancePercentage < 75.0 ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${s.bunkFlagsCount} Bunkings",
                                    style: TextStyle(
                                      color: s.bunkFlagsCount > 0 ? Colors.red : Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
