import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chapter.dart';

class ViewChapterDialog extends StatelessWidget {
  final Chapter chapter;

  const ViewChapterDialog({super.key, required this.chapter});

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
                        'Chapter ${chapter.chapterNumber} • ${chapter.sourceText.length} characters',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: chapter.sourceText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                  tooltip: 'Copy text',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Images Section
            if (chapter.images != null && chapter.images!.isNotEmpty) ...[
              const Text(
                'Chapter Images',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: chapter.images!.length,
                  itemBuilder: (context, index) {
                    final imageUrl = _getImageUrl(
                      chapter.id,
                      chapter.images![index],
                    );
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _showFullImage(context, imageUrl),
                        child: Container(
                          width: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 48,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 24),
            ],

            // Content with inline images
            Expanded(
              child: SingleChildScrollView(
                child: _buildTextWithImages(chapter, context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getImageUrl(String chapterId, String filename) {
    // PocketBase image URL format
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

  Widget _buildTextWithImages(Chapter chapter, BuildContext ctx) {
    final text = chapter.sourceText;
    final images = chapter.images;

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
        final imageUrl = _getImageUrl(chapter.id, images[imageNumber - 1]);
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
}
