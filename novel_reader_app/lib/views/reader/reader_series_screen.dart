import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../models/chapter.dart';
import '../../models/translation.dart';
import '../../services/pocketbase_service.dart';
import '../../services/reader_auth_service.dart';
import 'reader_screen.dart';

class ReaderSeriesScreen extends StatefulWidget {
  final Series series;
  final Chapter? autoOpenChapter;

  const ReaderSeriesScreen({
    super.key,
    required this.series,
    this.autoOpenChapter,
  });

  @override
  State<ReaderSeriesScreen> createState() => _ReaderSeriesScreenState();
}

class _ReaderSeriesScreenState extends State<ReaderSeriesScreen> {
  List<Chapter> _chapters = [];
  bool _loading = true;
  final _pb = PocketBaseService();

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (widget.autoOpenChapter != null && mounted) {
        _openChapter(widget.autoOpenChapter!);
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final records = await _pb.pb
          .collection('chapters')
          .getFullList(
            filter:
                'series_id = "${widget.series.id}" && translation_status = "completed"',
            sort: 'chapter_number',
          );
      if (mounted) {
        setState(() {
          _chapters =
              records.map((r) => Chapter.fromJson(r.toJson())).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Translation?> _fetchTranslation(String chapterId) async {
    try {
      final records = await _pb.pb
          .collection('translations')
          .getList(filter: 'chapter_id = "$chapterId"', sort: '-created');
      if (records.items.isNotEmpty) {
        return Translation.fromJson(records.items.first.toJson());
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openChapter(Chapter chapter) async {
    // Save progress
    final auth = context.read<ReaderAuthService>();
    await auth.saveProgress(
      widget.series.id,
      chapter.id,
      chapter.chapterNumber,
      chapter.chapterTitle ?? 'Chapter ${chapter.chapterNumber}',
    );

    final translation = await _fetchTranslation(chapter.id);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            series: widget.series,
            chapter: chapter,
            translation: translation,
            allChapters: _chapters,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ReaderAuthService>();
    final liked = auth.isLiked(widget.series.id);
    final progress = auth.getProgress(widget.series.id);
    final series = widget.series;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      body: Row(
        children: [
          // ─── Left: Series info panel ───
          Container(
            width: 300,
            color: Colors.white,
            child: Column(
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 20),
                      color: const Color(0xFF6B6B6B),
                      tooltip: 'Back',
                    ),
                  ),
                ),

                // Cover
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
                ),

                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            series.translatedTitle ?? series.title,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          if (series.translatedTitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              series.title,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF9E9E9E),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'by ${series.author}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF6B6B6B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _Badge(
                                label: series.sourceLanguage,
                                bg: const Color(0xFFF5F4F1),
                                color: const Color(0xFF6B6B6B),
                              ),
                              const SizedBox(width: 8),
                              _Badge(
                                label: series.status == 'ongoing'
                                    ? 'Ongoing'
                                    : 'Finished',
                                bg: series.status == 'ongoing'
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFF5F4F1),
                                color: series.status == 'ongoing'
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF6B6B6B),
                              ),
                            ],
                          ),
                          if (series.description != null &&
                              series.description!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              series.description!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF6B6B6B),
                                height: 1.6,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Follow & Read buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => auth.toggleLike(series.id),
                                  icon: Icon(
                                    liked
                                        ? Icons.bookmark
                                        : Icons.bookmark_outline,
                                    size: 16,
                                  ),
                                  label: Text(
                                      liked ? 'Following' : 'Follow'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: liked
                                        ? const Color(0xFF1A1A1A)
                                        : const Color(0xFF6B6B6B),
                                    side: BorderSide(
                                      color: liked
                                          ? const Color(0xFF1A1A1A)
                                          : const Color(0xFFE0DED8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    textStyle:
                                        GoogleFonts.inter(fontSize: 13),
                                  ),
                                ),
                              ),
                              if (progress != null) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final chapter = _chapters.firstWhere(
                                        (c) =>
                                            c.id ==
                                            progress['chapterId'],
                                        orElse: () => _chapters.first,
                                      );
                                      _openChapter(chapter);
                                    },
                                    icon: const Icon(Icons.play_arrow,
                                        size: 16),
                                    label: const Text('Continue'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF1A1A1A),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      textStyle:
                                          GoogleFonts.inter(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Right: Chapter list ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF9F7),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF0EEE9)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Chapters',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EEE9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_chapters.length} translated',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chapter list
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1A1A1A),
                            strokeWidth: 2,
                          ),
                        )
                      : _chapters.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.hourglass_empty,
                                      size: 40,
                                      color: const Color(0xFFE0DED8)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No translated chapters yet.',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFF9E9E9E),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  32, 8, 32, 32),
                              itemCount: _chapters.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: Color(0xFFF0EEE9),
                              ),
                              itemBuilder: (_, i) {
                                final chapter = _chapters[i];
                                final isLast =
                                    progress != null &&
                                        progress['chapterId'] == chapter.id;
                                return _ChapterRow(
                                  chapter: chapter,
                                  isLastRead: isLast,
                                  onTap: () => _openChapter(chapter),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chapter row ───

class _ChapterRow extends StatelessWidget {
  final Chapter chapter;
  final bool isLastRead;
  final VoidCallback onTap;

  const _ChapterRow({
    required this.chapter,
    required this.isLastRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Chapter number
            SizedBox(
              width: 48,
              child: Text(
                '${chapter.chapterNumber}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFBDBDBD),
                ),
              ),
            ),

            // Title & meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chapter.chapterTitle ??
                              'Chapter ${chapter.chapterNumber}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLastRead)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Last read',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _wordCount(chapter),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }

  String _wordCount(Chapter chapter) {
    final count = chapter.wordCount ??
        chapter.sourceText.split(' ').length;
    if (count > 1000) {
      return '~${(count / 1000).toStringAsFixed(1)}k chars';
    }
    return '$count chars';
  }
}

// ─── Badge ───

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color color;

  const _Badge({
    required this.label,
    required this.bg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
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