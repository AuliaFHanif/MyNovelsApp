import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chapter.dart';
import '../../models/series.dart';
import '../../models/translation.dart';
import '../../services/pocketbase_service.dart';

// ─────────────────────────────────────────
//  Reader Theme
// ─────────────────────────────────────────

enum ReaderTheme { light, dark, sepia }

class _ThemeColors {
  final Color background;
  final Color surface;
  final Color text;
  final Color subtext;
  final Color divider;
  final Color icon;
  final Color accent;

  const _ThemeColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.subtext,
    required this.divider,
    required this.icon,
    required this.accent,
  });

  static const light = _ThemeColors(
    background: Color(0xFFF7F6F3),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF1A1A1A),
    subtext: Color(0xFF6B6B6B),
    divider: Color(0xFFE0DED8),
    icon: Color(0xFF555555),
    accent: Color(0xFF5B7FEC),
  );

  static const dark = _ThemeColors(
    background: Color(0xFF141414),
    surface: Color(0xFF1E1E1E),
    text: Color(0xFFE8E6E1),
    subtext: Color(0xFF8A8A8A),
    divider: Color(0xFF2C2C2C),
    icon: Color(0xFFAAAAAA),
    accent: Color(0xFF7B9FFF),
  );

  static const sepia = _ThemeColors(
    background: Color(0xFFF2E8D5),
    surface: Color(0xFFFAF3E4),
    text: Color(0xFF3B2F1E),
    subtext: Color(0xFF7A6548),
    divider: Color(0xFFD9C9A8),
    icon: Color(0xFF7A6548),
    accent: Color(0xFFB87D4B),
  );
}

// ─────────────────────────────────────────
//  Reader Screen
// ─────────────────────────────────────────

class ReaderScreen extends StatefulWidget {
  final Series series;
  final Chapter chapter;
  final Translation? translation;
  final List<Chapter> allChapters;

