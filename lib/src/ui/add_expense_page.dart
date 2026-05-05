import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mix/mix.dart';

import '../data/image_storage.dart';
import '../data/models/expense.dart';
import '../data/providers.dart';
import 'formatters.dart';
import 'mix_tokens.dart';

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage(
      {super.key, this.onEditingChanged, this.onShowDashboard});

  final ValueChanged<bool>? onEditingChanged;
  final VoidCallback? onShowDashboard;

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage>
    with WidgetsBindingObserver {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _picker = ImagePicker();

  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _activeCameraIndex = 0;
  bool _cameraReady = false;
  bool _cameraFailed = false;
  bool _capturing = false;
  bool _flashOn = false;

  XFile? _picked;
  String? _emoji;
  bool _saving = false;

  // Detail modal state
  bool _showDetailModal = false;
  bool _isExpense = true;
  int _detailTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _camera;
    if (controller == null) return;
    if (!controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameraReady = false;
      _cameraFailed = false;
      if (mounted) setState(() {});

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _cameraFailed = true;
        if (mounted) setState(() {});
        return;
      }

      final description = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _activeCameraIndex = _cameras.indexOf(description);
      await _startCamera(description);
    } catch (_) {
      _cameraFailed = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _startCamera(CameraDescription description) async {
    try {
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await _camera?.dispose();
      _camera = controller;
      _cameraReady = true;

      if (_flashOn) {
        try {
          await controller.setFlashMode(FlashMode.torch);
        } catch (_) {
          _flashOn = false;
        }
      }

      setState(() {});
    } catch (_) {
      _cameraFailed = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _camera;
    if (controller == null || !_cameraReady) return;

    final next = !_flashOn;
    setState(() => _flashOn = next);
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      if (mounted) setState(() => _flashOn = false);
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.isEmpty) return;
    final nextIndex = (_activeCameraIndex + 1) % _cameras.length;
    _activeCameraIndex = nextIndex;
    await _startCamera(_cameras[nextIndex]);
  }

  Future<void> _setZoom1x() async {
    final controller = _camera;
    if (controller == null || !_cameraReady) return;
    try {
      await controller.setZoomLevel(1.0);
    } catch (_) {
      // Ignore if unsupported.
    }
  }

  Future<void> _pickGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (file == null) return;
    setState(() {
      _picked = file;
      _showDetailModal = true;
    });
    widget.onEditingChanged?.call(true);
  }

  Future<void> _capture() async {
    final controller = _camera;
    if (controller == null || !_cameraReady || _capturing) return;
    if (_saving) return;

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      setState(() {
        _picked = file;
        _showDetailModal = true;
      });
      widget.onEditingChanged?.call(true);
    } catch (_) {
      // Keep user on camera preview.
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _openNoImageDetail() {
    setState(() {
      _showDetailModal = true;
    });
    widget.onEditingChanged?.call(true);
  }

  void _closeDetailModal() {
    setState(() {
      _showDetailModal = false;
      _picked = null;
      _emoji = null;
      _amountController.clear();
      _descController.clear();
      _isExpense = true;
      _detailTabIndex = 0;
    });
    widget.onEditingChanged?.call(false);
  }

  Future<void> _save() async {
    final isar = await ref.read(isarProvider.future);
    final amountRaw = _amountController.text;
    final parsed = parseVndInput(amountRaw);
    if (parsed == null || parsed == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập số tiền hợp lệ (vd: 30,000)')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? savedPath;
      if (_picked != null) {
        const storage = ImageStorage();
        savedPath = await storage.saveCompressedExpenseImage(
          sourcePath: _picked!.path,
          fileNameBase: DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      final amount = _isExpense ? -(parsed.abs()) : parsed.abs();
      final expense = Expense()
        ..amountVnd = amount
        ..emoji = _emoji
        ..description = _descController.text.trim()
        ..imagePath = savedPath
        ..createdAt = DateTime.now();

      await isar.writeTxn(() => isar.expenses.put(expense));
      if (!mounted) return;

      _closeDetailModal();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm: ${vndFormat.format(amount.abs())}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraRadius = AppTokens.cameraRadius.resolve(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Stack(
        children: [
          // Background
          Positioned.fill(
            child: ColoredBox(color: AppTokens.bg.resolve(context)),
          ),
          // ── Camera mode (no detail modal) ──
          if (!_showDetailModal)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RoundIconButton(
                        tooltip: 'Crown',
                        icon: LucideIcons.crown,
                        iconColor: AppTokens.accent.resolve(context),
                        onTap: () {},
                      ),
                      _RoundIconButton(
                        tooltip: 'Settings',
                        icon: LucideIcons.settings,
                        iconColor: AppTokens.text.resolve(context),
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Camera area – square with border radius (Locket-style)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Square size = min of width and height
                        final squareSize = constraints.biggest.shortestSide;
                        return Center(
                          child: SizedBox(
                            width: squareSize,
                            height: squareSize,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTokens.surface.resolve(context),
                                borderRadius: BorderRadius.all(cameraRadius),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.all(cameraRadius),
                                child: Stack(
                                  children: [
                                    // Camera / captured image surface
                                    Positioned.fill(
                                      child: _CameraSurface(
                                        camera: _camera,
                                        cameraReady: _cameraReady,
                                        cameraFailed: _cameraFailed,
                                        captured: _picked,
                                      ),
                                    ),
                                    // "+" button at bottom-center (no-image mode)
                                    if (_picked == null)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 16,
                                        child: Center(
                                          child: GestureDetector(
                                            onTap: _saving
                                                ? null
                                                : _openNoImageDetail,
                                            child: Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: AppTokens.accent
                                                    .resolve(context)
                                                    .withOpacity(0.9),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                LucideIcons.plus,
                                                size: 22,
                                                color: AppTokens.text
                                                    .resolve(context),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Side controls at middle-right (vertical column)
                                    if (_picked == null)
                                      Positioned(
                                        right: 12,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _SmallControlButton(
                                                tooltip: '1x',
                                                icon: Icons.filter_1_outlined,
                                                onTap: _setZoom1x,
                                              ),
                                              const SizedBox(height: 10),
                                              _SmallControlButton(
                                                tooltip: 'Flash',
                                                icon: _flashOn
                                                    ? LucideIcons.zap
                                                    : LucideIcons.zapOff,
                                                onTap: _toggleFlash,
                                              ),
                                              const SizedBox(height: 10),
                                              _SmallControlButton(
                                                tooltip: 'Flip',
                                                icon: LucideIcons.refreshCw,
                                                onTap: _flipCamera,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    // Expense/Income switch at bottom-center on captured image
                                    if (_picked != null)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 12,
                                        child: Center(
                                          child: _CaptureTypeSwitch(
                                            isExpense: _isExpense,
                                            onToggle: (v) =>
                                                setState(() => _isExpense = v),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Bottom capture row
                  _BottomCaptureRow(
                    enabled: !_saving,
                    capturing: _capturing,
                    hasCaptured: _picked != null,
                    onGallery: _pickGallery,
                    onShutter: _capture,
                    onMic: () {},
                  ),
                ],
              ),
            ),
          // ── Edit mode (detail modal shown) ──
          if (_showDetailModal)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Top bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RoundIconButton(
                          tooltip: 'Close',
                          icon: LucideIcons.x,
                          iconColor: AppTokens.text.resolve(context),
                          onTap: _saving ? () {} : _closeDetailModal,
                        ),
                        Text(
                          'Add transaction',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTokens.text.resolve(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        _RoundIconButton(
                          tooltip: 'Save image',
                          icon: LucideIcons.download,
                          iconColor: AppTokens.text.resolve(context),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Đã lưu ảnh về máy')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Camera frame with captured image (same size as camera mode)
                    SizedBox(
                      width: screenWidth - 32,
                      height: screenWidth - 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTokens.surface.resolve(context),
                          borderRadius: BorderRadius.all(cameraRadius),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(cameraRadius),
                          child: Stack(
                            children: [
                              // Image or placeholder
                              Positioned.fill(
                                child: _picked != null
                                    ? Image.file(
                                        File(_picked!.path),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      )
                                    : ColoredBox(
                                        color:
                                            AppTokens.surface.resolve(context),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                LucideIcons.image,
                                                color: AppTokens.muted
                                                    .resolve(context),
                                                size: 32,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'No image',
                                                style: TextStyle(
                                                  color: AppTokens.muted
                                                      .resolve(context),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                              // Expense/Income switch at bottom-center
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 12,
                                child: Center(
                                  child: _CaptureTypeSwitch(
                                    isExpense: _isExpense,
                                    onToggle: (v) =>
                                        setState(() => _isExpense = v),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ── Editor panel ──
                    _DetailEditorPanel(
                      saving: _saving,
                      emoji: _emoji,
                      onEmojiChanged: (v) => setState(() => _emoji = v),
                      amountController: _amountController,
                      descController: _descController,
                      tabIndex: _detailTabIndex,
                      onTabChanged: (v) => setState(() => _detailTabIndex = v),
                      onSave: _save,
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

/// ---------------------------------------------------------------------------
/// Expense/Income switch overlay – shown on the captured image
/// Red for expense, green for income (Locket-style)
/// ---------------------------------------------------------------------------
class _CaptureTypeSwitch extends StatelessWidget {
  const _CaptureTypeSwitch({
    required this.isExpense,
    required this.onToggle,
  });

  final bool isExpense;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!isExpense),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypePill(
              label: 'Expense',
              icon: LucideIcons.arrowDown,
              selected: isExpense,
              activeColor: Colors.redAccent,
            ),
            const SizedBox(width: 4),
            _TypePill(
              label: 'Income',
              icon: LucideIcons.arrowUp,
              selected: !isExpense,
              activeColor: Colors.greenAccent,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Detail Editor Panel – compact transaction editor below the camera frame
/// ---------------------------------------------------------------------------
class _DetailEditorPanel extends StatelessWidget {
  const _DetailEditorPanel({
    required this.saving,
    required this.emoji,
    required this.onEmojiChanged,
    required this.amountController,
    required this.descController,
    required this.tabIndex,
    required this.onTabChanged,
    required this.onSave,
  });

  final bool saving;
  final String? emoji;
  final ValueChanged<String?> onEmojiChanged;
  final TextEditingController amountController;
  final TextEditingController descController;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.accent.resolve(context);
    final textColor = AppTokens.text.resolve(context);

    return Column(
      children: [
        // ── Category picker ──
        _CategoryPicker(
          enabled: !saving,
          value: emoji,
          onChanged: onEmojiChanged,
        ),
        const SizedBox(height: 12),
        // ── Tab bar: Amount | Description ──
        Row(
          children: [
            _TabButton(
              label: 'Amount',
              selected: tabIndex == 0,
              onTap: () => onTabChanged(0),
            ),
            const SizedBox(width: 8),
            _TabButton(
              label: 'Description',
              selected: tabIndex == 1,
              onTap: () => onTabChanged(1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ── Tab content ──
        SizedBox(
          height: 140,
          child: tabIndex == 0
              ? _AmountTab(controller: amountController, enabled: !saving)
              : _DescriptionTab(controller: descController, enabled: !saving),
        ),
        const SizedBox(height: 12),
        // ── Save button ──
        Pressable(
          enabled: !saving,
          onPress: saving ? null : onSave,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Save transaction',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Category picker – horizontal scrollable chips
/// ---------------------------------------------------------------------------
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final String? value;
  final ValueChanged<String?> onChanged;

  static const _options = <(String emoji, String label)>[
    ('🍜', 'Food'),
    ('🥤', 'Drink'),
    ('🛒', 'Shopping'),
    ('🚕', 'Transport'),
    ('🏠', 'Home'),
    ('💊', 'Health'),
    ('🎮', 'Entertainment'),
    ('🧾', 'Bills'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.accent.resolve(context);
    final surface2 = AppTokens.surface2.resolve(context);
    final textColor = AppTokens.text.resolve(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            color: AppTokens.muted.resolve(context),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final opt = _options[index];
              final selected = value == opt.$1;
              return GestureDetector(
                onTap: enabled ? () => onChanged(opt.$1) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected ? accent : surface2,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        selected ? Border.all(color: accent, width: 1.5) : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(opt.$1, style: const TextStyle(fontSize: 16)),
                      if (selected) ...[
                        const SizedBox(width: 4),
                        Text(
                          opt.$2,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Tab button
/// ---------------------------------------------------------------------------
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.accent.resolve(context);
    final textColor = AppTokens.text.resolve(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Amount tab content
/// ---------------------------------------------------------------------------
class _AmountTab extends StatefulWidget {
  const _AmountTab({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  State<_AmountTab> createState() => _AmountTabState();
}

class _AmountTabState extends State<_AmountTab> {
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onAmountChanged);
    super.dispose();
  }

  void _onAmountChanged() {
    if (_isUpdating) return;
    _isUpdating = true;

    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    final formatted = formatVndComma(text);
    if (formatted != text) {
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(
          offset: formatted.length -
              (text.length - cursorPos).clamp(0, formatted.length),
        ),
      );
    }

    _isUpdating = false;
  }

  @override
  Widget build(BuildContext context) {
    final surface2 = AppTokens.surface2.resolve(context);
    final textColor = AppTokens.text.resolve(context);
    final muted = AppTokens.muted.resolve(context);
    final accent = AppTokens.accent.resolve(context);

    return Container(
      decoration: BoxDecoration(
        color: surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Amount',
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'VND',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: textColor,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: '0',
              hintStyle: TextStyle(
                color: muted.withOpacity(0.4),
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Description tab content
/// ---------------------------------------------------------------------------
class _DescriptionTab extends StatelessWidget {
  const _DescriptionTab({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final surface2 = AppTokens.surface2.resolve(context);
    final textColor = AppTokens.text.resolve(context);
    final muted = AppTokens.muted.resolve(context);

    return Container(
      decoration: BoxDecoration(
        color: surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Description',
            style: TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            enabled: enabled,
            maxLines: 4,
            minLines: 1,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: 'Enter description...',
              hintStyle: TextStyle(
                color: muted.withOpacity(0.4),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Small control button (zoom, flash, flip)
/// ---------------------------------------------------------------------------
class _SmallControlButton extends StatelessWidget {
  const _SmallControlButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onPress: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTokens.surface2.resolve(context).withOpacity(0.85),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTokens.text.resolve(context), size: 18),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Round icon button (top bar)
/// ---------------------------------------------------------------------------
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onPress: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTokens.surface2.resolve(context),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor ?? AppTokens.text.resolve(context),
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Bottom capture row
/// ---------------------------------------------------------------------------
class _BottomCaptureRow extends StatelessWidget {
  const _BottomCaptureRow({
    required this.enabled,
    required this.capturing,
    required this.hasCaptured,
    required this.onGallery,
    required this.onShutter,
    required this.onMic,
  });

  final bool enabled;
  final bool capturing;
  final bool hasCaptured;
  final VoidCallback onGallery;
  final VoidCallback onShutter;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final muted = AppTokens.muted.resolve(context);
    final accent = AppTokens.accent.resolve(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Gallery',
          onPressed: enabled ? onGallery : null,
          icon: Icon(LucideIcons.image, color: muted, size: 28),
        ),
        GestureDetector(
          onTap: (!enabled || capturing || hasCaptured) ? null : onShutter,
          child: Container(
            width: 86,
            height: 86,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 5),
            ),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: capturing
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: accent,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Microphone',
          onPressed: enabled ? onMic : null,
          icon: Icon(LucideIcons.mic, color: muted, size: 28),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Camera surface
/// ---------------------------------------------------------------------------
class _CameraSurface extends StatelessWidget {
  const _CameraSurface({
    required this.camera,
    required this.cameraReady,
    required this.cameraFailed,
    required this.captured,
  });

  final CameraController? camera;
  final bool cameraReady;
  final bool cameraFailed;
  final XFile? captured;

  @override
  Widget build(BuildContext context) {
    if (captured != null) {
      return ColoredBox(
        color: AppTokens.bg.resolve(context),
        child: Image.file(
          File(captured!.path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    if (cameraFailed) {
      return ColoredBox(
        color: AppTokens.bg.resolve(context),
        child: Center(
          child: Text(
            'Không mở được camera.\nBạn có thể upload ảnh từ máy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTokens.text.resolve(context)),
          ),
        ),
      );
    }

    if (!cameraReady || camera == null) {
      return ColoredBox(
        color: AppTokens.bg.resolve(context),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: AppTokens.bg.resolve(context),
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: camera!.value.previewSize?.height ?? 720,
          height: camera!.value.previewSize?.width ?? 1280,
          child: CameraPreview(camera!),
        ),
      ),
    );
  }
}
