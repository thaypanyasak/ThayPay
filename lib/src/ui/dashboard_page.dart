import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/models/expense.dart';
import '../features/monthly_expenses.dart';
import 'formatters.dart';
import 'mix_tokens.dart';

/// Map emoji categories to colours + label for the pie chart
class _CategoryInfo {
  final Color color;
  final String label;
  const _CategoryInfo(this.color, this.label);
}

Map<String, _CategoryInfo> _categoryColours = {
  '🍜': const _CategoryInfo(Color(0xFFFF6B6B), 'Food'),
  '🥤': const _CategoryInfo(Color(0xFF4ECDC4), 'Drink'),
  '🛒': const _CategoryInfo(Color(0xFFA66CFF), 'Shopping'),
  '🚕': const _CategoryInfo(Color(0xFFFFB347), 'Transport'),
  '🏠': const _CategoryInfo(Color(0xFF5DADE2), 'Home'),
  '💊': const _CategoryInfo(Color(0xFFE74C3C), 'Health'),
  '🎮': const _CategoryInfo(Color(0xFF2ECC71), 'Entertainment'),
  '🧾': const _CategoryInfo(Color(0xFF95A5A6), 'Bills'),
};

const _otherColor = Color(0xFF7F8C8D);

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(currentMonthProvider);
    final expensesAsync = ref.watch(monthlyExpensesProvider);
    final monthLabel =
        '${month.month.toString().padLeft(2, '0')}/${month.year}';

    final bg = AppTokens.surface.resolve(context);
    final textColor = AppTokens.text.resolve(context);
    final muted = AppTokens.muted.resolve(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header (fixed) ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: textColor,
                        ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Tháng trước',
                      onPressed: () {
                        final prev = DateTime(month.year, month.month - 1);
                        ref.read(currentMonthProvider.notifier).state = prev;
                      },
                      icon: Icon(LucideIcons.chevronLeft, color: textColor),
                    ),
                    Text(monthLabel, style: TextStyle(color: textColor)),
                    IconButton(
                      tooltip: 'Tháng sau',
                      onPressed: () {
                        final next = DateTime(month.year, month.month + 1);
                        ref.read(currentMonthProvider.notifier).state = next;
                      },
                      icon: Icon(LucideIcons.chevronRight, color: textColor),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── 3 Summary Cards (fixed) ──
            expensesAsync.when(
              data: (items) {
                final totalExpense = items
                    .where((e) => e.amountVnd < 0)
                    .fold<int>(0, (acc, e) => acc + e.amountVnd.abs());
                final totalIncome = items
                    .where((e) => e.amountVnd > 0)
                    .fold<int>(0, (acc, e) => acc + e.amountVnd);
                final remaining = totalIncome - totalExpense;

                return _SummaryCards(
                  totalExpense: totalExpense,
                  totalIncome: totalIncome,
                  remaining: remaining,
                  bg: bg,
                  textColor: textColor,
                  muted: muted,
                );
              },
              loading: () => const _SummaryLoading(),
              error: (_, __) => const _SummaryLoading(),
            ),
            const SizedBox(height: 12),

            // ── Scrollable content ──
            Expanded(
              child: expensesAsync.when(
                data: (items) => _ScrollableChartArea(
                  month: month,
                  items: items,
                  bg: bg,
                  textColor: textColor,
                  muted: muted,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Lỗi: $e', style: TextStyle(color: muted))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary cards
// ---------------------------------------------------------------------------
class _SummaryCards extends StatelessWidget {
  final int totalExpense;
  final int totalIncome;
  final int remaining;
  final Color bg;
  final Color textColor;
  final Color muted;

  const _SummaryCards({
    required this.totalExpense,
    required this.totalIncome,
    required this.remaining,
    required this.bg,
    required this.textColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DashboardCard(
            icon: LucideIcons.arrowDown,
            iconColor: Colors.red,
            label: 'Expense',
            value: vndFormat.format(totalExpense),
            bg: bg,
            textColor: textColor,
            muted: muted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DashboardCard(
            icon: LucideIcons.arrowUp,
            iconColor: Colors.green,
            label: 'Income',
            value: vndFormat.format(totalIncome),
            bg: bg,
            textColor: textColor,
            muted: muted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DashboardCard(
            icon: LucideIcons.wallet,
            iconColor: Colors.blue,
            label: 'Remaining',
            value: vndFormat.format(remaining),
            bg: bg,
            textColor: textColor,
            muted: muted,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Scrollable chart area – contains main card + transaction list (if any)
// ---------------------------------------------------------------------------
class _ScrollableChartArea extends ConsumerStatefulWidget {
  final DateTime month;
  final List<Expense> items;
  final Color bg;
  final Color textColor;
  final Color muted;

  const _ScrollableChartArea({
    required this.month,
    required this.items,
    required this.bg,
    required this.textColor,
    required this.muted,
  });

  @override
  ConsumerState<_ScrollableChartArea> createState() =>
      _ScrollableChartAreaState();
}

class _ScrollableChartAreaState extends ConsumerState<_ScrollableChartArea> {
  String _activeMode = 'expense';
  String? _selectedCategory;
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    // ── Filter by mode ──
    final filtered = widget.items.where((e) {
      if (_activeMode == 'expense') return e.amountVnd < 0;
      return e.amountVnd > 0;
    }).toList();

    // ── Group by category ──
    final Map<String, List<Expense>> categoryMap = {};
    for (final e in filtered) {
      final key = e.emoji ?? '';
      categoryMap.putIfAbsent(key, () => []);
      categoryMap[key]!.add(e);
    }

    final totalAmount =
        filtered.fold<int>(0, (acc, e) => acc + e.amountVnd.abs());

    final categoryEntries = categoryMap.entries.toList()
      ..sort((a, b) {
        final sumA = a.value.fold<int>(0, (s, e) => s + e.amountVnd.abs());
        final sumB = b.value.fold<int>(0, (s, e) => s + e.amountVnd.abs());
        return sumB.compareTo(sumA);
      });

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < categoryEntries.length; i++) {
      final entry = categoryEntries[i];
      final sum = entry.value.fold<int>(0, (s, e) => s + e.amountVnd.abs());
      final info = _categoryColours[entry.key];
      final colour = info?.color ?? _otherColor;
      final isSelected = _selectedCategory == entry.key;
      final isDimmed = _selectedCategory != null && !isSelected;
      final isTouched = i == _touchedIndex;

      sections.add(PieChartSectionData(
        color: colour.withOpacity(isDimmed ? 0.25 : 1.0),
        value: sum.toDouble(),
        radius: isTouched ? 54 : (isSelected ? 52 : 48),
        titleStyle: const TextStyle(fontSize: 0),
        badgeWidget: isTouched
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black87,
                ),
                child: Text(
                  '${info?.label ?? 'Khác'} ${(sum / max(totalAmount, 1) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        badgePositionPercentageOffset: 1.4,
      ));
    }

    final isEmpty = sections.isEmpty;

    // ── Main chart card (always shown) ──
    final mainCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle
          _ModeToggle(
            activeMode: _activeMode,
            textColor: widget.textColor,
            onChanged: (mode) {
              setState(() {
                _activeMode = mode;
                _selectedCategory = null;
                _touchedIndex = null;
              });
            },
          ),
          const SizedBox(height: 16),

          // Pie chart
          isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    _activeMode == 'expense'
                        ? 'Chưa có chi tiêu trong tháng'
                        : 'Chưa có thu nhập trong tháng',
                    style: TextStyle(color: widget.muted),
                  ),
                )
              : SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: sections,
                          centerSpaceRadius: 50,
                          sectionsSpace: 2,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, pieTouchResponse) {
                              if (event is FlTapUpEvent) {
                                if (pieTouchResponse != null &&
                                    pieTouchResponse.touchedSection != null) {
                                  final touchedIdx = pieTouchResponse
                                      .touchedSection!.touchedSectionIndex;
                                  final key = categoryEntries[touchedIdx].key;
                                  setState(() {
                                    if (_selectedCategory == key) {
                                      _selectedCategory = null;
                                      _touchedIndex = null;
                                    } else {
                                      _selectedCategory = key;
                                      _touchedIndex = touchedIdx;
                                    }
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      // Centre text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activeMode == 'expense'
                                ? 'Total Expense'
                                : 'Total Income',
                            style: TextStyle(
                              color: widget.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _activeMode == 'expense'
                                ? '-${vndFormat.format(totalAmount)}'
                                : '+${vndFormat.format(totalAmount)}',
                            style: TextStyle(
                              color: widget.textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          const SizedBox(height: 12),

          // ── Category list ──
          if (!isEmpty) ...[
            Divider(
              color: widget.muted.withOpacity(0.15),
              height: 1,
            ),
            const SizedBox(height: 8),
            ...categoryEntries.map((entry) {
              final sum =
                  entry.value.fold<int>(0, (s, e) => s + e.amountVnd.abs());
              final percent = totalAmount > 0 ? (sum / totalAmount * 100) : 0.0;
              final info = _categoryColours[entry.key];
              final colour = info?.color ?? _otherColor;
              final label = info?.label ?? 'Khác';
              final isSelected = _selectedCategory == entry.key;
              final isDimmed = _selectedCategory != null && !isSelected;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedCategory == entry.key) {
                      _selectedCategory = null;
                      _touchedIndex = null;
                    } else {
                      _selectedCategory = entry.key;
                      _touchedIndex =
                          categoryEntries.indexWhere((e) => e.key == entry.key);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colour.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Opacity(
                    opacity: isDimmed ? 0.35 : 1.0,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colour.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(entry.key,
                              style: const TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: widget.textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${entry.value.length} khoản',
                                style: TextStyle(
                                  color: widget.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _activeMode == 'expense'
                                  ? '-${vndFormat.format(sum)}'
                                  : '+${vndFormat.format(sum)}',
                              style: TextStyle(
                                color: widget.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${percent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: colour,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );

    // ── Transaction list card (only when a category is selected) ──
    Widget? txCard;
    if (_selectedCategory != null && categoryMap[_selectedCategory] != null) {
      txCard = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  categoryMap[_selectedCategory]!.first.emoji ?? '',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  _categoryColours[_selectedCategory]?.label ?? 'Chi tiết',
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...categoryMap[_selectedCategory]!.map((e) {
              final info = _categoryColours[e.emoji ?? ''];
              final colour = info?.color ?? _otherColor;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colour.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.description.isEmpty
                            ? 'Không có mô tả'
                            : e.description,
                        style: TextStyle(color: widget.textColor, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _activeMode == 'expense'
                          ? '-${vndFormat.format(e.amountVnd.abs())}'
                          : '+${vndFormat.format(e.amountVnd.abs())}',
                      style: TextStyle(
                        color: _activeMode == 'expense'
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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

    return SingleChildScrollView(
      child: Column(
        children: [
          mainCard,
          if (txCard != null) ...[
            const SizedBox(height: 12),
            txCard,
          ],
          // Extra bottom padding so content doesn't stick to edge
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode toggle
// ---------------------------------------------------------------------------
class _ModeToggle extends StatelessWidget {
  final String activeMode;
  final Color textColor;
  final ValueChanged<String> onChanged;

  const _ModeToggle({
    required this.activeMode,
    required this.textColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: textColor.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            label: 'Expense',
            icon: LucideIcons.arrowDown,
            activeColor: Colors.red,
            isActive: activeMode == 'expense',
            onTap: () => onChanged('expense'),
          ),
          const SizedBox(width: 4),
          _ModeButton(
            label: 'Income',
            icon: LucideIcons.arrowUp,
            activeColor: Colors.green,
            isActive: activeMode == 'income',
            onTap: () => onChanged('income'),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color activeColor;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : activeColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : activeColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard summary card
// ---------------------------------------------------------------------------
class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color bg;
  final Color textColor;
  final Color muted;

  const _DashboardCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.bg,
    required this.textColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading placeholder
// ---------------------------------------------------------------------------
class _SummaryLoading extends StatelessWidget {
  const _SummaryLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
