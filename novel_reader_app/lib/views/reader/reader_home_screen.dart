import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../models/chapter.dart';
import '../../services/pocketbase_service.dart';
import '../../services/reader_auth_service.dart';
import 'reader_browse_screen.dart';
import 'reader_series_screen.dart';
import 'reader_followed_screen.dart';
import 'reader_login_screen.dart';
import 'reader_settings_screen.dart';

class ReaderHomeScreen extends StatefulWidget {
  const ReaderHomeScreen({super.key});

  @override
  State<ReaderHomeScreen> createState() => _ReaderHomeScreenState();
}

class _ReaderHomeScreenState extends State<ReaderHomeScreen> {
  int _navIndex = 0;

  // Data
  List<Series> _recentSeries = [];
  List<_UpdatedChapter> _recentChapters = [];
  bool _loading = true;

  final _pb = PocketBaseService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Recent series
      final seriesRecords = await _pb.pb
          .collection('series')
          .getList(page: 1, perPage: 6, sort: '-created');
      final series = seriesRecords.items
          .map((r) => Series.fromJson(r.toJson()))
          .toList();

      // Recently updated chapters (with series info)
      final chapterRecords = await _pb.pb
          .collection('chapters')
          .getList(
            page: 1,
            perPage: 8,
            sort: '-updated',
            filter: 'translation_status = "completed"',
            expand: 'series_id',
          );

      final updatedChapters = chapterRecords.items.map((r) {
        final json = r.toJson();
        final chapter = Chapter.fromJson(json);
        Series? s;
        try {
          final expand = json['expand'] as Map<String, dynamic>?;
          if (expand != null && expand['series_id'] != null) {
            s = Series.fromJson(expand['series_id'] as Map<String, dynamic>);
          }
        } catch (_) {}
        return _UpdatedChapter(chapter: chapter, series: s);
      }).toList();

