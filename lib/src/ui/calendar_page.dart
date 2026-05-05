import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/models/expense.dart';
import '../features/monthly_expenses.dart';
import 'formatters.dart';
import 'mix_tokens.dart';

/// ---------------------------------------------------------------------------
/// Calendar page – scrollable vertical list of months (Locket-style)
/// Shows 2 years back, 3 months forward. Current month centered on load.
/// ---------------------------------------------------------------------------
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  final _scrollController = ScrollController();

  /// All months from 2 years ago to 3 months from now.
  late final List<DateTime> _months;

  /// Index of the current month in [_months].
  late final int _currentMonthIndex;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    _months = _generateMonths(current);
    _currentMonthIndex = _months.indexOf(current);

    // Scroll to current month after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentMonth();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<DateTime> _generateMonths(DateTime current) {
    final months = <DateTime>[];
    // 2 years back
    for (int i = 24; i >= 1; i--) {
      months.add(DateTime(current.year, current.month - i));
    }
    // Current month
    months.add(current);
    // 3 months forward
    for (int i = 1; i <= 3; i++) {
      months.add(DateTime(current.year, current.month + i));
    }
    return months;
  }

  void _scrollToCurrentMonth() {
    if (!_scrollController.hasClients) return;
    // Use itemExtent approach: each month card ~480px + 24px bottom padding
    const estimatedItemHeight = 504.0;
    final offset = _currentMonthIndex * estimatedItemHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final target = (offset - viewportHeight * 0.15)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  void _onDayTap(DateTime day, List<Expense> expenses) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.6),
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => _DayDetailPage(
          day: day,
          expenses: expenses,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          return SlideTransition(position: slide, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  /// Get the latest image from a list of expenses (prefer most recent with image).
  String? _latestImage(List<Expense> exps) {
    for (final e in exps) {
      if (e.imagePath != null && e.imagePath!.isNotEmpty) return e.imagePath;
    }
    return null;
  }

  /// Calculate net total for a list of expenses (income - expense).
  int _netTotal(List<Expense> exps) {
    return exps.fold<int>(0, (acc, e) => acc + e.amountVnd);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Main scrollable content
          expensesAsyncBuilder(
            context,
            (items) => NotificationListener<ScrollNotification>(
              onNotification: (_) => false,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: _months.length,
                itemBuilder: (context, index) {
                  final month = _months[index];
                  final isCurrent = index == _currentMonthIndex;
                  return _MonthCard(
                    month: month,
                    allExpenses: items,
                    isCurrent: isCurrent,
                    selectedDay: null,
                    onDayTap: _onDayTap,
                    latestImage: _latestImage,
                    netTotal: _netTotal,
                  );
                },
              ),
            ),
          ),

          // No overlay needed – detail opens as full-screen page

          // ── Header with centered "Calendar" title ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTokens.bg.resolve(context),
                    AppTokens.bg.resolve(context).withOpacity(0),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  'Calendar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTokens.text.resolve(context),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to build the async expenses stream.
  Widget expensesAsyncBuilder(
      BuildContext context, Widget Function(List<Expense>) builder) {
    return ref.watch(calendarRangeExpensesProvider).when(
          data: builder,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Lỗi tải dữ liệu: $e',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTokens.muted.resolve(context)),
            ),
          ),
        );
  }
}

/// ---------------------------------------------------------------------------
/// Month card – header + calendar grid for one month
/// with glass/glossy background and per-month expense/income switch
/// ---------------------------------------------------------------------------
class _MonthCard extends StatefulWidget {
  const _MonthCard({
    required this.month,
    required this.allExpenses,
    required this.isCurrent,
    required this.selectedDay,
    required this.onDayTap,
    required this.latestImage,
    required this.netTotal,
  });

