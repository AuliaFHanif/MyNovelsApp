import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chapter.dart';
import '../../viewmodels/translation_viewmodel.dart';

class TranslationProgressDialog extends StatefulWidget {
  final Chapter chapter;
  final String sourceLanguage;
  final String? seriesContext;
  final Map<String, String>? glossary;

  const TranslationProgressDialog({
    super.key,
    required this.chapter,
    required this.sourceLanguage,
    this.seriesContext,
    this.glossary,
  });

  @override
  State<TranslationProgressDialog> createState() =>
      _TranslationProgressDialogState();
}

class _TranslationProgressDialogState extends State<TranslationProgressDialog> {
  bool _isStarted = false;
  bool _isComplete = false;
  bool _hasFailed = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _startTranslation();
  }

  Future<void> _startTranslation() async {
    setState(() => _isStarted = true);

    final viewModel = context.read<TranslationViewModel>();
    final success = await viewModel.translateChapter(
      widget.chapter,
      widget.sourceLanguage,
      context: widget.seriesContext,
      glossary: widget.glossary,
    );

    // Check if cancelled during translation
    if (_isCancelled) return;

    setState(() {
      _isComplete = true;
      _hasFailed = !success;
    });

    // Auto-close after 2 seconds if successful
    if (success) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && !_isCancelled) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    }
  }

  void _cancelTranslation() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Cancel Translation?'),
          ],
        ),
        content: const Text(
          'The translation is in progress. Cancelling will:\n\n'
          '• Stop the current translation\n'
          '• Discard any progress\n'
          '• Set chapter status back to pending\n\n'
          'Are you sure you want to cancel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Translation'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Translation'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      setState(() => _isCancelled = true);

      // Cancel the translation in the view model
      final viewModel = context.read<TranslationViewModel>();
      viewModel.cancelTranslation();

      if (mounted) {
        Navigator.pop(context, false); // Return false to indicate cancelled
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isComplete || _isCancelled,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              _isCancelled
                  ? Icons.cancel
                  : _hasFailed
                  ? Icons.error
                  : _isComplete
                  ? Icons.check_circle
                  : Icons.translate,
              color: _isCancelled
                  ? Colors.orange
                  : _hasFailed
                  ? Colors.red
                  : _isComplete
                  ? Colors.green
                  : Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isCancelled
                    ? 'Translation Cancelled'
                    : _hasFailed
                    ? 'Translation Failed'
                    : _isComplete
                    ? 'Translation Complete!'
                    : 'Translating Chapter ${widget.chapter.chapterNumber}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Consumer<TranslationViewModel>(
          builder: (context, viewModel, child) {
            if (_isCancelled) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange[700]),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Translation was cancelled. Chapter status has been reset to pending.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            if (_hasFailed) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Translation failed. Please check:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildCheckItem('LM Studio is running'),
                  _buildCheckItem('Model is loaded'),
                  _buildCheckItem('API server is started'),
                  const SizedBox(height: 12),
                  if (viewModel.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        viewModel.errorMessage!,
                        style: TextStyle(fontSize: 12, color: Colors.red[900]),
                      ),
                    ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bar
                LinearProgressIndicator(
                  value: viewModel.progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isComplete ? Colors.green : Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),

                // Status message
                Row(
                  children: [
                    if (!_isComplete)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (_isComplete)
                      const Icon(Icons.check, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        viewModel.statusMessage,
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Progress percentage
                Text(
                  '${(viewModel.progress * 100).toStringAsFixed(0)}% complete',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),

                if (_isComplete) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Translation saved successfully!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          // Cancel button - only show while translating
          if (!_isComplete && !_hasFailed && !_isCancelled)
            TextButton.icon(
              onPressed: _cancelTranslation,
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          // Close button - show when done/failed/cancelled
          if (_isComplete || _hasFailed || _isCancelled)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _isComplete && !_isCancelled),
              child: Text(_hasFailed || _isCancelled ? 'Close' : 'Done'),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
