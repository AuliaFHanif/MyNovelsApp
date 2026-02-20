import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../viewmodels/series_viewmodel.dart';

class EditSeriesDialog extends StatefulWidget {
  final Series series;

  const EditSeriesDialog({super.key, required this.series});

  @override
  State<EditSeriesDialog> createState() => _EditSeriesDialogState();
}

class _EditSeriesDialogState extends State<EditSeriesDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _translatedTitleController;
  late final TextEditingController _authorController;
  late final TextEditingController _descriptionController;
  late String _selectedLanguage;
  late String _selectedStatus;
  bool _isSaving = false;

  final List<String> _languages = [
    'Chinese',
    'Japanese',
    'Korean',
    'English',
    'Spanish',
    'French',
    'German',
    'Russian',
    'Arabic',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.series.title);
    _translatedTitleController = TextEditingController(
      text: widget.series.translatedTitle ?? '',
    );
    _authorController = TextEditingController(text: widget.series.author);
    _descriptionController = TextEditingController(
      text: widget.series.description ?? '',
    );
    _selectedLanguage = widget.series.sourceLanguage;
    _selectedStatus = widget.series.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _translatedTitleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.edit_note, size: 28, color: Color(0xFF5B7FEC)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Edit Series Information',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 32),

            // Form
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      'Title',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Enter series title',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Translated Title
                    const Text(
                      'Translated Title',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _translatedTitleController,
                      decoration: const InputDecoration(
                        hintText: 'Enter translated title (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Author
                    const Text(
                      'Author',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _authorController,
                      decoration: const InputDecoration(
                        hintText: 'Enter author name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Source Language
                    const Text(
                      'Source Language',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLanguage,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _languages.map((language) {
                        return DropdownMenuItem(
                          value: language,
                          child: Text(language),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedLanguage = value);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Status
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
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

                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Enter series description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
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
                  onPressed: _isSaving ? null : _saveSeries,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B7FEC),
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
    );
  }

  Future<void> _saveSeries() async {
    // Validation
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title cannot be empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_authorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Author cannot be empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Update series
    final updatedSeries = Series(
      id: widget.series.id,
      title: _titleController.text.trim(),
      translatedTitle: _translatedTitleController.text.trim().isEmpty
          ? null
          : _translatedTitleController.text.trim(),
      author: _authorController.text.trim(),
      sourceLanguage: _selectedLanguage,
      coverImage: widget.series.coverImage,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      translationContext: widget.series.translationContext,
      glossary: widget.series.glossary,
      status: _selectedStatus,
      created: widget.series.created,
      updated: DateTime.now(),
    );

    final viewModel = context.read<SeriesViewModel>();
    final success = await viewModel.updateSeries(updatedSeries);

    if (success && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Series updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Failed to update series'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
