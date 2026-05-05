import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/models/bank_qr.dart';
import '../data/providers.dart';
import 'mix_tokens.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final allBankQrsProvider = StreamProvider<List<BankQr>>((ref) {
  final repo = ref.watch(bankQrRepositoryProvider);
  return repo.watchAll();
});

// ---------------------------------------------------------------------------
// Wallet / QR Bank page
// ---------------------------------------------------------------------------
class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  bool _isGridMode = false;

  @override
  Widget build(BuildContext context) {
    final textColor = AppTokens.text.resolve(context);
    final muted = AppTokens.muted.resolve(context);
    final accent = AppTokens.accent.resolve(context);
    final qrsAsync = ref.watch(allBankQrsProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ví QR',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quản lý mã QR ngân hàng',
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle + Add buttons
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isGridMode = !_isGridMode),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Icon(
                          _isGridMode ? LucideIcons.list : LucideIcons.layoutGrid,
                          color: textColor,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _showAddSheet(context, ref),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(LucideIcons.plus, color: Colors.black, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── List / Grid ──
          Expanded(
            child: qrsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyState(onAdd: () => _showAddSheet(context, ref));
                }
                if (_isGridMode) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final qr = items[index];
                      return _BankQrIconTile(
                        bankQr: qr,
                        onTap: () => _showDetailPage(context, ref, qr),
                        onDelete: () => _confirmDelete(context, ref, qr),
                      );
                    },
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final qr = items[index];
                    return _BankQrRow(
                      bankQr: qr,
                      onTap: () => _showDetailPage(context, ref, qr),
                      onDelete: () => _confirmDelete(context, ref, qr),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Lỗi: $e', style: TextStyle(color: muted)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BankQrFormSheet(),
    );
  }

  void _showDetailPage(BuildContext context, WidgetRef ref, BankQr bankQr) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _QrDetailPage(bankQr: bankQr, ref: ref),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BankQr bankQr) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Xóa QR?',
          style: TextStyle(
            color: AppTokens.text.resolve(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Mã QR "${bankQr.title}" sẽ bị xóa vĩnh viễn.',
          style: TextStyle(color: AppTokens.muted.resolve(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Hủy', style: TextStyle(color: AppTokens.muted.resolve(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(bankQrRepositoryProvider).delete(bankQr.id);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final muted = AppTokens.muted.resolve(context);
    final accent = AppTokens.accent.resolve(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.qrCode, size: 44, color: accent.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            'Chưa có mã QR nào',
            style: TextStyle(
              color: muted,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thêm mã QR ngân hàng để thanh toán nhanh',
            style: TextStyle(color: muted.withOpacity(0.5), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 18, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    'Thêm mã QR',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List row (logo + name only, no QR preview)
// ---------------------------------------------------------------------------
class _BankQrRow extends StatelessWidget {
  final BankQr bankQr;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BankQrRow({
    required this.bankQr,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppTokens.text.resolve(context);
    final muted = AppTokens.muted.resolve(context);
    final accent = AppTokens.accent.resolve(context);
    final hasLogo = bankQr.logoPath != null && File(bankQr.logoPath!).existsSync();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        child: Row(
          children: [
            // Logo avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: hasLogo ? Colors.transparent : muted.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasLogo
                  ? Image.file(File(bankQr.logoPath!), fit: BoxFit.cover)
                  : Icon(LucideIcons.banknote, size: 24, color: muted),
            ),
            const SizedBox(width: 14),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bankQr.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Nhấn để xem mã QR',
                    style: TextStyle(
                      color: muted.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Arrow
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.chevronRight, size: 16, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid icon tile (3-per-row, iPhone app style)
// ---------------------------------------------------------------------------
class _BankQrIconTile extends StatelessWidget {
  final BankQr bankQr;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BankQrIconTile({
    required this.bankQr,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppTokens.text.resolve(context);
    final muted = AppTokens.muted.resolve(context);
    final hasLogo = bankQr.logoPath != null && File(bankQr.logoPath!).existsSync();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App icon style logo
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: hasLogo ? Colors.transparent : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: hasLogo
                ? Image.file(File(bankQr.logoPath!), fit: BoxFit.cover)
                : Icon(LucideIcons.banknote, size: 28, color: muted),
          ),
          const SizedBox(height: 8),
          Text(
            bankQr.title,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}


class _QrDetailPage extends StatelessWidget {
  final BankQr bankQr;
  final WidgetRef ref;

  const _QrDetailPage({required this.bankQr, required this.ref});

  @override
  Widget build(BuildContext context) {
    final textColor = AppTokens.text.resolve(context);
    final muted = AppTokens.muted.resolve(context);
    final accent = AppTokens.accent.resolve(context);
    final hasQr = bankQr.qrImagePath != null && File(bankQr.qrImagePath!).existsSync();
    final hasLogo = bankQr.logoPath != null && File(bankQr.logoPath!).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: SafeArea(
        child: Column(
          children: [
            // ── Compact header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(LucideIcons.chevronLeft, color: textColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasLogo
                        ? Image.file(File(bankQr.logoPath!), fit: BoxFit.cover)
                        : Icon(LucideIcons.banknote, size: 18, color: muted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bankQr.title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1C1C1E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(
                            'Xóa QR?',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                          ),
                          content: Text(
                            'Mã QR "${bankQr.title}" sẽ bị xóa vĩnh viễn.',
                            style: TextStyle(color: muted),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Hủy', style: TextStyle(color: muted)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                                ref.read(bankQrRepositoryProvider).delete(bankQr.id);
                              },
                              child: const Text(
                                'Xóa',
                                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 17),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white.withOpacity(0.05)),
            const SizedBox(height: 10),

            // ── QR Image ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: hasQr
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 50,
                              spreadRadius: -8,
                              offset: const Offset(0, 16),
                            ),
                            BoxShadow(
                              color: accent.withOpacity(0.15),
                              blurRadius: 60,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.file(
                            File(bankQr.qrImagePath!),
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.qrCode, size: 80, color: muted.withOpacity(0.25)),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có ảnh QR',
                              style: TextStyle(color: muted.withOpacity(0.5), fontSize: 15),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // ── Bottom hint ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.scan, size: 14, color: muted.withOpacity(0.4)),
                  const SizedBox(width: 8),
                  Text(
                    'Hướng camera vào mã QR để thanh toán',
                    style: TextStyle(color: muted.withOpacity(0.4), fontSize: 12),
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

// ---------------------------------------------------------------------------
// Add / Edit form sheet
// ---------------------------------------------------------------------------
class _BankQrFormSheet extends ConsumerStatefulWidget {
  const _BankQrFormSheet();

  @override
  ConsumerState<_BankQrFormSheet> createState() => _BankQrFormSheetState();
}

class _BankQrFormSheetState extends ConsumerState<_BankQrFormSheet> {
  final _titleController = TextEditingController();
  final _picker = ImagePicker();
  String? _logoPath;
  String? _qrPath;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _logoPath = file.path);
  }

  Future<void> _pickQr() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _qrPath = file.path);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final bankQr = BankQr()
        ..title = title
        ..logoPath = _logoPath
        ..qrImagePath = _qrPath;
      await ref.read(bankQrRepositoryProvider).save(bankQr);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppTokens.text.resolve(context);
    final muted = AppTokens.muted.resolve(context);
    final accent = AppTokens.accent.resolve(context);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Thêm mã QR ngân hàng',
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nhập tên và chọn ảnh logo + ảnh QR',
            style: TextStyle(color: muted.withOpacity(0.6), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Bank name field
          TextField(
            controller: _titleController,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: 'Tên ngân hàng',
              labelStyle: TextStyle(color: muted.withOpacity(0.6), fontSize: 14),
              hintText: 'VD: Vietcombank, MB Bank...',
              hintStyle: TextStyle(color: muted.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              prefixIcon: Icon(LucideIcons.building2, size: 18, color: muted.withOpacity(0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Image pickers row
          Row(
            children: [
              // Logo picker
              Expanded(
                child: _ImagePickerTile(
                  label: 'Logo NH',
                  icon: LucideIcons.image,
                  imagePath: _logoPath,
                  accent: accent,
                  muted: muted,
                  onTap: _pickLogo,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              // QR picker
              Expanded(
                flex: 2,
                child: _ImagePickerTile(
                  label: 'Ảnh mã QR',
                  icon: LucideIcons.qrCode,
                  imagePath: _qrPath,
                  accent: accent,
                  muted: muted,
                  onTap: _pickQr,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Text(
                      'Lưu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable image picker tile
// ---------------------------------------------------------------------------
class _ImagePickerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? imagePath;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;
  final BoxFit fit;

  const _ImagePickerTile({
    required this.label,
    required this.icon,
    required this.imagePath,
    required this.accent,
    required this.muted,
    required this.onTap,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    final picked = imagePath != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 90,
        decoration: BoxDecoration(
          color: picked ? Colors.transparent : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: picked ? accent.withOpacity(0.6) : Colors.white.withOpacity(0.08),
            width: picked ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: picked
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(imagePath!), fit: fit),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.check, size: 10, color: Colors.black),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: muted.withOpacity(0.5)),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: muted.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