  final DateTime month;
  final List<Expense> allExpenses;
  final bool isCurrent;
  final DateTime? selectedDay;
  final void Function(DateTime day, List<Expense> expenses) onDayTap;
  final String? Function(List<Expense>) latestImage;
  final int Function(List<Expense>) netTotal;

  @override
  State<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<_MonthCard> {
  /// null = show all, true = income only, false = expense only
  bool? _filterType;

  @override
  Widget build(BuildContext context) {
    final textColor = AppTokens.text.resolve(context);
    final muted = AppTokens.muted.resolve(context);
    final surface2 = AppTokens.surface2.resolve(context);
    final accent = AppTokens.accent.resolve(context);

    // Filter expenses for this month
    final monthExpenses = widget.allExpenses.where((e) {
      return e.createdAt.year == widget.month.year &&
          e.createdAt.month == widget.month.month;
    }).toList();

    // Apply income/expense filter
    final filteredExpenses = monthExpenses.where((e) {
      if (_filterType == null) return true;
      if (_filterType == true) return e.amountVnd > 0; // income
      return e.amountVnd < 0; // expense
    }).toList();

    int totalExpense = 0;
    int totalIncome = 0;
    for (final e in monthExpenses) {
      if (e.amountVnd < 0) {
        totalExpense += e.amountVnd;
      } else {
        totalIncome += e.amountVnd;
      }
    }
    
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    // Group by day
    final Map<int, List<Expense>> dayExpenses = {};
    for (final e in filteredExpenses) {
      final day = e.createdAt.day;
      (dayExpenses[day] ??= []).add(e);
    }

    // Calendar calculations
    final firstDay = DateTime(widget.month.year, widget.month.month, 1);
    final lastDay = DateTime(widget.month.year, widget.month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday % 7; // Sunday = 0

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isCurrent
              ? const Color(0xFF1E2130)
              : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(widget.isCurrent ? 0.12 : 0.05),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Month header ──
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: Text(
                        DateFormat('MMMM yyyy').format(widget.month),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: widget.isCurrent ? accent : textColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                  // ── Expense/Income Summary & Filter ──
                  Row(
                    children: [
                      // Expense Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _filterType = _filterType == false ? null : false;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: _filterType == false || _filterType == null
                                  ? const Color(0xFFE55A5A).withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _filterType == false || _filterType == null 
                                        ? const Color(0xFF301010) // Very dark red like image
                                        : Colors.white.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    LucideIcons.arrowUpRight,
                                    size: 20,
                                    color: _filterType == false || _filterType == null 
                                        ? const Color(0xFFE55A5A) // Red accent
                                        : muted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Texts
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Expenses',
                                        style: TextStyle(
                                          color: _filterType == false || _filterType == null 
                                              ? Colors.white 
                                              : muted,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        currencyFmt.format(totalExpense).replaceAll(' ', ''),
                                        style: TextStyle(
                                          color: _filterType == false || _filterType == null 
                                              ? const Color(0xFFE55A5A)
                                              : muted.withOpacity(0.5),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Income Button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _filterType = _filterType == true ? null : true;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: _filterType == true || _filterType == null
                                  ? Colors.greenAccent.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _filterType == true || _filterType == null 
                                        ? Colors.greenAccent.withOpacity(0.15) 
                                        : Colors.white.withOpacity(0.03),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    LucideIcons.arrowDownRight,
                                    size: 20,
                                    color: _filterType == true || _filterType == null 
                                        ? Colors.greenAccent 
                                        : muted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Texts
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Income',
                                        style: TextStyle(
                                          color: _filterType == true || _filterType == null 
                                              ? Colors.white 
                                              : muted,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '+${currencyFmt.format(totalIncome).replaceAll(' ', '').replaceAll('đ', '')}đ',
                                        style: TextStyle(
                                          color: _filterType == true || _filterType == null 
                                              ? Colors.greenAccent 
                                              : muted.withOpacity(0.5),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Weekday headers ──
                  Row(
                    children: weekdays.map((d) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  // ── Day grid ──
                  ...List.generate(_weekCount(firstDay, lastDay), (weekIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: Row(
                        children: List.generate(7, (weekdayIndex) {
                          final dayNumber =
                              weekIndex * 7 + weekdayIndex - startWeekday + 1;
                          if (dayNumber < 1 || dayNumber > daysInMonth) {
                            return const Expanded(child: SizedBox(height: 76));
                          }

                          final date = DateTime(
                            widget.month.year,
                            widget.month.month,
                            dayNumber,
                          );
                          final isToday = date == todayDate;
                          final isSelected = widget.selectedDay == date;
                          final dayExps = dayExpenses[dayNumber] ?? [];
                          final hasExpenses = dayExps.isNotEmpty;
                          final img =
                              hasExpenses ? widget.latestImage(dayExps) : null;
                          final net =
                              hasExpenses ? widget.netTotal(dayExps) : 0;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onDayTap(date, dayExps),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 76,
                                margin: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Row 1: Image thumbnail or "+" button with count badge
                                    SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          hasExpenses && img != null
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.file(
                                                    File(img),
                                                    width: 36,
                                                    height: 36,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) =>
                                                        _emptyPlusIcon(
                                                      isToday && hasExpenses
                                                          ? accent
                                                          : muted,
                                                      isSelected: isSelected,
                                                      accentColor: accent,
                                                    ),
                                                  ),
                                                )
                                              : _emptyPlusIcon(
                                                  isToday && hasExpenses
                                                      ? accent
                                                      : muted,
                                                  isSelected: isSelected,
                                                  accentColor: accent,
                                                ),
                                          if (hasExpenses)
                                            Positioned(
                                              top: -4,
                                              right: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                constraints: const BoxConstraints(
                                                  minWidth: 16,
                                                  minHeight: 16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent.shade200,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${dayExps.length}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      height: 1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Row 2: Day number
                                    Text(
                                      '$dayNumber',
                                      style: TextStyle(
                                        color: isToday || isSelected
                                            ? accent
                                            : textColor,
                                        fontSize: 14,
                                        fontWeight: isToday || isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    // Row 3: Net total
                                    if (hasExpenses)
                                      Text(
                                        _formatNet(net),
                                        style: TextStyle(
                                          color: net >= 0
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),
      ),
    );
  }

  Widget _emptyPlusIcon(Color iconColor, {bool isSelected = false, Color? accentColor}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isSelected && accentColor != null 
            ? accentColor.withOpacity(0.3) 
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(LucideIcons.plus, size: 18, color: isSelected && accentColor != null ? accentColor : iconColor),
    );
  }

  String _formatNet(int net) {
    if (net == 0) return '0';
    final abs = net.abs();
    if (abs >= 1000000) {
      return '${net >= 0 ? '+' : ''}${(abs / 1000000).toStringAsFixed(1)}M';
    }
    if (abs >= 1000) {
      return '${net >= 0 ? '+' : ''}${(abs / 1000).toStringAsFixed(0)}k';
    }
    return '${net >= 0 ? '+' : ''}$abs';
  }

  int _weekCount(DateTime firstDay, DateTime lastDay) {
    final start = firstDay.weekday % 7;
    final totalCells = start + lastDay.day;
    return (totalCells / 7).ceil();
  }
}

/// ---------------------------------------------------------------------------
/// Day detail page – full-screen page for selected day transactions
/// ---------------------------------------------------------------------------
class _DayDetailPage extends StatefulWidget {
  const _DayDetailPage({
    required this.day,
    required this.expenses,
  });

  final DateTime day;
  final List<Expense> expenses;

  @override
  State<_DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<_DayDetailPage> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppTokens.text.resolve(context);
    final muted = AppTokens.muted.resolve(context);

    final totalNet = widget.expenses.fold<int>(0, (s, e) => s + e.amountVnd);
    final isNetIncome = totalNet >= 0;
    final netColor = isNetIncome ? Colors.greenAccent : Colors.redAccent;
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(LucideIcons.chevronLeft, color: textColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Date icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(widget.day),
                          style: TextStyle(
                            color: AppTokens.accent.resolve(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(widget.day).toUpperCase(),
                          style: TextStyle(
                            color: muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Date text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(widget.day),
                          style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          DateFormat('dd MMMM yyyy').format(widget.day),
                          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  // Net total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isNetIncome ? 'Tổng thu' : 'Tổng chi',
                        style: TextStyle(color: muted, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isNetIncome ? '+' : ''}${fmt.format(totalNet).replaceAll(' ', '')}',
                        style: TextStyle(color: netColor, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white.withOpacity(0.06),
            ),
            const SizedBox(height: 12),

            // ── Transaction count + page dots ──
            if (widget.expenses.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.expenses.length} giao dịch',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(widget.expenses.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _currentPage ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: i == _currentPage
                                ? AppTokens.accent.resolve(context)
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            if (widget.expenses.length > 1) const SizedBox(height: 12),

            // ── Transaction cards (fills remaining space) ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: widget.expenses.length == 1
                    ? _TransactionCard(expense: widget.expenses.first)
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: widget.expenses.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (context, index) {
                          return _TransactionCard(
                            expense: widget.expenses[index],
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
/// Transaction card – Locket-style: full-width square image + info below
/// ---------------------------------------------------------------------------
class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final muted = AppTokens.muted.resolve(context);
    final textColor = AppTokens.text.resolve(context);
    final isIncome = expense.amountVnd > 0;
    final amtColor = isIncome ? Colors.greenAccent : Colors.redAccent;
    final hasImage = expense.imagePath != null && expense.imagePath!.isNotEmpty;

    // Fixed square image size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth - 32; // padding 16 each side

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Square image (Locket-style, fixed size) ──
        if (hasImage) ...
          [
            SizedBox(
              width: imageSize,
              height: imageSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(expense.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: amtColor.withOpacity(0.08),
                        child: Center(child: Icon(LucideIcons.imageOff, color: muted, size: 40)),
                      ),
                    ),
                    // Type badge top-left
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: amtColor.withOpacity(0.5), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isIncome ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight, size: 11, color: amtColor),
                            const SizedBox(width: 5),
                            Text(isIncome ? 'Income' : 'Expense',
                                style: TextStyle(color: amtColor, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    // Time top-right
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(DateFormat('HH:mm').format(expense.createdAt),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]
        else ...
          [
            // No image – centered amount card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: amtColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: amtColor.withOpacity(0.2), width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: amtColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: amtColor.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isIncome ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight, size: 13, color: amtColor),
                        const SizedBox(width: 6),
                        Text(isIncome ? 'Income' : 'Expense',
                            style: TextStyle(color: amtColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (expense.emoji != null && expense.emoji!.isNotEmpty) ...[
                    Text(expense.emoji!, style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    '${isIncome ? '+' : '-'}${vndFormat.format(expense.amountVnd.abs())}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: amtColor, fontSize: 32, fontWeight: FontWeight.w800, height: 1),
                  ),
                  const SizedBox(height: 6),
                  Text(DateFormat('HH:mm').format(expense.createdAt),
                      style: TextStyle(color: muted, fontSize: 13)),
                ],
              ),
            ),
          ],

        // ── Amount pill below image (centered) ──
        if (hasImage)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: amtColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: amtColor.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (expense.emoji != null && expense.emoji!.isNotEmpty) ...[
                    Text(expense.emoji!, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    '${isIncome ? '+' : '-'}${vndFormat.format(expense.amountVnd.abs())}',
                    style: TextStyle(
                      color: amtColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Description ──
        if (expense.description.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.messageCircle, size: 15, color: muted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    expense.description,
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 15,
                      height: 1.55,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }
}
