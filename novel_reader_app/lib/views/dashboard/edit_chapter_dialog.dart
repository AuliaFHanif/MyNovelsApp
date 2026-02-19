import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../models/chapter.dart';
import '../../viewmodels/chapter_viewmodel.dart';
import '../../services/pocketbase_service.dart';
import 'package:provider/provider.dart';
import 'widgets/image_upload_section.dart';

class EditChapterDialog extends StatefulWidget {
  final Chapter chapter;

  const EditChapterDialog({super.key, required this.chapter});

  @override
  State<EditChapterDialog> createState() => _EditChapterDialogState();
}

class _EditChapterDialogState extends State<EditChapterDialog> {
  late final TextEditingController _chapterNumberController;
  late final TextEditingController _titleController;
  late final TextEditingController _sourceTextController;
  final List<File> _selectedImages = [];
  late String _selectedStatus;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  int _characterCount = 0;

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing chapter data
    _chapterNumberController = TextEditingController(
      text: widget.chapter.chapterNumber.toString(),
    );
    _titleController = TextEditingController(
      text: widget.chapter.chapterTitle ?? '',
    );
    _sourceTextController = TextEditingController(
      text: widget.chapter.sourceText,
    );
    _selectedStatus = widget.chapter.status;
    _characterCount = widget.chapter.sourceText.length;

    _sourceTextController.addListener(_updateCharacterCount);

    // Debug existing images
    print('DEBUG - Chapter ID: ${widget.chapter.id}');
    print('DEBUG - Chapter images field: ${widget.chapter.images}');
    print('DEBUG - Images is null? ${widget.chapter.images == null}');
    print('DEBUG - Images isEmpty? ${widget.chapter.images?.isEmpty}');
    if (widget.chapter.images != null) {
      for (var i = 0; i < widget.chapter.images!.length; i++) {
        print('DEBUG - Image $i: "${widget.chapter.images![i]}"');
      }
    }
  }

  void _updateCharacterCount() {
    setState(() {
      _characterCount = _sourceTextController.text.length;
    });
  }

  @override
  void dispose() {
    _chapterNumberController.dispose();
    _titleController.dispose();
    _sourceTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.edit, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Edit Chapter',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    'ID: ${widget.chapter.id.substring(0, 8)}...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Chapter Number & Title Row
              Row(
                children: [
                  // Chapter Number
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _chapterNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Chapter Number *',
                        hintText: 'e.g., 1',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Chapter Title
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Chapter Title',
                        hintText: 'Optional title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chapter Status
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Chapter Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                  DropdownMenuItem(value: 'finished', child: Text('Finished')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedStatus = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Character Count & Status
              Row(
                children: [
                  Chip(
                    avatar: const Icon(Icons.text_fields, size: 18),
                    label: Text('$_characterCount characters'),
                    backgroundColor: Colors.blue[50],
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: Icon(
                      _getStatusIcon(widget.chapter.translationStatus),
                      size: 18,
                      color: _getStatusColor(widget.chapter.translationStatus),
                    ),
                    label: Text(widget.chapter.translationStatus),
                    backgroundColor: _getStatusColor(
                      widget.chapter.translationStatus,
                    ).withOpacity(0.1),
                  ),
                  const Spacer(),
                  // Warning if chapter has translation
                  if (widget.chapter.translationStatus == 'completed')
                    Tooltip(
                      message:
                          'Editing will reset translation status to pending',
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Will reset translation',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Source Text Label
              Row(
                children: [
                  const Text(
                    'Source Text *',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.paste, size: 18),
                    label: const Text('Paste'),
                  ),
                  TextButton.icon(
                    onPressed: _clearText,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Source Text Field and Image Section
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _sourceTextController,
                        decoration: const InputDecoration(
                          hintText: 'Paste chapter content here...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 12,
                        textAlignVertical: TextAlignVertical.top,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Source text is required';
                          }
                          if (value.length < 10) {
                            return 'Text too short (min 10 chars)';
                          }
                          return null;
                        },
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
                        existingImageUrls: _getExistingImageUrls(),
                        textController: _sourceTextController,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveChapter,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
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

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      final currentText = _sourceTextController.text;
      final newText = currentText.isEmpty
          ? clipboardData!.text!
          : '$currentText\n\n${clipboardData!.text}';
      _sourceTextController.text = newText;
      // Move cursor to end
      _sourceTextController.selection = TextSelection.fromPosition(
        TextPosition(offset: _sourceTextController.text.length),
      );
    }
  }

  void _clearText() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Text?'),
        content: const Text('This will remove all source text. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _sourceTextController.clear();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _saveChapter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Determine new translation status
      String newStatus = widget.chapter.translationStatus;
      if (widget.chapter.sourceText != _sourceTextController.text) {
        // Text changed - reset to pending
        newStatus = 'pending';
      }

      // Create updated chapter with same id and created time
      final updatedChapter = Chapter(
        id: widget.chapter.id,
        seriesId: widget.chapter.seriesId,
        chapterNumber: int.parse(_chapterNumberController.text),
        chapterTitle: _titleController.text.isEmpty
            ? null
            : _titleController.text,
        sourceText: _sourceTextController.text,
        translationStatus: newStatus,
        status: _selectedStatus,
        wordCount:
            _characterCount, // Update word count to current character count
        created: widget.chapter.created, // Keep original creation time
        updated: DateTime.now(), // Set new update time
      );

      final viewModel = context.read<ChapterViewModel>();
      final success = await viewModel.updateChapter(updatedChapter);

      if (!success) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                viewModel.errorMessage ?? 'Failed to update chapter',
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Upload new images if any were selected
      if (_selectedImages.isNotEmpty) {
        print('Uploading ${_selectedImages.length} new images...');

        final pb = PocketBaseService().pb;
        final files = _selectedImages.map((file) {
          return http.MultipartFile.fromBytes(
            'images',
            file.readAsBytesSync(),
            filename: file.path.split(Platform.pathSeparator).last,
          );
        }).toList();

        await pb.collection('chapters').update(widget.chapter.id, files: files);

        print('Images uploaded successfully');

        // Refresh chapters to get updated image list
        await viewModel.fetchChapters(widget.chapter.seriesId);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedImages.isEmpty
                  ? 'Chapter updated successfully'
                  : 'Chapter and ${_selectedImages.length} image(s) updated!',
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      print('Error saving chapter: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'processing':
        return Icons.hourglass_empty;
      case 'failed':
        return Icons.error;
      default:
        return Icons.pending;
    }
  }

  List<String>? _getExistingImageUrls() {
    if (widget.chapter.images == null || widget.chapter.images!.isEmpty) {
      return null;
    }

    return widget.chapter.images!.map((filename) {
      return 'http://127.0.0.1:8090/api/files/chapters/${widget.chapter.id}/$filename';
    }).toList();
  }
}
