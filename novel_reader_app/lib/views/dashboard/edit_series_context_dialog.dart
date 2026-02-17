import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/series.dart';
import '../../viewmodels/series_viewmodel.dart';

class EditSeriesContextDialog extends StatefulWidget {
  final Series series;

  const EditSeriesContextDialog({super.key, required this.series});

  @override
  State<EditSeriesContextDialog> createState() =>
      _EditSeriesContextDialogState();
}

class _EditSeriesContextDialogState extends State<EditSeriesContextDialog> {
  late final TextEditingController _contextController;
  final List<GlossaryEntry> _glossaryEntries = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contextController = TextEditingController(
      text: widget.series.translationContext ?? '',
    );

    // Load existing glossary
    if (widget.series.glossary != null) {
      widget.series.glossary!.forEach((key, value) {
        _glossaryEntries.add(GlossaryEntry(source: key, translation: value));
      });
    }
  }

  @override
  void dispose() {
    _contextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.settings, size: 28, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Translation Context & Glossary',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.series.title,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            const Divider(height: 32),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Context Section
                    const Text(
                      'Translation Context',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Provide context about this series to help the AI maintain consistency',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contextController,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g., "This is a cultivation novel set in ancient China. The main character is Liu Wei, a young cultivator..."',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 6,
                    ),

                    const SizedBox(height: 32),

                    // Glossary Section
                    Row(
                      children: [
                        const Text(
                          'Glossary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _addGlossaryEntry,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Term'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Define how specific terms should be translated',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),

                    // Glossary Entries
                    if (_glossaryEntries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.book,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No glossary entries yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add terms to ensure consistent translation of names, places, and terminology',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...List.generate(_glossaryEntries.length, (index) {
                        return _buildGlossaryEntryRow(index);
                      }),
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
                  onPressed: _isSaving ? null : _saveContext,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save'),
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
    );
  }

  Widget _buildGlossaryEntryRow(int index) {
    final entry = _glossaryEntries[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: entry.source,
              decoration: const InputDecoration(
                labelText: 'Source Term',
                hintText: 'e.g., 刘伟',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => entry.source = value,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: entry.translation,
              decoration: const InputDecoration(
                labelText: 'Translation',
                hintText: 'e.g., Liu Wei',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => entry.translation = value,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeGlossaryEntry(index),
          ),
        ],
      ),
    );
  }

  void _addGlossaryEntry() {
    setState(() {
      _glossaryEntries.add(GlossaryEntry(source: '', translation: ''));
    });
  }

  void _removeGlossaryEntry(int index) {
    setState(() {
      _glossaryEntries.removeAt(index);
    });
  }

  Future<void> _saveContext() async {
    setState(() => _isSaving = true);

    // Build glossary map
    final glossaryMap = <String, String>{};
    for (final entry in _glossaryEntries) {
      if (entry.source.isNotEmpty && entry.translation.isNotEmpty) {
        glossaryMap[entry.source] = entry.translation;
      }
    }

    // Update series
    final updatedSeries = Series(
      id: widget.series.id,
      title: widget.series.title,
      author: widget.series.author,
      sourceLanguage: widget.series.sourceLanguage,
      coverImage: widget.series.coverImage,
      description: widget.series.description,
      translationContext: _contextController.text.isEmpty
          ? null
          : _contextController.text,
      glossary: glossaryMap.isEmpty ? null : glossaryMap,
      status: widget.series.status,
      created: widget.series.created,
      updated: DateTime.now(),
    );

    final viewModel = context.read<SeriesViewModel>();
    final success = await viewModel.updateSeries(updatedSeries);

    if (success && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation context saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Failed to save context'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class GlossaryEntry {
  String source;
  String translation;

  GlossaryEntry({required this.source, required this.translation});
}
