import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../models/series.dart';
import '../../viewmodels/chapter_viewmodel.dart';
import '../../services/pocketbase_service.dart';
import 'widgets/image_upload_section.dart';

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
  final List<File> _selectedImages = [];
  String _selectedStatus = 'ongoing';

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
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ongoing',
                            child: Text('Ongoing'),
                          ),
                          DropdownMenuItem(
                            value: 'finished',
                            child: Text('Finished'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedStatus = value);
                          }
                        },
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
                      const SizedBox(height: 16),
                      ImageUploadSection(
                        selectedImages: _selectedImages,
                        onImagesChanged: (images) {
                          setState(() {
                            _selectedImages.clear();
                            _selectedImages.addAll(images);
                          });
                        },
                        textController: _sourceTextController,
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

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Saving chapter...'),
          ],
        ),
      ),
    );

    try {
      final pb = PocketBaseService().pb;

      // Prepare chapter data
      final chapterData = {
        'series_id': widget.series.id,
        'chapter_number': int.parse(_chapterNumberController.text),
        'chapter_title': _chapterTitleController.text.isEmpty
            ? null
            : _chapterTitleController.text,
        'source_text': _sourceTextController.text,
        'translation_status': 'pending',
        'status': _selectedStatus,
        'word_count': _sourceTextController.text.length,
      };

      // Create chapter
      final record = await pb.collection('chapters').create(body: chapterData);

      print('Chapter created with ID: ${record.id}');

      // Upload images if any
      if (_selectedImages.isNotEmpty) {
        print('Uploading ${_selectedImages.length} images...');

        final files = _selectedImages.map((file) {
          return http.MultipartFile.fromBytes(
            'images',
            file.readAsBytesSync(),
            filename: file.path.split(Platform.pathSeparator).last,
          );
        }).toList();

        await pb.collection('chapters').update(record.id, files: files);

        print('Images uploaded successfully');
      }

      // Refresh chapter list
      if (context.mounted) {
        final viewModel = context.read<ChapterViewModel>();
        await viewModel.fetchChapters(widget.series.id);

        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedImages.isEmpty
                  ? 'Chapter added successfully!'
                  : 'Chapter and ${_selectedImages.length} image(s) added!',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error saving chapter: $e');
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
