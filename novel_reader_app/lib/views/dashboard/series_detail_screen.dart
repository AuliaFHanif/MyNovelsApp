import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../models/chapter.dart';
import '../../viewmodels/chapter_viewmodel.dart';
import '../../viewmodels/series_viewmodel.dart';
import 'add_chapter_dialog.dart';
import 'view_chapter_dialog.dart';
import 'edit_chapter_dialog.dart';
import 'translation_progress_dialog.dart';
import '../../viewmodels/translation_viewmodel.dart';
import 'view_translation_dialog.dart';
import '../../services/pocketbase_service.dart';
import 'edit_series_context_dialog.dart';
import 'edit_series_dialog.dart';

class SeriesDetailScreen extends StatefulWidget {
  final Series series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  late Series _currentSeries;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentSeries = widget.series;
    Future.microtask(
      () => context.read<ChapterViewModel>().fetchChapters(widget.series.id),
    );
  }

  Future<void> _refreshSeries() async {
    final seriesViewModel = context.read<SeriesViewModel>();
    await seriesViewModel.fetchSeries();
    final updatedSeries = seriesViewModel.seriesList.firstWhere(
      (s) => s.id == widget.series.id,
      orElse: () => _currentSeries,
    );
    setState(() {
      _currentSeries = updatedSeries;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Novel Library'),
        backgroundColor: const Color(0xFF5B7FEC),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 280,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Book Cover
                Container(
                  height: 200,
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _currentSeries.coverImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            'http://127.0.0.1:8090/api/files/series/${_currentSeries.id}/${_currentSeries.coverImage!}',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.menu_book,
                                  size: 80,
                                  color: Colors.white70,
                                ),
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.menu_book,
                          size: 80,
                          color: Colors.white70,
                        ),
                ),
                // Series Info (Scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            _currentSeries.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_currentSeries.translatedTitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _currentSeries.translatedTitle!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'by ${_currentSeries.author}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Status Badge
                          Row(
                            children: [
                              const Text(
                                'STATUS',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    _currentSeries.status,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _currentSeries.status == 'ongoing'
                                      ? 'Ongoing'
                                      : 'Finished',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getStatusColor(
                                      _currentSeries.status,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Source Badge
                          Row(
                            children: [
                              const Text(
                                'SOURCE LANGUAGE',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Icon(
                                    Icons.language,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _currentSeries.sourceLanguage,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Total Chapters
                          Consumer<ChapterViewModel>(
                            builder: (context, viewModel, child) {
                              return Row(
                                children: [
                                  const Text(
                                    'TOTAL CHAPTERS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${viewModel.chaptersList.length}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          // Description
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentSeries.description ??
                                'No description available.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Edit Buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _editSeries(context),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Edit Series Information'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _editContext(context),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Context & Glossary'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Consumer<ChapterViewModel>(
              builder: (context, viewModel, child) {
                return Column(
                  children: [
                    // Toolbar
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          // Search
                          SizedBox(
                            width: 300,
                            child: TextField(
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search chapters...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Consumer<ChapterViewModel>(
                            builder: (context, vm, child) {
                              final filtered = _filterChapters(vm.chaptersList);
                              return Text(
                                'Showing ${filtered.length} of ${vm.chaptersList.length} items',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Chapter Table
                    Expanded(child: _buildChapterTable(context, viewModel)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddChapterDialog(context),
        backgroundColor: const Color(0xFF5B7FEC),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Chapter> _filterChapters(List<Chapter> chapters) {
    if (_searchQuery.isEmpty) {
      return chapters;
    }

    return chapters.where((chapter) {
      final numberMatch = chapter.chapterNumber.toString().contains(
        _searchQuery,
      );
      final titleMatch =
          chapter.chapterTitle?.toLowerCase().contains(_searchQuery) ?? false;
      final contentMatch = chapter.sourceText.toLowerCase().contains(
        _searchQuery,
      );

      return numberMatch || titleMatch || contentMatch;
    }).toList();
  }

  Widget _buildChapterTable(BuildContext context, ChapterViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(viewModel.errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.fetchChapters(widget.series.id),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (viewModel.chaptersList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'No chapters yet',
              style: TextStyle(fontSize: 20, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap + to add your first chapter',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final filteredChapters = _filterChapters(viewModel.chaptersList);

    if (filteredChapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'No chapters found',
              style: TextStyle(fontSize: 20, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Text(
              'Try searching with different keywords',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'TITLE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 120,
                  child: Text(
                    'LENGTH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 140,
                  child: Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Container(
                  width: 80,
                  alignment: Alignment.center,
                  child: const Text(
                    'ACTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: filteredChapters.length,
              itemBuilder: (context, index) {
                final chapter = filteredChapters[index];
                return _ChapterTableRow(
                  chapter: chapter,
                  seriesId: _currentSeries.id,
                  sourceLanguage: _currentSeries.sourceLanguage,
                  translationContext: _currentSeries.translationContext,
                  glossary: _currentSeries.glossary,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddChapterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddChapterDialog(series: widget.series),
    );
  }

  void _editContext(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditSeriesContextDialog(series: _currentSeries),
    );
    if (result == true && mounted) {
      await _refreshSeries();
    }
  }

  void _editSeries(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditSeriesDialog(series: _currentSeries),
    );
    if (result == true && mounted) {
      await _refreshSeries();
    }
  }

  Color _getStatusColor(String status) {
    return status == 'finished' ? Colors.blue[700]! : Colors.green[700]!;
  }
}

class _ChapterTableRow extends StatelessWidget {
  final Chapter chapter;
  final String seriesId;
  final String sourceLanguage;
  final String? translationContext;
  final Map<String, String>? glossary;

  const _ChapterTableRow({
    required this.chapter,
    required this.seriesId,
    required this.sourceLanguage,
    this.translationContext,
    this.glossary,
  });

  @override
  Widget build(BuildContext context) {
    Widget statusBadge;

    switch (chapter.translationStatus) {
      case 'completed':
        statusBadge = _buildStatusBadge('Completed', Colors.green);
        break;
      case 'processing':
        statusBadge = _buildStatusBadge('In Progress', Colors.orange);
        break;
      case 'failed':
        statusBadge = _buildStatusBadge('Failed', Colors.red);
        break;
      default:
        statusBadge = _buildStatusBadge('Pending', Colors.grey);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: InkWell(
        onTap: () => _viewChapter(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Chapter Number
              SizedBox(
                width: 60,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B7FEC).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${chapter.chapterNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B7FEC),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              // Title
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.chapterTitle ??
                          'Chapter ${chapter.chapterNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Original: ${chapter.chapterTitle ?? "Chapter ${chapter.chapterNumber}"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Length
              SizedBox(
                width: 120,
                child: Text(
                  '${chapter.sourceText.length.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} chars',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
              // Status
              SizedBox(width: 140, child: statusBadge),
              // Actions
              SizedBox(
                width: 80,
                child: PopupMenuButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  itemBuilder: (context) {
                    final hasTranslation =
                        chapter.translationStatus == 'completed';

                    return [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 18),
                            SizedBox(width: 8),
                            Text('View Source'),
                          ],
                        ),
                      ),
                      if (hasTranslation)
                        const PopupMenuItem(
                          value: 'view_translation',
                          child: Row(
                            children: [
                              Icon(
                                Icons.translate,
                                size: 18,
                                color: Colors.green,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'View Translation',
                                style: TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: Colors.blue)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'translate',
                        child: Row(
                          children: [
                            Icon(
                              hasTranslation ? Icons.refresh : Icons.translate,
                              size: 18,
                              color: hasTranslation ? Colors.orange : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              hasTranslation ? 'Re-translate' : 'Translate',
                              style: TextStyle(
                                color: hasTranslation ? Colors.orange : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ];
                  },
                  onSelected: (value) {
                    if (value == 'view') {
                      _viewChapter(context);
                    } else if (value == 'view_translation') {
                      _viewTranslation(context);
                    } else if (value == 'edit') {
                      _editChapter(context);
                    } else if (value == 'delete') {
                      _deleteChapter(context);
                    } else if (value == 'translate') {
                      _translateChapter(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _deleteChapter(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: Text('Delete Chapter ${chapter.chapterNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final viewModel = context.read<ChapterViewModel>();
              await viewModel.deleteChapter(chapter.id, seriesId);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editChapter(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EditChapterDialog(chapter: chapter),
    );
  }

  void _translateChapter(BuildContext context) async {
    // Check if already translated
    if (chapter.translationStatus == 'completed') {
      final shouldRetranslate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 12),
              Text('Re-translate Chapter?'),
            ],
          ),
          content: const Text(
            'This chapter already has a translation. Re-translating will:\n\n'
            '• Delete the existing translation\n'
            '• Use AI tokens/time again\n'
            '• May produce different results\n\n'
            'Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Re-translate'),
            ),
          ],
        ),
      );

      if (shouldRetranslate != true) return;

      // Delete existing translation
      final translationViewModel = context.read<TranslationViewModel>();
      final existingTranslation = await translationViewModel.getTranslation(
        chapter.id,
      );
      if (existingTranslation != null && context.mounted) {
        try {
          await context
              .read<PocketBaseService>()
              .pb
              .collection('translations')
              .delete(existingTranslation.id);
        } catch (e) {
          print('Failed to delete existing translation: $e');
        }
      }
    }

    // First, check LM Studio connection
    final translationViewModel = context.read<TranslationViewModel>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Checking LM Studio connection...'),
          ],
        ),
      ),
    );

    final isConnected = await translationViewModel.testLMStudioConnection();

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog
    }

    if (!isConnected) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 12),
                Text('LM Studio Not Available'),
              ],
            ),
            content: const Text(
              'Cannot connect to LM Studio. Please make sure:\n\n'
              '1. LM Studio is running\n'
              '2. A model is loaded\n'
              '3. The API server is started\n'
              '4. Server is listening on localhost:1234',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Get series to determine source language
    // For now, we'll ask the user or use a default
    // In a real app, you'd get this from the series
    final sourceLanguage = 'Chinese'; // TODO: Get from series

    if (context.mounted) {
      final success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => TranslationProgressDialog(
          chapter: chapter,
          sourceLanguage: sourceLanguage,
          seriesContext: translationContext,
          glossary: glossary,
        ),
      );

      if (success == true && context.mounted) {
        // Refresh the chapter list to show updated status
        context.read<ChapterViewModel>().fetchChapters(seriesId);
      }
    }
  }

  void _viewChapter(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ViewChapterDialog(chapter: chapter),
    );
  }

  void _viewTranslation(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Fetch translation
    final translationViewModel = context.read<TranslationViewModel>();
    final translation = await translationViewModel.getTranslation(chapter.id);

    if (context.mounted) {
      Navigator.pop(context); // Close loading
    }

    if (translation == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No translation found for this chapter'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) =>
            ViewTranslationDialog(chapter: chapter, translation: translation),
      );
    }
  }
}
