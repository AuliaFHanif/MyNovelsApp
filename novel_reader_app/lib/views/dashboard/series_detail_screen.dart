import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../models/chapter.dart';
import '../../viewmodels/chapter_viewmodel.dart';
import 'add_chapter_dialog.dart';
import 'view_chapter_dialog.dart';
import 'edit_chapter_dialog.dart';

class SeriesDetailScreen extends StatefulWidget {
  final Series series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<ChapterViewModel>().fetchChapters(widget.series.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ChapterViewModel>().fetchChapters(
              widget.series.id,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Series Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.series.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${widget.series.author}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                if (widget.series.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.series.description!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          // Chapters List
          Expanded(
            child: Consumer<ChapterViewModel>(
              builder: (context, viewModel, child) {
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
                          onPressed: () =>
                              viewModel.fetchChapters(widget.series.id),
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
                        Icon(
                          Icons.article_outlined,
                          size: 100,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No chapters yet',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap + to add your first chapter',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: viewModel.chaptersList.length,
                  itemBuilder: (context, index) {
                    final chapter = viewModel.chaptersList[index];
                    return _ChapterListItem(
                      chapter: chapter,
                      seriesId: widget.series.id,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddChapterDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddChapterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddChapterDialog(series: widget.series),
    );
  }
}

class _ChapterListItem extends StatelessWidget {
  final Chapter chapter;
  final String seriesId;

  const _ChapterListItem({required this.chapter, required this.seriesId});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;

    switch (chapter.translationStatus) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'processing':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default: // pending
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('${chapter.chapterNumber}')),
        title: Text(
          chapter.chapterTitle ?? 'Chapter ${chapter.chapterNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${chapter.sourceText.length} characters • ${chapter.translationStatus}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 8),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 20),
                      SizedBox(width: 8),
                      Text('View'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  // <-- ADD THIS
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Edit', style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'translate',
                  child: Row(
                    children: [
                      Icon(Icons.translate, size: 20),
                      SizedBox(width: 8),
                      Text('Translate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'view') {
                  _viewChapter(context);
                } else if (value == 'edit') {
                  // <-- ADD THIS CASE
                  _editChapter(context);
                } else if (value == 'delete') {
                  _deleteChapter(context);
                } else if (value == 'translate') {
                  _translateChapter(context);
                }
              },
            ),
          ],
        ),
      ),
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

  void _translateChapter(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Translation feature coming in Phase 4!')),
    );
  }

  void _viewChapter(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ViewChapterDialog(chapter: chapter),
    );
  }
}
