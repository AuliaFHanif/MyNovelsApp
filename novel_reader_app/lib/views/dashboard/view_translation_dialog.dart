import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chapter.dart';
import '../../models/translation.dart';
import 'edit_translation_dialog.dart';

class ViewTranslationDialog extends StatelessWidget {
  final Chapter chapter;
  final Translation translation;

  const ViewTranslationDialog({
    super.key,
    required this.chapter,
    required this.translation,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.chapterTitle ??
                            'Chapter ${chapter.chapterNumber}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chapter ${chapter.chapterNumber} • Translation',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Translation Info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Translated',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pop(context); // Close view dialog
                    showDialog(
                      context: context,
                      builder: (context) => EditTranslationDialog(
                        chapter: chapter,
                        translation: translation,
                      ),
                    );
                  },
                  tooltip: 'Edit translation',
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: translation.translatedText),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Translation copied to clipboard'),
                      ),
                    );
                  },
                  tooltip: 'Copy translation',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // Translation metadata
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (translation.modelUsed != null)
                  _buildInfoChip(
                    Icons.psychology,
                    'Model: ${translation.modelUsed}',
                    Colors.blue,
                  ),
                if (translation.translationTime != null)
                  _buildInfoChip(
                    Icons.timer,
                    'Time: ${_formatDuration(translation.translationTime!)}',
                    Colors.orange,
                  ),
                if (translation.chunkCount != null)
                  _buildInfoChip(
                    Icons.grid_on,
                    'Chunks: ${translation.chunkCount}',
                    Colors.purple,
                  ),
                _buildInfoChip(
                  Icons.text_fields,
                  '${translation.translatedText.length} characters',
                  Colors.green,
                ),
              ],
            ),

            const Divider(height: 24),

            // Translated Content with inline images
            Expanded(
              child: SingleChildScrollView(
                child: _buildTextWithImages(
                  translation.translatedText,
                  chapter.images,
                  chapter.id,
                  context,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    }
  }

  Widget _buildTextWithImages(
    String text,
    List<String>? images,
    String chapterId,
    BuildContext ctx,
  ) {
    // If no images or no markers, just show text
    if (images == null || images.isEmpty || !text.contains('[Image ')) {
      return SelectableText(
        text,
        style: const TextStyle(fontSize: 16, height: 1.8),
      );
    }

    // Parse text and insert images
    final parts = <Widget>[];
    final pattern = RegExp(r'\[Image (\d+)\]');
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Add text before marker
      if (match.start > lastEnd) {
        parts.add(
          SelectableText(
            text.substring(lastEnd, match.start),
            style: const TextStyle(fontSize: 16, height: 1.8),
          ),
        );
      }

      // Add image
      final imageNumber = int.parse(match.group(1)!);
      if (imageNumber > 0 && imageNumber <= images.length) {
        final imageUrl = _getImageUrl(chapterId, images[imageNumber - 1]);
        parts.add(_buildInlineImage(imageUrl, imageNumber, ctx));
      }

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      parts.add(
        SelectableText(
          text.substring(lastEnd),
          style: const TextStyle(fontSize: 16, height: 1.8),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts,
    );
  }

  Widget _buildInlineImage(String imageUrl, int imageNumber, BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showFullImage(ctx, imageUrl),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image, size: 48),
                          const SizedBox(height: 8),
                          Text('Failed to load Image $imageNumber'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Image $imageNumber',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _getImageUrl(String chapterId, String filename) {
    return 'http://127.0.0.1:8090/api/files/chapters/$chapterId/$filename';
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(imageUrl)),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
