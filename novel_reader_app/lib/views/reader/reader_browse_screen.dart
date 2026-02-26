import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/series.dart';
import '../../services/pocketbase_service.dart';
import '../../services/reader_auth_service.dart';
import 'package:provider/provider.dart';
import 'reader_series_screen.dart';

class ReaderBrowseScreen extends StatefulWidget {
  const ReaderBrowseScreen({super.key});

  @override
  State<ReaderBrowseScreen> createState() => _ReaderBrowseScreenState();
}

class _ReaderBrowseScreenState extends State<ReaderBrowseScreen> {
  List<Series> _allSeries = [];
  List<Series> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _statusFilter = 'all';
  String _langFilter = 'all';

  final _searchCtrl = TextEditingController();
  final _pb = PocketBaseService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final records =
          await _pb.pb.collection('series').getFullList(sort: '-updated');
      final series =
          records.map((r) => Series.fromJson(r.toJson())).toList();
      if (mounted) {
        setState(() {
          _allSeries = series;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _allSeries.where((s) {
        final q = _search.toLowerCase();
        final matchSearch = q.isEmpty ||
            s.title.toLowerCase().contains(q) ||
            (s.translatedTitle?.toLowerCase().contains(q) ?? false) ||
            s.author.toLowerCase().contains(q) ||
            (s.description?.toLowerCase().contains(q) ?? false);
        final matchStatus =
            _statusFilter == 'all' || s.status == _statusFilter;
        final matchLang =
            _langFilter == 'all' || s.sourceLanguage == _langFilter;
        return matchSearch && matchStatus && matchLang;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── Top bar ───
        Container(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
          color: const Color(0xFFFAF9F7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Browse Library',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              // Search
              TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  _search = v;
                  _applyFilters();
                },
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by title, author or description…',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: const Color(0xFFBDBDBD)),
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: Color(0xFF9E9E9E)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0DED8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0DED8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF1A1A1A), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter chips
              Row(
                children: [
                  _FilterChips(
                    label: 'Status:',
                    options: const {
                      'all': 'All',
                      'ongoing': 'Ongoing',
                      'finished': 'Finished'
                    },
                    selected: _statusFilter,
                    onSelect: (v) {
                      _statusFilter = v;
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 24),
                  _FilterChips(
                    label: 'Language:',
                    options: const {
                      'all': 'All',
                      'Chinese': 'Chinese',
                      'Japanese': 'Japanese',
                      'Korean': 'Korean',
                    },
                    selected: _langFilter,
                    onSelect: (v) {
                      _langFilter = v;
                      _applyFilters();
                    },
                  ),
                  const Spacer(),
                  Text(
                    '${_filtered.length} series',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ─── List ───
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1A1A1A),
                    strokeWidth: 2,
                  ),
                )
              : _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No series found.',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: const Color(0xFF9E9E9E)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        color: Color(0xFFF0EEE9),
                      ),
                      itemBuilder: (_, i) =>
                          _SeriesListRow(series: _filtered[i]),
                    ),
        ),
      ],
    );
  }
}

// ─── Filter chips ───

class _FilterChips extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterChips({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF9E9E9E),
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        ...options.entries.map((e) {
          final isSelected = selected == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSelect(e.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1A1A1A)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFE0DED8),
                  ),
                ),
                child: Text(
                  e.value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF6B6B6B),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Series list row ───

class _SeriesListRow extends StatelessWidget {
  final Series series;
  const _SeriesListRow({required this.series});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ReaderAuthService>();
    final liked = auth.isLiked(series.id);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderSeriesScreen(series: series),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 82,
                child: series.coverImage != null
                    ? Image.network(
                        'http://127.0.0.1:8090/api/files/series/${series.id}/${series.coverImage!}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _PlaceholderCover(title: series.title),
                      )
                    : _PlaceholderCover(title: series.title),
              ),
            ),
            const SizedBox(width: 20),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          series.translatedTitle ?? series.title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusBadge(status: series.status),
                    ],
                  ),
                  if (series.translatedTitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      series.title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF9E9E9E),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'by ${series.author}  ·  ${series.sourceLanguage}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  if (series.description != null &&
                      series.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      series.description!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF6B6B6B),
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Like button
            IconButton(
              onPressed: () => auth.toggleLike(series.id),
              icon: Icon(
                liked ? Icons.bookmark : Icons.bookmark_outline,
                size: 20,
                color: liked
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFBDBDBD),
              ),
              tooltip: liked ? 'Remove from following' : 'Follow series',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOngoing = status == 'ongoing';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOngoing
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF5F4F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOngoing ? 'Ongoing' : 'Finished',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isOngoing
              ? const Color(0xFF16A34A)
              : const Color(0xFF6B6B6B),
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
    ];
    return colors[title.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _color(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}