import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/extensions/double_extensions.dart';
import '../../core/widgets/empty_state.dart';

class ShoppingListComparisonScreen extends ConsumerWidget {
  final int listId;
  const ShoppingListComparisonScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparaison des prix'),
        centerTitle: false,
        scrolledUnderElevation: 3,
      ),
      body: StreamBuilder<Map<Store, double>>(
        stream: db.watchComparisonForList(listId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final comparison = snapshot.data ?? {};
          if (comparison.isEmpty) {
            return const EmptyState(
              icon: Icons.compare_arrows,
              title: 'Pas assez de données',
              subtitle: 'Ajoutez des prix dans plusieurs magasins pour comparer',
            );
          }

          final sorted = comparison.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value));
          final minPrice = sorted.first.value;
          final maxPrice = sorted.last.value;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Winner banner
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.emoji_events_rounded,
                            color: cs.onPrimary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sorted.first.key.name,
                              style: tt.titleLarge?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Magasin le moins cher',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        minPrice.formatPrice(),
                        style: tt.headlineMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Bar chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  child: SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        barGroups: sorted.asMap().entries.map((entry) {
                          final i = entry.key;
                          final e = entry.value;
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: e.value,
                                color: i == 0
                                    ? cs.primary
                                    : cs.surfaceContainerHighest,
                                width: 32,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                rodStackItems: [],
                              ),
                            ],
                          );
                        }).toList(),
                        maxY: maxPrice * 1.2,
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i >= 0 && i < sorted.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      sorted[i].key.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: i == 0
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                        fontWeight: i == 0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              reservedSize: 32,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) => Text(
                                '${value.toStringAsFixed(0)}€',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              reservedSize: 40,
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: cs.outlineVariant,
                            strokeWidth: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Ranked list
              Text(
                'Classement',
                style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              ...sorted.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final savings = i > 0 ? e.value - minPrice : 0.0;
                final isFirst = i == 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isFirst ? cs.primaryContainer : cs.surfaceContainerLow,
                  elevation: isFirst ? 0 : 0,
                  child: ListTile(
                    leading: _RankBadge(rank: i + 1, isFirst: isFirst, cs: cs),
                    title: Text(
                      e.key.name,
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                        color: isFirst ? cs.onPrimaryContainer : null,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          e.value.formatPrice(),
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isFirst
                                ? cs.onPrimaryContainer
                                : cs.onSurface,
                          ),
                        ),
                        if (savings > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${savings.formatPrice()}',
                              style: tt.labelSmall?.copyWith(
                                  color: cs.onErrorContainer),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final bool isFirst;
  final ColorScheme cs;

  const _RankBadge({required this.rank, required this.isFirst, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isFirst ? cs.primary : cs.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isFirst
            ? Icon(Icons.emoji_events_rounded, size: 18, color: cs.onPrimary)
            : Text(
                '$rank',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}
