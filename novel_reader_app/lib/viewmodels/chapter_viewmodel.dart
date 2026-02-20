import 'package:flutter/foundation.dart';
import '../models/chapter.dart';
import '../services/pocketbase_service.dart';

class ChapterViewModel extends ChangeNotifier {
  final PocketBaseService _pb = PocketBaseService();

  List<Chapter> _chaptersList = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Chapter> get chaptersList => _chaptersList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  PocketBaseService get pb => _pb;

  // Fetch chapters for a specific series
  Future<void> fetchChapters(String seriesId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final records = await _pb.pb
          .collection('chapters')
          .getFullList(
            filter: 'series_id = "$seriesId"',
            sort: 'chapter_number',
          );

      _chaptersList = records
          .map((record) => Chapter.fromJson(record.toJson()))
          .toList();
    } catch (e) {
      _errorMessage = 'Failed to load chapters: $e';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new chapter
  Future<bool> addChapter(Chapter chapter) async {
    try {
      await _pb.pb.collection('chapters').create(body: chapter.toJson());
      await fetchChapters(chapter.seriesId); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add chapter: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Delete chapter
  Future<bool> deleteChapter(String id, String seriesId) async {
    try {
      await _pb.pb.collection('chapters').delete(id);
      await fetchChapters(seriesId); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete chapter: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Get a single chapter by ID
  Future<Chapter?> getChapter(String chapterId) async {
    try {
      final record = await _pb.pb.collection('chapters').getOne(chapterId);
      return Chapter.fromJson(record.toJson());
    } catch (e) {
      _errorMessage = 'Failed to get chapter: $e';
      print(_errorMessage);
      notifyListeners();
      return null;
    }
  }

  // Update existing chapter
  Future<bool> updateChapter(Chapter chapter) async {
    try {
      await _pb.pb
          .collection('chapters')
          .update(chapter.id, body: chapter.toJson());
      await fetchChapters(chapter.seriesId); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update chapter: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
  }
}
