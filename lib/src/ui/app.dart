import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mix/mix.dart';

import 'add_expense_page.dart';
import 'calendar_page.dart';
import 'dashboard_page.dart';
import 'mix_tokens.dart';
import 'wallet_page.dart';

class ThayPayApp extends StatefulWidget {
  const ThayPayApp({super.key});

  @override
  State<ThayPayApp> createState() => _ThayPayAppState();
}

class _ThayPayAppState extends State<ThayPayApp> {
  int index = 1;
  bool _isEditing = false;
  final _homePageController = PageController(initialPage: 0);
  int _homePageIndex = 0; // 0 = AddExpense, 1 = Dashboard

  @override
  void dispose() {
    _homePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show bottom nav (plus Stats pill) when not editing
    final showBottom = !_isEditing;

    return MixTheme(
      data: buildAppMixTheme(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ThayPay',
        theme: buildAppTheme(),
        home: Scaffold(
          body: Stack(
            children: [
              // ── Main page area (3 tabs via IndexedStack) ──
              IndexedStack(
                index: index,
                children: [
                  const CalendarPage(),
                  // Home tab uses a vertical PageView for TikTok-style scroll
                  _HomePageView(
                    controller: _homePageController,
                    onPageChanged: (i) => setState(() => _homePageIndex = i),
                    onEditingChanged: (v) => setState(() => _isEditing = v),
                  ),
                  const WalletPage(),
                ],
              ),
              // ── Stats pill – fades out as user scrolls to Dashboard ──
              if (showBottom && index == 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 120,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _homePageIndex == 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _homePageIndex != 0,
                        child: _StatsPill(
                          onTap: () => _homePageController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: showBottom
              ? _BottomArea(index: index, onChanged: _onNavChanged)
              : null,
        ),
      ),
    );
  }

  void _onNavChanged(int value) {
    setState(() {
      index = value;
      // Reset Home vertical scroll to AddExpense when returning
      if (value == 1) {
        _homePageIndex = 0;
        _homePageController.jumpToPage(0);
      }
    });
  }
}

/// Vertical PageView between AddExpense (page 0) and Dashboard (page 1)
class _HomePageView extends StatelessWidget {
  const _HomePageView({
    required this.controller,
    required this.onPageChanged,
    required this.onEditingChanged,
  });

  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<bool> onEditingChanged;

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: controller,
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      onPageChanged: onPageChanged,
      children: [
        AddExpensePage(onEditingChanged: onEditingChanged),
        const DashboardPage(),
      ],
    );
  }
}

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: _BottomNavBar(index: index, onChanged: onChanged),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.surface2.resolve(context),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            tooltip: 'Calendar',
            selected: index == 0,
            icon: LucideIcons.calendarDays,
            onTap: () => onChanged(0),
          ),
          _NavItem(
            tooltip: 'Add',
            selected: index == 1,
            icon: index == 1 ? LucideIcons.house : LucideIcons.plus,
            onTap: () => onChanged(1),
          ),
          _NavItem(
            tooltip: 'Wallet',
            selected: index == 2,
            icon: LucideIcons.wallet,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _StatsPill extends StatelessWidget {
  const _StatsPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPress: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppTokens.surface2.resolve(context),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.chartBar,
              size: 18,
              color: AppTokens.text.resolve(context),
            ),
            const SizedBox(width: 10),
            Text(
              'Stats',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTokens.text.resolve(context),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tooltip,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? AppTokens.surface.resolve(context) : Colors.transparent;

    final fg = selected
        ? AppTokens.accent.resolve(context)
        : AppTokens.muted.resolve(context);

    return Tooltip(
      message: tooltip,
      child: Pressable(
        onPress: onTap,
        child: Container(
          width: 72,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, color: fg, size: 24),
        ),
      ),
    );
  }
}
