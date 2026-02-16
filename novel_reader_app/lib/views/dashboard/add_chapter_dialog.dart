import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../models/chapter.dart';
import '../../viewmodels/chapter_viewmodel.dart';

class AddChapterDialog extends StatefulWidget {
  final Series series;

  const AddChapterDialog({super.key, required this.series});

  @override
  State<AddChapterDialog> createState() => _AddChapterDialogState();
}

class _AddChapterDialogState extends State<AddChapterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _chapterNumberController = TextEditingController();
  final _chapterTitleController = TextEditingController();
  final _sourceTextController = TextEditingController();

  @override
  void dispose() {
    _chapterNumberController.dispose();
    _chapterTitleController.dispose();
    _sourceTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Chapter to ${widget.series.title}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _chapterNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Chapter Number *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _chapterTitleController,
                              decoration: const InputDecoration(
                                labelText: 'Chapter Title (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sourceTextController,
                        decoration: const InputDecoration(
                          labelText: 'Source Text *',
                          border: OutlineInputBorder(),
                          hintText: 'Paste the chapter content here...',
                        ),
                        maxLines: 15,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter chapter content';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_sourceTextController.text.length} characters',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _saveChapter(context),
                    child: const Text('Add Chapter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveChapter(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final chapter = Chapter(
      id: '',
      seriesId: widget.series.id,
      chapterNumber: int.parse(_chapterNumberController.text),
      chapterTitle: _chapterTitleController.text.isEmpty
          ? null
          : _chapterTitleController.text,
      sourceText: _sourceTextController.text,
      translationStatus: 'pending',
      wordCount: _sourceTextController.text.length,
      created: DateTime.now(),
      updated: DateTime.now(),
    );

    final viewModel = context.read<ChapterViewModel>();
    final success = await viewModel.addChapter(chapter);

    if (success && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chapter added successfully!')),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Failed to add chapter'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
