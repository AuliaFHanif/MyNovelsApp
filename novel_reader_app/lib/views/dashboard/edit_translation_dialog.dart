import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chapter.dart';
import '../../models/translation.dart';
import '../../viewmodels/translation_viewmodel.dart';
import 'package:provider/provider.dart';

class EditTranslationDialog extends StatefulWidget {
  final Chapter chapter;
  final Translation translation;

  const EditTranslationDialog({
    super.key,
    required this.chapter,
    required this.translation,
  });

  @override
  State<EditTranslationDialog> createState() => _EditTranslationDialogState();
}

class _EditTranslationDialogState extends State<EditTranslationDialog> {
  late final TextEditingController _translatedTextController;
  late final TextEditingController _modelUsedController;
  int? _qualityRating;
  
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  int _characterCount = 0;

  @override
  void initState() {
    super.initState();
    _translatedTextController = TextEditingController(
      text: widget.translation.translatedText,
    );
    _modelUsedController = TextEditingController(
      text: widget.translation.modelUsed ?? '',
    );
    _qualityRating = widget.translation.qualityRating;
    _characterCount = widget.translation.translatedText.length;
    
    _translatedTextController.addListener(_updateCharacterCount);
  }

  void _updateCharacterCount() {
    setState(() {
      _characterCount = _translatedTextController.text.length;
    });
  }

  @override
  void dispose() {
    _translatedTextController.dispose();
    _modelUsedController.dispose();
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
                  const Icon(Icons.edit, size: 28, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Translation',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.chapter.chapterTitle ?? 'Chapter ${widget.chapter.chapterNumber}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Metadata Row
              Row(
                children: [
                  // Model Used
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _modelUsedController,
                      decoration: const InputDecoration(
                        labelText: 'Model Used',
                        hintText: 'e.g., Gemma 2 9B Q4',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.psychology),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Quality Rating
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quality Rating',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(5, (index) {
                            final rating = index + 1;
                            return IconButton(
                              icon: Icon(
                                rating <= (_qualityRating ?? 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                              ),
                              onPressed: () {
                                setState(() {
                                  _qualityRating = rating;
                                });
                              },
                              tooltip: '$rating star${rating > 1 ? 's' : ''}',
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Character Count & Info
              Row(
                children: [
                  Chip(
                    avatar: const Icon(Icons.text_fields, size: 18),
                    label: Text('$_characterCount characters'),
                    backgroundColor: Colors.blue[50],
                  ),
                  const SizedBox(width: 8),
                  if (widget.translation.translationTime != null)
                    Chip(
                      avatar: const Icon(Icons.timer, size: 18),
                      label: Text(_formatDuration(widget.translation.translationTime!)),
                      backgroundColor: Colors.orange[50],
                    ),
                  const SizedBox(width: 8),
                  if (widget.translation.chunkCount != null)
                    Chip(
                      avatar: const Icon(Icons.grid_on, size: 18),
                      label: Text('${widget.translation.chunkCount} chunks'),
                      backgroundColor: Colors.purple[50],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Translation Text Label
              Row(
                children: [
                  const Text(
                    'Translated Text *',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.paste, size: 18),
                    label: const Text('Paste'),
                  ),
                  TextButton.icon(
                    onPressed: _compareWithSource,
                    icon: const Icon(Icons.compare_arrows, size: 18),
                    label: const Text('Compare'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Translation Text Field
              Expanded(
                child: TextFormField(
                  controller: _translatedTextController,
                  decoration: const InputDecoration(
                    hintText: 'Edit the translation here...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Translation text is required';
                    }
                    if (value.length < 10) {
                      return 'Translation too short (min 10 chars)';
                    }
                    return null;
                  },
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
                    onPressed: _isSaving ? null : _saveTranslation,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
      final currentText = _translatedTextController.text;
      final newText = currentText.isEmpty 
          ? clipboardData!.text! 
          : '$currentText\n\n${clipboardData!.text}';
      _translatedTextController.text = newText;
      _translatedTextController.selection = TextSelection.fromPosition(
        TextPosition(offset: _translatedTextController.text.length),
      );
    }
  }

  void _compareWithSource() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 900,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Compare Source and Translation',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: Row(
                  children: [
                    // Source Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.blue[50],
                            child: const Row(
                              children: [
                                Icon(Icons.source, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Source Text',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: SelectableText(
                                widget.chapter.sourceText,
                                style: const TextStyle(fontSize: 14, height: 1.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    // Translation
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.green[50],
                            child: const Row(
                              children: [
                                Icon(Icons.translate, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Translation',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _translatedTextController.text,
                                style: const TextStyle(fontSize: 14, height: 1.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveTranslation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedTranslation = Translation(
      id: widget.translation.id,
      chapterId: widget.translation.chapterId,
      translatedText: _translatedTextController.text,
      modelUsed: _modelUsedController.text.isEmpty ? null : _modelUsedController.text,
      translationTime: widget.translation.translationTime,
      qualityRating: _qualityRating,
      chunkCount: widget.translation.chunkCount,
      created: widget.translation.created,
      updated: DateTime.now(),
    );

    final viewModel = context.read<TranslationViewModel>();
    final success = await viewModel.updateTranslation(updatedTranslation);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Translation updated successfully'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Failed to update translation'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
}