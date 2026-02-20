import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../services/pocketbase_service.dart';
import '../../services/reader_auth_service.dart';
import 'reader_series_screen.dart';

class ReaderFollowedScreen extends StatefulWidget {
  const ReaderFollowedScreen({super.key});

  @override
  State<ReaderFollowedScreen> createState() => _ReaderFollowedScreenState();
}

class _ReaderFollowedScreenState extends State<ReaderFollowedScreen> {
  List<Series> _followedSeries = [];
  bool _loading = true;
  final _pb = PocketBaseService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<ReaderAuthService>();
    final ids = auth.likedSeriesIds;

    if (ids.isEmpty) {
      setState(() {
        _followedSeries = [];
        _loading = false;
      });
      return;
    }

    try {
      final filter = ids.map((id) => 'id = "$id"').join(' || ');
      final records =
          await _pb.pb.collection('series').getFullList(filter: filter);
      if (mounted) {
        setState(() {
          _followedSeries =
              records.map((r) => Series.fromJson(r.toJson())).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-load when liked IDs change
    context.watch<ReaderAuthService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Following',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 20),
                color: const Color(0xFF9E9E9E),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1A1A1A),
                    strokeWidth: 2,
                  ),
                )
              : _followedSeries.isEmpty
                  ? _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      itemCount: _followedSeries.length,
                      itemBuilder: (_, i) =>
                          _FollowedSeriesCard(series: _followedSeries[i]),
                    ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_outline,
            size: 52,
            color: const Color(0xFFE0DED8),
          ),
          const SizedBox(height: 16),
          Text(
            'No followed series yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookmark series from Browse to see them here.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowedSeriesCard extends StatelessWidget {
  final Series series;
  const _FollowedSeriesCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<ReaderAuthService>();
    final progress = auth.getProgress(series.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderSeriesScreen(series: series),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0EEE9)),
          ),
          child: Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 78,
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

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.translatedTitle ?? series.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'by ${series.author}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.history,
                            size: 13,
                            color: const Color(0xFF6B6B6B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Last read: Ch. ${progress['chapterNumber']}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF6B6B6B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Actions
              Column(
                children: [
                  // Unfollow
                  IconButton(
                    onPressed: () => auth.toggleLike(series.id),
                    icon: const Icon(Icons.bookmark, size: 20),
                    color: const Color(0xFF1A1A1A),
                    tooltip: 'Unfollow',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 12),
                  // Read
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      progress != null ? 'Continue' : 'Read',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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