import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chapter.dart';
import '../../models/series.dart';
import '../../models/translation.dart';
import '../../services/pocketbase_service.dart';

// ─────────────────────────────────────────
//  Enums
// ─────────────────────────────────────────

enum ReaderTheme { light, dark, sepia }

enum ReadingMode { scroll, paged }

// ─────────────────────────────────────────
//  Page model — sealed union
// ─────────────────────────────────────────

abstract class _PageContent {}

class _TextPage extends _PageContent {
  final List<String> paragraphs;
  _TextPage(this.paragraphs);
}

class _ImagePage extends _PageContent {
  final String marker; // "[Image 3]"
  final int imageIndex; // 0-based index into chapter.images
  _ImagePage({required this.marker, required this.imageIndex});
}

// ─────────────────────────────────────────
//  Theme colors
// ─────────────────────────────────────────

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
  // ─── Chapter ───
  late Chapter _currentChapter;
  Translation? _currentTranslation;
  bool _loadingTranslation = false;

  // ─── Prefs ───
  ReaderTheme _theme = ReaderTheme.light;
  ReadingMode _mode = ReadingMode.scroll;
  double _fontSize = 18.0;
  double _lineHeight = 1.75;
  double _maxWidth = 680.0;
  bool _showOriginal = false;
  bool _settingsOpen = false;

  // ─── Scroll mode ───
  double _scrollProgress = 0.0;
  final _scrollCtrl = ScrollController();

  // ─── Paged mode ───
  int _currentPageIndex = 0;
  List<_PageContent> _pages = [];
  late PageController _pageCtrl;
  double _pagedAvailH = 0;
  double _pagedAvailW = 0;

  // ─── Animation ───
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ─── Helpers ───

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
  bool get _hasPrev => widget.allChapters.any(
    (c) => c.chapterNumber < _currentChapter.chapterNumber,
  );
  bool get _hasNext => widget.allChapters.any(
    (c) => c.chapterNumber > _currentChapter.chapterNumber,
  );

  Chapter? get _prevChapter {
    final list =
        widget.allChapters
            .where((c) => c.chapterNumber < _currentChapter.chapterNumber)
            .toList()
          ..sort((a, b) => b.chapterNumber.compareTo(a.chapterNumber));
    return list.isEmpty ? null : list.first;
  }

  Chapter? get _nextChapter {
    final list =
        widget.allChapters
            .where((c) => c.chapterNumber > _currentChapter.chapterNumber)
            .toList()
          ..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    return list.isEmpty ? null : list.first;
  }

  // ─── Page splitting ───
  static final _imageRegex = RegExp(
    r'^\[Image\s+(\d+)\]$',
    caseSensitive: false,
  );

  List<_PageContent> _buildPages() {
    final lines = _displayText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final result = <_PageContent>[];
    final buf = <String>[];
    double currentH = 0;
    int pageIndex = 0;

    // ── Budget calculation ──────────────────────────────────────────
    // Available height for the Expanded text area on each page:
    //
    //   _pagedAvailH              full viewport height (LayoutBuilder)
    //   - _headerH      (72)      56px bar + 16px block-bar, via Container top padding
    //   - padH          (44)      fromLTRB(32, 20, 32, 24): top 20 + bottom 24
    //   - navH          (40)      Padding(top:12) + _PageArrow(vertical:6+6, icon:16)
    //   - safetyMargin  (20)      rounding errors + font metric differences
    //
    // Page 0 additionally loses the chapter title block rendered above the text.
    // Title block: label(~13) + gap(10) + title text(~56 for 2 lines) +
    //              gap(24) + Divider + gap(20) ≈ 155px.
    const navH = 40.0;
    const padH = 44.0;
    const safetyMargin = 20.0;
    const titleH = 155.0;
    final fullBudget = (_pagedAvailH - _headerH - navH - padH - safetyMargin)
        .clamp(80.0, double.infinity);

    double budgetFor(int pi) => pi == 0
        ? (fullBudget - titleH).clamp(60.0, double.infinity)
        : fullBudget;

    // Bottom padding per paragraph — must match the widget exactly.
    final paraBottomPad = _fontSize * _lineHeight * 0.5;

    double measurePara(String text) {
      if (_pagedAvailW <= 0) {
        // No layout info yet — rough fallback.
        return _fontSize * _lineHeight * 3 + paraBottomPad;
      }
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: _fontSize,
            height: _lineHeight,
            letterSpacing: 0.01,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: _pagedAvailW);
      // Apply a 1.07 multiplier: TextPainter uses the system default font while
      // the widget renders in Lora, which has slightly taller metrics.
      return tp.height * 1.07 + paraBottomPad;
    }

    void flush() {
      if (buf.isNotEmpty) {
        result.add(_TextPage(List.from(buf)));
        buf.clear();
        currentH = 0;
        pageIndex++;
      }
    }

    for (final line in lines) {
      final m = _imageRegex.firstMatch(line);
      if (m != null) {
        flush();
        final n = int.parse(m.group(1)!);
        result.add(_ImagePage(marker: line, imageIndex: n - 1));
        pageIndex++;
      } else {
        final h = measurePara(line);
        if (buf.isNotEmpty && currentH + h > budgetFor(pageIndex)) {
          // Current page is full — start a new one.
          flush();
        }
        buf.add(line);
        currentH += h;
        // If a single paragraph exceeds the entire budget on its own, flush it
        // immediately so it gets its own page and doesn't block the next one.
        if (buf.length == 1 && currentH > budgetFor(pageIndex)) {
          flush();
        }
      }
    }
    flush();
    return result;
  }

  // ─── Lifecycle ───

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _currentTranslation = widget.translation;
    _pages = _buildPages();

    _pageCtrl = PageController();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    final p = (_scrollCtrl.offset / max).clamp(0.0, 1.0);
    if ((p - _scrollProgress).abs() > 0.001) {
      setState(() => _scrollProgress = p);
    }
  }

  // ─── Chapter navigation ───

  Future<void> _navigateToChapter(Chapter chapter) async {
    setState(() {
      _loadingTranslation = true;
      _currentChapter = chapter;
      _currentTranslation = null;
      _scrollProgress = 0;
      _currentPageIndex = 0;
      _pages = [];
    });

    if (_mode == ReadingMode.scroll) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _pageCtrl.jumpToPage(0);
    }

    _fadeCtrl.reset();

    try {
      final records = await PocketBaseService().pb
          .collection('translations')
          .getList(filter: 'chapter_id = "${chapter.id}"', sort: '-created');

      Translation? t;
      if (records.items.isNotEmpty) {
        t = Translation.fromJson(records.items.first.toJson());
      }

      if (mounted) {
        setState(() {
          _currentTranslation = t;
          _loadingTranslation = false;
          if (t == null) _showOriginal = true;
          _pages = _buildPages();
        });
        _fadeCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTranslation = false);
    }
  }

  // ─── Mode switch ───

  void _setMode(ReadingMode m) {
    if (m == _mode) return;
    setState(() {
      _mode = m;
      _currentPageIndex = 0;
      _scrollProgress = 0;
      if (m == ReadingMode.paged) {
        _pages = _buildPages();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
        });
      }
    });
  }

  // ─── Page navigation ───

  void _goToPage(int i) {
    if (i < 0 || i >= _pages.length) return;
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ─── Keyboard ───

  KeyEventResult _handleKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;

    if (_mode == ReadingMode.paged) {
      if (e.logicalKey == LogicalKeyboardKey.arrowRight ||
          e.logicalKey == LogicalKeyboardKey.space) {
        if (_currentPageIndex < _pages.length - 1) {
          _goToPage(_currentPageIndex + 1);
        } else if (_hasNext) {
          _navigateToChapter(_nextChapter!);
        }
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_currentPageIndex > 0) {
          _goToPage(_currentPageIndex - 1);
        } else if (_hasPrev) {
          _navigateToChapter(_prevChapter!);
        }
        return KeyEventResult.handled;
      }
    } else {
      if (e.logicalKey == LogicalKeyboardKey.arrowRight ||
          e.logicalKey == LogicalKeyboardKey.keyN) {
        if (_hasNext) _navigateToChapter(_nextChapter!);
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft ||
          e.logicalKey == LogicalKeyboardKey.keyP) {
        if (_hasPrev) _navigateToChapter(_prevChapter!);
        return KeyEventResult.handled;
      }
    }

    if (e.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ═══════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: _colors.background,
        body: Stack(
          children: [
            _mode == ReadingMode.scroll
                ? _buildScrollView()
                : _buildPagedView(),
            Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),
            if (_settingsOpen) _buildSettingsOverlay(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Header
  // ─────────────────────────────────────────

  Widget _buildHeader() {
    final totalPages = _pages.isEmpty ? 1 : _pages.length;
    final pageLabel = '${_currentPageIndex + 1} / $totalPages';
    final scrollLabel = '${(_scrollProgress * 100).round()}%';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Bar ──
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: _colors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                _HeaderBtn(
                  icon: Icons.arrow_back,
                  color: _colors.icon,
                  onTap: () => Navigator.pop(context),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 12),

                // Breadcrumb
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

                // Chapter nav + progress label
                Row(
                  children: [
                    _HeaderBtn(
                      icon: Icons.chevron_left,
                      color: _hasPrev ? _colors.icon : _colors.divider,
                      onTap: _hasPrev
                          ? () => _navigateToChapter(_prevChapter!)
                          : null,
                      tooltip: 'Previous chapter',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ch. ${_currentChapter.chapterNumber}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _colors.subtext,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _mode == ReadingMode.scroll
                                ? scrollLabel
                                : pageLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _colors.subtext.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderBtn(
                      icon: Icons.chevron_right,
                      color: _hasNext ? _colors.icon : _colors.divider,
                      onTap: _hasNext
                          ? () => _navigateToChapter(_nextChapter!)
                          : null,
                      tooltip: 'Next chapter',
                    ),
                  ],
                ),

                const SizedBox(width: 8),

                // ── View mode toggle ──
                _ModeToggle(mode: _mode, colors: _colors, onChanged: _setMode),

                const SizedBox(width: 8),

                // Translation toggle
                if (_hasTranslation) ...[
                  _ToggleChip(
                    label: _showOriginal ? 'Original' : 'Translation',
                    icon: _showOriginal
                        ? Icons.translate_outlined
                        : Icons.translate,
                    color: _colors.accent,
                    textColor: _colors.text,
                    onTap: () {
                      setState(() {
                        _showOriginal = !_showOriginal;
                        if (_mode == ReadingMode.paged) {
                          _pages = _buildPages();
                          _currentPageIndex = 0;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
                          });
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],

                // Settings
                _HeaderBtn(
                  icon: Icons.tune,
                  color: _settingsOpen ? _colors.accent : _colors.icon,
                  onTap: () => setState(() => _settingsOpen = !_settingsOpen),
                  tooltip: 'Settings',
                ),
              ],
            ),
          ),
        ),

        // ── Progress indicator ──
        if (_mode == ReadingMode.scroll)
          _ScrollBar(
            progress: _scrollProgress,
            color: _colors.accent,
            bg: _colors.divider,
          )
        else
          _BlockBar(
            pages: _pages,
            currentIndex: _currentPageIndex,
            color: _colors.accent,
            bg: _colors.divider,
            onTap: _goToPage,
          ),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  Scroll view
  // ─────────────────────────────────────────

  // Header = 56px bar + 16px block bar
  static const _headerH = 72.0;

  Widget _buildScrollView() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: _headerH)),

          // Chapter title
          SliverToBoxAdapter(child: _chapterTitleBlock()),

          // Body
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

          // Bottom nav
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

  // ─────────────────────────────────────────
  //  Paged view
  // ─────────────────────────────────────────

  Widget _buildPagedView() {
    if (_loadingTranslation) {
      return Center(
        child: CircularProgressIndicator(color: _colors.accent, strokeWidth: 2),
      );
    }
    if (_pages.isEmpty) {
      return Center(
        child: Text(
          'No content',
          style: GoogleFonts.inter(color: _colors.subtext),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final newH = constraints.maxHeight;
        // Text column width = constrained by _maxWidth, minus 64px horizontal padding.
        final newW = (constraints.maxWidth.clamp(0.0, _maxWidth)) - 64;

        if ((newH - _pagedAvailH).abs() > 1 ||
            (newW - _pagedAvailW).abs() > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _pagedAvailH = newH;
                _pagedAvailW = newW;
                _pages = _buildPages();
                _currentPageIndex = 0;
                if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
              });
            }
          });
        }

        return FadeTransition(
          opacity: _fadeAnim,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPageIndex = i),
            itemBuilder: (ctx, i) => _buildPage(_pages[i], i),
          ),
        );
      },
    );
  }

  Widget _buildPage(_PageContent page, int i) {
    final isFirst = i == 0;
    final isLast = i == _pages.length - 1;

    if (page is _ImagePage) {
      return _ImagePageWidget(
        page: page,
        chapter: _currentChapter,
        colors: _colors,
        headerH: _headerH,
        onPrev: i > 0
            ? () => _goToPage(i - 1)
            : (_hasPrev ? () => _navigateToChapter(_prevChapter!) : null),
        onNext: !isLast
            ? () => _goToPage(i + 1)
            : (_hasNext ? () => _navigateToChapter(_nextChapter!) : null),
        prevLabel: i > 0 ? 'Back' : 'Ch. ${_prevChapter?.chapterNumber ?? ""}',
        nextLabel: !isLast ? 'Continue' : 'Next Chapter',
      );
    }

    final tp = page as _TextPage;

    return GestureDetector(
      onTapUp: (d) {
        final w = context.size?.width ?? 800;
        if (d.localPosition.dx > w * 0.5) {
          if (!isLast) {
            _goToPage(i + 1);
          } else if (_hasNext) {
            _navigateToChapter(_nextChapter!);
          }
        } else {
          if (i > 0) {
            _goToPage(i - 1);
          } else if (_hasPrev) {
            _navigateToChapter(_prevChapter!);
          }
        }
      },
      child: SizedBox.expand(
        child: Container(
          color: _colors.background,
          padding: EdgeInsets.only(top: _headerH),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Chapter title on first page only
                    if (isFirst) ...[
                      Text(
                        'CHAPTER ${_currentChapter.chapterNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: _colors.accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _currentChapter.chapterTitle ??
                            'Chapter ${_currentChapter.chapterNumber}',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: _colors.text,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(color: _colors.divider),
                      const SizedBox(height: 20),
                    ],

                    // Text content — fills available space, no scrolling
                    Expanded(
                      child: ClipRect(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: tp.paragraphs
                              .map(
                                (p) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: _fontSize * _lineHeight * 0.5,
                                  ),
                                  child: Text(
                                    p,
                                    style: GoogleFonts.lora(
                                      fontSize: _fontSize,
                                      height: _lineHeight,
                                      color: _colors.text,
                                      letterSpacing: 0.01,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),

                    // Page turn arrows — always pinned at the bottom
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left
                          if (i > 0)
                            _PageArrow(
                              icon: Icons.arrow_back,
                              label: 'Back',
                              colors: _colors,
                              onTap: () => _goToPage(i - 1),
                            )
                          else if (_hasPrev)
                            _PageArrow(
                              icon: Icons.arrow_back,
                              label: 'Ch. ${_prevChapter!.chapterNumber}',
                              colors: _colors,
                              onTap: () => _navigateToChapter(_prevChapter!),
                            )
                          else
                            const SizedBox(width: 80),

                          // Right
                          if (!isLast)
                            _PageArrow(
                              icon: Icons.arrow_forward,
                              label: 'Next',
                              colors: _colors,
                              alignRight: true,
                              onTap: () => _goToPage(i + 1),
                            )
                          else if (_hasNext)
                            _PageArrow(
                              icon: Icons.arrow_forward,
                              label: 'Ch. ${_nextChapter!.chapterNumber}',
                              colors: _colors,
                              alignRight: true,
                              onTap: () => _navigateToChapter(_nextChapter!),
                            )
                          else
                            const SizedBox(width: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Shared content helpers
  // ─────────────────────────────────────────

  Widget _chapterTitleBlock() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 14,
                    color: _colors.subtext,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_displayText.split(' ').length} words',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _colors.subtext,
                    ),
                  ),
                  if (_currentTranslation?.modelUsed != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.auto_awesome, size: 14, color: _colors.subtext),
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
    );
  }

  Widget _buildBodyText() {
    final paras = _displayText
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paras.map((p) {
        if (_imageRegex.hasMatch(p)) {
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
                    p,
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
            p,
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
                onTap: () {},
                child: _SettingsPanel(
                  colors: _colors,
                  theme: _theme,
                  fontSize: _fontSize,
                  lineHeight: _lineHeight,
                  maxWidth: _maxWidth,
                  onThemeChanged: (t) => setState(() => _theme = t),
                  onFontSizeChanged: (s) => setState(() {
                    _fontSize = s;
                    if (_mode == ReadingMode.paged) _pages = _buildPages();
                  }),
                  onLineHeightChanged: (h) => setState(() {
                    _lineHeight = h;
                    if (_mode == ReadingMode.paged) _pages = _buildPages();
                  }),
                  onWidthChanged: (w) => setState(() {
                    _maxWidth = w;
                    if (_mode == ReadingMode.paged) _pages = _buildPages();
                  }),
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

// ═══════════════════════════════════════════
//  Image page widget
// ═══════════════════════════════════════════

class _ImagePageWidget extends StatelessWidget {
  final _ImagePage page;
  final Chapter chapter;
  final _ThemeColors colors;
  final double headerH;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final String prevLabel;
  final String nextLabel;

  const _ImagePageWidget({
    required this.page,
    required this.chapter,
    required this.colors,
    required this.headerH,
    required this.onPrev,
    required this.onNext,
    required this.prevLabel,
    required this.nextLabel,
  });

  String? _url() {
    final imgs = chapter.images;
    if (imgs == null || imgs.isEmpty) return null;
    final i = page.imageIndex;
    if (i < 0 || i >= imgs.length) return null;
    return 'http://127.0.0.1:8090/api/files/chapters/${chapter.id}/${imgs[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final url = _url();

    return GestureDetector(
      onTapUp: (d) {
        final w = context.size?.width ?? 800;
        if (d.localPosition.dx > w * 0.5) {
          onNext?.call();
        } else {
          onPrev?.call();
        }
      },
      child: SizedBox.expand(
        child: Container(
          color: colors.background,
          padding: EdgeInsets.only(top: headerH),
          child: Column(
            children: [
              // Image fills remaining space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 16, 40, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        page.marker,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: colors.subtext,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: url != null
                              ? Image.network(
                                  url,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (_, child, prog) {
                                    if (prog == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: colors.accent,
                                        strokeWidth: 2,
                                        value: prog.expectedTotalBytes != null
                                            ? prog.cumulativeBytesLoaded /
                                                  prog.expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => _ImgPlaceholder(
                                    marker: page.marker,
                                    colors: colors,
                                  ),
                                )
                              : _ImgPlaceholder(
                                  marker: page.marker,
                                  colors: colors,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Nav
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    onPrev != null
                        ? _PageArrow(
                            icon: Icons.arrow_back,
                            label: prevLabel,
                            colors: colors,
                            onTap: onPrev!,
                          )
                        : const SizedBox(width: 80),
                    onNext != null
                        ? _PageArrow(
                            icon: Icons.arrow_forward,
                            label: nextLabel,
                            colors: colors,
                            alignRight: true,
                            onTap: onNext!,
                          )
                        : const SizedBox(width: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  final String marker;
  final _ThemeColors colors;
  const _ImgPlaceholder({required this.marker, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.divider.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 48, color: colors.subtext),
            const SizedBox(height: 12),
            Text(
              marker,
              style: GoogleFonts.inter(
                fontSize: 14,
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

// ═══════════════════════════════════════════
//  Mode toggle
// ═══════════════════════════════════════════

class _ModeToggle extends StatelessWidget {
  final ReadingMode mode;
  final _ThemeColors colors;
  final ValueChanged<ReadingMode> onChanged;

  const _ModeToggle({
    required this.mode,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: colors.divider.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(
            icon: Icons.view_agenda_outlined,
            label: 'Scroll',
            selected: mode == ReadingMode.scroll,
            colors: colors,
            onTap: () => onChanged(ReadingMode.scroll),
          ),
          _Pill(
            icon: Icons.auto_stories_outlined,
            label: 'Pages',
            selected: mode == ReadingMode.paged,
            colors: colors,
            onTap: () => onChanged(ReadingMode.paged),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final _ThemeColors colors;
  final VoidCallback onTap;

  const _Pill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? colors.accent : colors.subtext,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? colors.text : colors.subtext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  Progress indicators
// ═══════════════════════════════════════════

class _ScrollBar extends StatelessWidget {
  final double progress;
  final Color color;
  final Color bg;
  const _ScrollBar({
    required this.progress,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (_, c) => Stack(
          children: [
            Container(width: c.maxWidth, height: 3, color: bg),
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              width: c.maxWidth * progress,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockBar extends StatelessWidget {
  final List<_PageContent> pages;
  final int currentIndex;
  final Color color;
  final Color bg;
  final ValueChanged<int> onTap;

  const _BlockBar({
    required this.pages,
    required this.currentIndex,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Cap at 80 visible blocks so they don't get microscopic
    const cap = 80;
    final total = pages.length.clamp(1, cap);
    final mappedCurrent = pages.length > cap
        ? (currentIndex / pages.length * total).floor().clamp(0, total - 1)
        : currentIndex;

    return Container(
      height: 16,
      color: bg.withOpacity(0.25),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: List.generate(total, (i) {
          final isImg =
              pages.length <= cap && i < pages.length && pages[i] is _ImagePage;
          final isCurrent = i == mappedCurrent;
          final isDone = i < mappedCurrent;

          return Expanded(
            child: GestureDetector(
              onTap: pages.length <= cap ? () => onTap(i) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? color
                        : isDone
                        ? color.withOpacity(0.4)
                        : isImg
                        ? color.withOpacity(0.15)
                        : bg,
                    borderRadius: BorderRadius.circular(2),
                    border: isImg && !isCurrent && !isDone
                        ? Border.all(color: color.withOpacity(0.5), width: 1)
                        : null,
                  ),
                  // Image pages get a tiny dot
                  child: isImg
                      ? Center(
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isCurrent || isDone)
                                  ? Colors.white.withOpacity(0.9)
                                  : color.withOpacity(0.7),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  Small reusable widgets
// ═══════════════════════════════════════════

class _PageArrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final _ThemeColors colors;
  final bool alignRight;
  final VoidCallback onTap;

  const _PageArrow({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      Icon(icon, size: 16, color: colors.subtext),
      const SizedBox(width: 6),
      Text(
        label,
        style: GoogleFonts.inter(fontSize: 13, color: colors.subtext),
      ),
    ];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: alignRight ? children.reversed.toList() : children,
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;

  const _HeaderBtn({
    required this.icon,
    required this.color,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 20, color: color),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
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
          mainAxisAlignment: isLeft
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
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

// ═══════════════════════════════════════════
//  Settings Panel
// ═══════════════════════════════════════════

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
                        enabledThumbRadius: 7,
                      ),
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
                style: GoogleFonts.inter(fontSize: 11, color: colors.subtext),
              ),
            ),
            const SizedBox(height: 20),

            _SectionLabel(label: 'LINE SPACING', colors: colors),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [1.4, 1.6, 1.75, 2.0, 2.2].map((h) {
                final sel = (lineHeight - h).abs() < 0.05;
                return GestureDetector(
                  onTap: () => onLineHeightChanged(h),
                  child: Container(
                    width: 44,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sel
                          ? colors.accent.withOpacity(0.12)
                          : Colors.transparent,
                      border: Border.all(
                        color: sel ? colors.accent : colors.divider,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        h.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                          color: sel ? colors.accent : colors.subtext,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _SectionLabel(label: 'CONTENT WIDTH', colors: colors),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children:
                  [
                    MapEntry('Narrow', 560.0),
                    MapEntry('Medium', 680.0),
                    MapEntry('Wide', 820.0),
                  ].map((p) {
                    final sel = (maxWidth - p.value).abs() < 10;
                    return GestureDetector(
                      onTap: () => onWidthChanged(p.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? colors.accent.withOpacity(0.12)
                              : Colors.transparent,
                          border: Border.all(
                            color: sel ? colors.accent : colors.divider,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.key,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: sel ? colors.accent : colors.subtext,
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
              'Scroll mode: ← → to change chapters\n'
              'Page mode: ← → or Space to turn pages\n'
              'Click blocks in the bar to jump to a page',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: colors.subtext,
                fontStyle: FontStyle.italic,
                height: 1.6,
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
