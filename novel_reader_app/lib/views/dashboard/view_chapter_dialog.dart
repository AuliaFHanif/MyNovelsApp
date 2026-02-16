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
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  chapter.sourceText,
                  style: const TextStyle(fontSize: 16, height: 1.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
