import 'package:flutter/foundation.dart';
import '../models/chapter.dart';
import '../models/translation.dart';
import '../services/pocketbase_service.dart';
import '../services/translation_service.dart';

class TranslationViewModel extends ChangeNotifier {
  final PocketBaseService _pb = PocketBaseService();
  final TranslationService _translationService = TranslationService();

  bool _isCancelled = false;
  bool _isTranslating = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String? _errorMessage;

  bool get isTranslating => _isTranslating;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;

  /// Test LM Studio connection
  Future<bool> testLMStudioConnection() async {
    return await _translationService.testConnection();
  }

  /// Update an existing translation
  Future<bool> updateTranslation(Translation translation) async {
    try {
      await _pb.pb
          .collection('translations')
          .update(translation.id, body: translation.toJson());
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update translation: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Translate a chapter
  Future<bool> translateChapter(
    Chapter chapter,
    String sourceLanguage, {
    String? context,
    Map<String, String>? glossary,
  }) async {
    _isTranslating = true;
    _progress = 0.0;
    _statusMessage = 'Initializing translation...';
    _errorMessage = null;
    _isCancelled = false; // Reset cancellation flag
    notifyListeners();

    try {
      // Update chapter status to processing
      await _updateChapterStatus(chapter.id, chapter.seriesId, 'processing');

      final startTime = DateTime.now();

      // Perform translation with cancellation support
      final translatedText = await _translationService.translateText(
        chapter.sourceText,
        sourceLanguage: sourceLanguage,
        targetLanguage: 'English',
        context: context,
        glossary: glossary,
        onProgress: (progress, message) {
          // Check if cancelled
          if (_isCancelled) {
            throw Exception('Translation cancelled by user');
          }

          _progress = progress;
          _statusMessage = message;
          notifyListeners();
        },
      );

      // Check if cancelled before saving
      if (_isCancelled) {
        await _updateChapterStatus(chapter.id, chapter.seriesId, 'pending');
        return false;
      }

      if (translatedText == null) {
        throw Exception('Translation returned null');
      }

      final endTime = DateTime.now();
      final translationTime = endTime.difference(startTime).inSeconds;

      // Save translation to database
      final translation = Translation(
        id: '',
        chapterId: chapter.id,
        translatedText: translatedText,
        modelUsed: 'huihui-qwen3-vl-8b-instruct-abliterated',
        translationTime: translationTime,
        chunkCount: _translationService.chunkText(chapter.sourceText).length,
        created: DateTime.now(),
        updated: DateTime.now(),
      );

      await _pb.pb
          .collection('translations')
          .create(body: translation.toJson());

      // Update chapter status to completed
      await _updateChapterStatus(chapter.id, chapter.seriesId, 'completed');

      _statusMessage = 'Translation saved successfully!';
      notifyListeners();

      return true;
    } catch (e) {
      if (_isCancelled) {
        _errorMessage = 'Translation cancelled';
        await _updateChapterStatus(chapter.id, chapter.seriesId, 'pending');
      } else {
        _errorMessage = 'Translation failed: $e';
        await _updateChapterStatus(chapter.id, chapter.seriesId, 'failed');
      }

      print(_errorMessage);
      notifyListeners();
      return false;
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  /// Update chapter translation status
  Future<void> _updateChapterStatus(
    String chapterId,
    String seriesId,
    String status,
  ) async {
    try {
      await _pb.pb
          .collection('chapters')
          .update(chapterId, body: {'translation_status': status});
    } catch (e) {
      print('Failed to update chapter status: $e');
    }
  }

  /// Get translation for a chapter
  Future<Translation?> getTranslation(String chapterId) async {
    try {
      final records = await _pb.pb
          .collection('translations')
          .getFullList(filter: 'chapter_id = "$chapterId"');

      if (records.isEmpty) return null;

      return Translation.fromJson(records.first.toJson());
    } catch (e) {
      print('Failed to get translation: $e');
      return null;
    }
  }

  /// Cancel ongoing translation
  void cancelTranslation() {
    _isCancelled = true;
    _statusMessage = 'Cancelling translation...';
    notifyListeners();
  }
}