      if (mounted) {
        setState(() {
          _recentSeries = series;
          _recentChapters = updatedChapters;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      body: Row(
        children: [
          // ─── Sidebar nav ───
          _Sidebar(
            selectedIndex: _navIndex,
            onSelect: (i) => setState(() => _navIndex = i),
          ),

          // ─── Main content ───
          Expanded(
            child: IndexedStack(
              index: _navIndex,
              children: [
                _HomeTab(
                  recentSeries: _recentSeries,
                  recentChapters: _recentChapters,
                  loading: _loading,
                  onRefresh: _loadData,
                ),
                const ReaderBrowseScreen(),
                const ReaderFollowedScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Sidebar
// ─────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ReaderAuthService>();

    return Container(
      width: 220,
      color: Colors.white,
      child: Column(
        children: [
          // App logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.menu_book,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Novels',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),

          // Nav items
          _NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore,
            label: 'Browse',
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          _NavItem(
            icon: Icons.bookmark_outline,
            activeIcon: Icons.bookmark,
            label: 'Following',
            selected: selectedIndex == 2,
            onTap: () {
              if (!auth.isLoggedIn) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReaderLoginScreen()),
                );
              } else {
                onSelect(2);
              }
            },
          ),

          const Spacer(),
          const Divider(height: 1, color: Color(0xFFF0EEE9)),
          const SizedBox(height: 4),

          // Settings button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                size: 20,
                color: Color(0xFF9E9E9E),
              ),
              title: Text(
                'Settings',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6B6B6B),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReaderSettingsScreen(),
                  ),
                );
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // User section
          if (auth.isLoggedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF1A1A1A),
                  child: Text(
                    (auth.username ?? auth.email ?? 'U')[0].toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Text(
                  auth.username ?? auth.email ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.logout, size: 16),
                  color: const Color(0xFF9E9E9E),
                  onPressed: () => auth.logout(),
                  tooltip: 'Sign out',
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReaderLoginScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1A1A),
                    side: const BorderSide(color: Color(0xFFE0DED8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    'Sign in',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(
          selected ? activeIcon : icon,
          size: 20,
          color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF9E9E9E),
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF6B6B6B),
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: selected ? const Color(0xFFF5F4F1) : Colors.transparent,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Home Tab
// ─────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final List<Series> recentSeries;
  final List<_UpdatedChapter> recentChapters;
  final bool loading;
  final VoidCallback onRefresh;

  const _HomeTab({
    required this.recentSeries,
    required this.recentChapters,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ReaderAuthService>();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFF1A1A1A),
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(auth),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'What would you like to read today?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, size: 20),
                    color: const Color(0xFF9E9E9E),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
          ),

          if (loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1A1A1A),
                  strokeWidth: 2,
                ),
              ),
            )
          else ...[
            // Continue reading
            _buildContinueReading(context, auth),

            // Recently added
            _SectionHeader(
              title: 'Recently Added',
              onSeeAll: () {
                // Navigate to browse
              },
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 290,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  itemCount: recentSeries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) => _SeriesCard(series: recentSeries[i]),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Recently updated chapters
            const _SectionHeader(title: 'Recently Updated'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: recentChapters
                      .map((uc) => _ChapterUpdateRow(updated: uc))
                      .toList(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }

  Widget _buildContinueReading(BuildContext context, ReaderAuthService auth) {
    // Find any series with saved progress
    final progressEntries = auth.likedSeriesIds.isEmpty
        ? <String>[]
        : auth.likedSeriesIds.toList();

    // Get continued series from progress map
    final progressMap = {
      for (final s in recentSeries)
        if (auth.getProgress(s.id) != null) s.id: s,
    };

    if (progressMap.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
            child: Text(
              'Continue Reading',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: progressMap.entries.map((entry) {
                final series = entry.value;
                final progress = auth.getProgress(series.id)!;
                return _ContinueReadingCard(
                  series: series,
                  chapterNumber: progress['chapterNumber'] as int,
                  chapterTitle: progress['chapterTitle'] as String? ?? '',
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting(ReaderAuthService auth) {
    final hour = DateTime.now().hour;
    final name = auth.username;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return name != null ? '$timeGreeting, $name' : timeGreeting;
  }
}

// ─────────────────────────────────────────
//  Section header
// ─────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  'See all',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6B6B6B),
                    decoration: TextDecoration.underline,
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
//  Series card (horizontal scroll)
// ─────────────────────────────────────────

class _SeriesCard extends StatelessWidget {
  final Series series;
  const _SeriesCard({required this.series});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReaderSeriesScreen(series: series)),
      ),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cover — fixed height, no AspectRatio fighting the parent
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 140,
                    height: 210,
                    child: series.coverImage != null
                        ? Image.network(
                            'http://127.0.0.1:8090/api/files/series/${series.id}/${series.coverImage!}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _PlaceholderCover(title: series.title),
                          )
                        : _PlaceholderCover(title: series.title),
                  ),
                ),
                // Status dot
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: series.status == 'ongoing'
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF9E9E9E),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              series.translatedTitle ?? series.title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              series.author,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF9E9E9E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  final String title;
  const _PlaceholderCover({required this.title});

  Color _color() {
    final colors = [
      const Color(0xFF2D3436),
      const Color(0xFF6C5CE7),
      const Color(0xFF00B894),
      const Color(0xFFE17055),
      const Color(0xFF0984E3),
      const Color(0xFFD63031),
    ];
    return colors[title.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _color(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Chapter update row
// ─────────────────────────────────────────

class _UpdatedChapter {
  final Chapter chapter;
  final Series? series;
  _UpdatedChapter({required this.chapter, this.series});
}

class _ChapterUpdateRow extends StatelessWidget {
  final _UpdatedChapter updated;
  const _ChapterUpdateRow({required this.updated});

  @override
  Widget build(BuildContext context) {
    final chapter = updated.chapter;
    final series = updated.series;

    return InkWell(
      onTap: series == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReaderSeriesScreen(
                  series: series,
                  autoOpenChapter: chapter,
                ),
              ),
            ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Small cover
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 36,
                height: 50,
                child: series?.coverImage != null
                    ? Image.network(
                        'http://127.0.0.1:8090/api/files/series/${series!.id}/${series.coverImage!}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderCover(title: series.title),
                      )
                    : _PlaceholderCover(title: series?.title ?? '?'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series?.translatedTitle ??
                        series?.title ??
                        'Unknown Series',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chapter.chapterTitle ?? 'Chapter ${chapter.chapterNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6B6B6B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              _timeAgo(chapter.updated),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

// ─────────────────────────────────────────
//  Continue reading card
// ─────────────────────────────────────────

class _ContinueReadingCard extends StatelessWidget {
  final Series series;
  final int chapterNumber;
  final String chapterTitle;

  const _ContinueReadingCard({
    required this.series,
    required this.chapterNumber,
    required this.chapterTitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReaderSeriesScreen(series: series)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0EEE9)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 66,
                child: series.coverImage != null
                    ? Image.network(
                        'http://127.0.0.1:8090/api/files/series/${series.id}/${series.coverImage!}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderCover(title: series.title),
                      )
                    : _PlaceholderCover(title: series.title),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.translatedTitle ?? series.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chapterTitle.isNotEmpty
                        ? chapterTitle
                        : 'Chapter $chapterNumber',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6B6B6B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