  const ReaderScreen({
    super.key,
    required this.series,
    required this.chapter,
    required this.translation,
    required this.allChapters,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  // ─── State ───
  late Chapter _currentChapter;
  Translation? _currentTranslation;
  bool _loadingTranslation = false;

  ReaderTheme _theme = ReaderTheme.light;
  double _fontSize = 18.0;
  double _lineHeight = 1.75;
  double _maxWidth = 680.0;
  bool _showOriginal = false;
  bool _settingsOpen = false;
  bool _headerVisible = true;

  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ─── Theme helpers ───
  _ThemeColors get _colors {
    switch (_theme) {
      case ReaderTheme.light:
        return _ThemeColors.light;
      case ReaderTheme.dark:
        return _ThemeColors.dark;
      case ReaderTheme.sepia:
        return _ThemeColors.sepia;
    }
  }

  String get _displayText {
    if (_showOriginal) return _currentChapter.sourceText;
    return _currentTranslation?.translatedText ?? _currentChapter.sourceText;
  }

  bool get _hasTranslation => _currentTranslation != null;
  bool get _hasPrev =>
      widget.allChapters
          .any((c) => c.chapterNumber < _currentChapter.chapterNumber);
  bool get _hasNext =>
      widget.allChapters
          .any((c) => c.chapterNumber > _currentChapter.chapterNumber);

  Chapter? get _prevChapter {
    final candidates = widget.allChapters
        .where((c) => c.chapterNumber < _currentChapter.chapterNumber)
        .toList()
      ..sort((a, b) => b.chapterNumber.compareTo(a.chapterNumber));
    return candidates.isEmpty ? null : candidates.first;
  }

  Chapter? get _nextChapter {
    final candidates = widget.allChapters
        .where((c) => c.chapterNumber > _currentChapter.chapterNumber)
        .toList()
      ..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _currentTranslation = widget.translation;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _scrollController.addListener(_onScroll);
  }

  double _lastScrollOffset = 0;

  void _onScroll() {
    final offset = _scrollController.offset;
    if ((offset - _lastScrollOffset).abs() > 30) {
      final scrollingDown = offset > _lastScrollOffset;
      if (scrollingDown && _headerVisible) {
        setState(() => _headerVisible = false);
      } else if (!scrollingDown && !_headerVisible) {
        setState(() => _headerVisible = true);
      }
      _lastScrollOffset = offset;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ─── Navigation ───
  Future<void> _navigateToChapter(Chapter chapter) async {
    setState(() {
      _loadingTranslation = true;
      _currentChapter = chapter;
      _currentTranslation = null;
    });

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    _fadeController.reset();

    try {
      final records = await PocketBaseService().pb
          .collection('translations')
          .getList(
            filter: 'chapter_id = "${chapter.id}"',
            sort: '-created',
          );

      Translation? translation;
      if (records.items.isNotEmpty) {
        translation = Translation.fromJson(records.items.first.toJson());
      }

      if (mounted) {
        setState(() {
          _currentTranslation = translation;
          _loadingTranslation = false;
          // Auto switch to original if no translation
          if (translation == null) _showOriginal = true;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTranslation = false);
      }
    }
  }

  // ─── Keyboard shortcuts ───
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyN) {
      if (_hasNext) _navigateToChapter(_nextChapter!);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.keyP) {
      if (_hasPrev) _navigateToChapter(_prevChapter!);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: _colors.background,
        body: Stack(
          children: [
            // ─── Main Content ───
            _buildContent(),

            // ─── Animated Header ───
            AnimatedSlide(
              offset: _headerVisible ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _buildHeader(),
            ),

            // ─── Settings Panel ───
            if (_settingsOpen) _buildSettingsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _colors.surface,
        border: Border(
          bottom: BorderSide(color: _colors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Back
            _HeaderButton(
              icon: Icons.arrow_back,
              color: _colors.icon,
              onTap: () => Navigator.pop(context),
              tooltip: 'Back to library',
            ),
            const SizedBox(width: 12),

            // Title breadcrumb
            Expanded(
              child: Row(
                children: [
                  Text(
                    widget.series.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _colors.subtext,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: _colors.subtext,
                    ),
                  ),
                  Text(
                    _currentChapter.chapterTitle ??
                        'Chapter ${_currentChapter.chapterNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Chapter nav
            Row(
              children: [
                _HeaderButton(
                  icon: Icons.chevron_left,
                  color: _hasPrev ? _colors.icon : _colors.divider,
                  onTap: _hasPrev
                      ? () => _navigateToChapter(_prevChapter!)
                      : null,
                  tooltip: 'Previous chapter (←)',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Ch. ${_currentChapter.chapterNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _colors.subtext,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _HeaderButton(
                  icon: Icons.chevron_right,
                  color: _hasNext ? _colors.icon : _colors.divider,
                  onTap: _hasNext
                      ? () => _navigateToChapter(_nextChapter!)
                      : null,
                  tooltip: 'Next chapter (→)',
                ),
              ],
            ),

            const SizedBox(width: 12),

            // Source toggle
            if (_hasTranslation)
              _ToggleChip(
                label: _showOriginal ? 'Original' : 'Translation',
                icon: _showOriginal ? Icons.translate_outlined : Icons.translate,
                color: _colors.accent,
                textColor: _colors.text,
                onTap: () => setState(() => _showOriginal = !_showOriginal),
              ),

            const SizedBox(width: 8),

            // Settings
            _HeaderButton(
              icon: Icons.tune,
              color: _settingsOpen ? _colors.accent : _colors.icon,
              onTap: () => setState(() => _settingsOpen = !_settingsOpen),
              tooltip: 'Reading settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Top spacer for header
          const SliverToBoxAdapter(child: SizedBox(height: 56)),

          // Chapter title block
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _maxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chapter number label
                      Text(
                        'CHAPTER ${_currentChapter.chapterNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: _colors.accent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Chapter title
                      Text(
                        _currentChapter.chapterTitle ??
                            'Chapter ${_currentChapter.chapterNumber}',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: _colors.text,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Metadata row
                      Row(
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 14, color: _colors.subtext),
                          const SizedBox(width: 6),
                          Text(
                            '${(_displayText.split(' ').length)} words',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _colors.subtext,
                            ),
                          ),
                          if (_currentTranslation?.modelUsed != null) ...[
                            const SizedBox(width: 16),
                            Icon(Icons.auto_awesome,
                                size: 14, color: _colors.subtext),
                            const SizedBox(width: 6),
                            Text(
                              _showOriginal
                                  ? 'Source text'
                                  : _currentTranslation!.modelUsed!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _colors.subtext,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 32),
                      Divider(color: _colors.divider, thickness: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Body text
          SliverToBoxAdapter(
            child: _loadingTranslation
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(64),
                      child: CircularProgressIndicator(
                        color: _colors.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                        child: _buildBodyText(),
                      ),
                    ),
                  ),
          ),

          // Bottom navigation
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _maxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 64, 24, 80),
                  child: Column(
                    children: [
                      Divider(color: _colors.divider),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Prev
                          _hasPrev
                              ? _NavButton(
                                  label: 'Previous',
                                  sublabel:
                                      'Ch. ${_prevChapter!.chapterNumber}',
                                  icon: Icons.arrow_back,
                                  isLeft: true,
                                  colors: _colors,
                                  onTap: () =>
                                      _navigateToChapter(_prevChapter!),
                                )
                              : const SizedBox(width: 160),

                          // Next
                          _hasNext
                              ? _NavButton(
                                  label: 'Next Chapter',
                                  sublabel:
                                      'Ch. ${_nextChapter!.chapterNumber}',
                                  icon: Icons.arrow_forward,
                                  isLeft: false,
                                  colors: _colors,
                                  onTap: () =>
                                      _navigateToChapter(_nextChapter!),
                                )
                              : const SizedBox(width: 160),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyText() {
    final paragraphs = _displayText
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        // Image marker
        if (RegExp(r'^\[Image \d+\]$').hasMatch(paragraph)) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _colors.divider.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, color: _colors.subtext, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    paragraph,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _colors.subtext,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: _fontSize * _lineHeight * 0.6),
          child: Text(
            paragraph,
            style: GoogleFonts.lora(
              fontSize: _fontSize,
              height: _lineHeight,
              color: _colors.text,
              letterSpacing: 0.01,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettingsOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _settingsOpen = false),
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              top: 64,
              right: 16,
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping panel
                child: _SettingsPanel(
                  colors: _colors,
                  theme: _theme,
                  fontSize: _fontSize,
                  lineHeight: _lineHeight,
                  maxWidth: _maxWidth,
                  onThemeChanged: (t) => setState(() => _theme = t),
                  onFontSizeChanged: (s) => setState(() => _fontSize = s),
                  onLineHeightChanged: (h) => setState(() => _lineHeight = h),
                  onWidthChanged: (w) => setState(() => _maxWidth = w),
                  onClose: () => setState(() => _settingsOpen = false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;

  const _HeaderButton({
    required this.icon,
    required this.color,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: color),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final bool isLeft;
  final _ThemeColors colors;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.isLeft,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
              isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: isLeft
              ? [
                  Icon(icon, size: 18, color: colors.subtext),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.subtext,
                        ),
                      ),
                      Text(
                        sublabel,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ),
                ]
              : [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.subtext,
                        ),
                      ),
                      Text(
                        sublabel,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Icon(icon, size: 18, color: colors.subtext),
                ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Settings Panel
// ─────────────────────────────────────────

class _SettingsPanel extends StatelessWidget {
  final _ThemeColors colors;
  final ReaderTheme theme;
  final double fontSize;
  final double lineHeight;
  final double maxWidth;
  final ValueChanged<ReaderTheme> onThemeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onClose;

  const _SettingsPanel({
    required this.colors,
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.maxWidth,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onWidthChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      shadowColor: Colors.black26,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reading Settings',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close, size: 18, color: colors.subtext),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Theme
            _SectionLabel(label: 'THEME', colors: colors),
            const SizedBox(height: 10),
            Row(
              children: [
                _ThemeButton(
                  label: 'Light',
                  bg: const Color(0xFFF7F6F3),
                  textColor: const Color(0xFF1A1A1A),
                  selected: theme == ReaderTheme.light,
                  onTap: () => onThemeChanged(ReaderTheme.light),
                ),
                const SizedBox(width: 8),
                _ThemeButton(
                  label: 'Dark',
                  bg: const Color(0xFF141414),
                  textColor: const Color(0xFFE8E6E1),
                  selected: theme == ReaderTheme.dark,
                  onTap: () => onThemeChanged(ReaderTheme.dark),
                ),
                const SizedBox(width: 8),
                _ThemeButton(
                  label: 'Sepia',
                  bg: const Color(0xFFF2E8D5),
                  textColor: const Color(0xFF3B2F1E),
                  selected: theme == ReaderTheme.sepia,
                  onTap: () => onThemeChanged(ReaderTheme.sepia),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Font size
            _SectionLabel(label: 'FONT SIZE', colors: colors),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'A',
                  style: GoogleFonts.lora(fontSize: 13, color: colors.subtext),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: colors.accent,
                      thumbColor: colors.accent,
                      inactiveTrackColor: colors.divider,
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: fontSize,
                      min: 14,
                      max: 26,
                      divisions: 12,
                      onChanged: onFontSizeChanged,
                    ),
                  ),
                ),
                Text(
                  'A',
                  style: GoogleFonts.lora(fontSize: 20, color: colors.subtext),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: Text(
                '${fontSize.round()}px',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: colors.subtext,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Line height
            _SectionLabel(label: 'LINE SPACING', colors: colors),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [1.4, 1.6, 1.75, 2.0, 2.2].map((h) {
                final selected = (lineHeight - h).abs() < 0.05;
                return GestureDetector(
                  onTap: () => onLineHeightChanged(h),
                  child: Container(
                    width: 44,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.accent.withOpacity(0.12)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected ? colors.accent : colors.divider,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        h.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.normal,
                          color: selected ? colors.accent : colors.subtext,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Content width
            _SectionLabel(label: 'CONTENT WIDTH', colors: colors),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ('Narrow', 560.0),
                ('Medium', 680.0),
                ('Wide', 820.0),
              ].map((pair) {
                final selected = (maxWidth - pair.$2).abs() < 10;
                return GestureDetector(
                  onTap: () => onWidthChanged(pair.$2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.accent.withOpacity(0.12)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected ? colors.accent : colors.divider,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pair.$1,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? colors.accent : colors.subtext,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            Divider(color: colors.divider),
            const SizedBox(height: 8),
            Text(
              'Tip: Use ← → arrow keys to navigate chapters',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: colors.subtext,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final _ThemeColors colors;

  const _SectionLabel({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: colors.subtext,
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.label,
    required this.bg,
    required this.textColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF5B7FEC) : Colors.grey[300]!,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}