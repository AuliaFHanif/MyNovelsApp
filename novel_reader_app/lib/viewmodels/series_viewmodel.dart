import 'package:flutter/foundation.dart';
import '../models/series.dart';
import '../services/pocketbase_service.dart';

class SeriesViewModel extends ChangeNotifier {
  final PocketBaseService _pb = PocketBaseService();

  List<Series> _seriesList = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Series> get seriesList => _seriesList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch all series
  Future<void> fetchSeries() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final records = await _pb.pb
          .collection('series')
          .getFullList(sort: '-created');

      _seriesList = records
          .map((record) => Series.fromJson(record.toJson()))
          .toList();
    } catch (e) {
      _errorMessage = 'Failed to load series: $e';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new series
  Future<bool> addSeries(Series series) async {
    try {
      await _pb.pb.collection('series').create(body: series.toJson());
      await fetchSeries(); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add series: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Update existing series
  Future<bool> updateSeries(Series series) async {
    try {
      await _pb.pb
          .collection('series')
          .update(series.id, body: series.toJson());
      await fetchSeries(); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update series: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Delete series (with cascade delete for chapters and translations)
  Future<bool> deleteSeries(String id) async {
    try {
      // First, get all chapters for this series
      final chapters = await _pb.pb
          .collection('chapters')
          .getFullList(filter: 'series_id = "$id"');

      // For each chapter, delete its translations first, then the chapter
      for (final chapter in chapters) {
        final chapterId = chapter.id;

        // Delete translations for this chapter
        try {
          final translations = await _pb.pb
              .collection('translations')
              .getFullList(filter: 'chapter_id = "$chapterId"');

          for (final translation in translations) {
            await _pb.pb.collection('translations').delete(translation.id);
          }
        } catch (e) {
          // Continue even if translations fail
        }

        // Delete the chapter
        try {
          await _pb.pb.collection('chapters').delete(chapterId);
        } catch (e) {
          throw Exception('Failed to delete chapter: $e');
        }
      }

      // Finally, delete the series
      await _pb.pb.collection('series').delete(id);

      await fetchSeries(); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete series: $e';
      notifyListeners();
      return false;
    }
  }
}
