import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/extensions/double_extensions.dart';
import '../../core/widgets/empty_state.dart';

class PriceHistoryScreen extends ConsumerStatefulWidget {
  final int productId;
  const PriceHistoryScreen({super.key, required this.productId});

  @override
  ConsumerState<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends ConsumerState<PriceHistoryScreen> {
  int? _selectedStoreId;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des prix')),
      body: StreamBuilder<List<PriceWithStore>>(
        stream: db.watchPricesForProduct(widget.productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allPrices = snapshot.data ?? [];
          if (allPrices.isEmpty) {
            return const EmptyState(
              icon: Icons.show_chart,
              title: 'Aucun prix enregistré',
              subtitle: 'Ajoutez des prix pour voir l\'historique',
            );
          }

          // Get unique stores
          final stores = <int, String>{};
          for (final p in allPrices) {
            stores[p.store.id] = p.store.name;
          }

          // Filter by selected store
          final filtered = _selectedStoreId == null
              ? allPrices
              : allPrices.where((p) => p.store.id == _selectedStoreId).toList();

          return Column(
            children: [
              // Store filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Tous'),
                      selected: _selectedStoreId == null,
                      onSelected: (_) => setState(() => _selectedStoreId = null),
                    ),
                    const SizedBox(width: 8),
                    ...stores.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(e.value),
                        selected: _selectedStoreId == e.key,
                        onSelected: (_) => setState(() => _selectedStoreId = e.key),
                      ),
                    )),
                  ],
                ),
              ),
              // Chart
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.filter_list_off,
                        title: 'Aucun prix pour ce filtre',
                        subtitle: 'Sélectionnez un autre magasin',
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildChart(filtered, stores),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChart(List<PriceWithStore> prices, Map<int, String> stores) {
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple];
    final storeIds = stores.keys.toList();

    // Group by store
    final Map<int, List<PriceWithStore>> byStore = {};
    for (final p in prices) {
      byStore.putIfAbsent(p.store.id, () => []).add(p);
    }

    // Sort each group by date
    for (final list in byStore.values) {
      list.sort((a, b) => a.price.date.compareTo(b.price.date));
    }

    final minPrice = prices.map((p) => p.price.price).reduce(
        (a, b) => a < b ? a : b);
    final maxPrice = prices.map((p) => p.price.price).reduce(
        (a, b) => a > b ? a : b);

    final lineBarsData = byStore.entries.map((entry) {
      final colorIndex = storeIds.indexOf(entry.key) % colors.length;
      final spots = entry.value.map((p) => FlSpot(
        p.price.date.millisecondsSinceEpoch.toDouble(),
        p.price.price,
      )).toList();

      return LineChartBarData(
        spots: spots,
        color: colors[colorIndex],
        isCurved: spots.length > 2,
        dotData: const FlDotData(show: true),
        barWidth: 2,
      );
    }).toList();

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              lineBarsData: lineBarsData,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      return Text(DateFormat('dd/MM').format(date),
                          style: const TextStyle(fontSize: 10));
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(value.formatPrice(),
                          style: const TextStyle(fontSize: 10));
                    },
                    reservedSize: 50,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              minY: (minPrice * 0.9).floorToDouble(),
              maxY: (maxPrice * 1.1).ceilToDouble(),
            ),
          ),
        ),
        // Legend
        Wrap(
          spacing: 16,
          children: byStore.keys.map((storeId) {
            final colorIndex = storeIds.indexOf(storeId) % colors.length;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 16, height: 4, color: colors[colorIndex]),
                const SizedBox(width: 4),
                Text(stores[storeId] ?? '', style: const TextStyle(fontSize: 12)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
