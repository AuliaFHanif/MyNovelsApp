import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  // LM Studio API endpoint
  final String _apiUrl = 'http://localhost:1234/v1/chat/completions';

  // Cancellation flag
  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
  }

  void resetCancellation() {
    _isCancelled = false;
  }

  // For mobile (Phase 6), you'll use:
  // final String _apiUrl = 'http://100.94.48.126:1234/v1/chat/completions';

  // Translation timeout (10 minutes)
  final Duration _timeout = const Duration(minutes: 10);

  /// Test if LM Studio is reachable
  Future<bool> testConnection() async {
    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'local-model',
              'messages': [
                {'role': 'user', 'content': 'Hello'},
              ],
              'max_tokens': 10,
            }),
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('LM Studio connection failed: $e');
      return false;
    }
  }

  /// Translate a single text chunk
  Future<String?> translateChunk(
    String sourceText, {
    String sourceLanguage = 'Chinese',
    String targetLanguage = 'English',
    String? context,
    Map<String, String>? glossary,
    Function(String)? onProgress,
    bool hasOverlap = false,
  }) async {
    try {
      final systemPrompt = _buildSystemPrompt(
        sourceLanguage,
        targetLanguage,
        context: context,
        glossary: glossary,
      );

      if (onProgress != null) {
        onProgress('Translating...');
      }

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'local-model',
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': sourceText},
              ],
              'temperature': 0.3, // Lower for more consistent translation
              'max_tokens': 8000, // Increased for larger chunks
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['choices'][0]['message']['content'];
        return translatedText.trim();
      } else {
        print('Translation failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Translation error: $e');
      return null;
    }
  }

  /// Build the system prompt for translation
  String _buildSystemPrompt(
    String sourceLanguage,
    String targetLanguage, {
    String? context,
    Map<String, String>? glossary,
  }) {
    final buffer = StringBuffer();

    buffer.writeln(
      '''You are a professional literary translator specializing in $sourceLanguage to $targetLanguage translation.

Your task:
1. Translate the provided text while preserving:
   - Narrative tone and style
   - Character voices and personality
   - Cultural context and idioms (adapt when necessary)
   - Paragraph structure and formatting
   - Image markers in the format [Image X] - DO NOT translate these, keep them exactly as-is

2. Guidelines:
   - Provide ONLY the translation, no commentary or explanations
   - Maintain the same paragraph breaks as the original
   - Keep all [Image X] markers unchanged in their exact positions
   - Adapt idioms and cultural references for $targetLanguage readers
   - Keep proper nouns (names, places) in their original form unless they have established translations

3. Quality standards:
   - Natural, fluent $targetLanguage
   - Faithful to the original meaning
   - Appropriate for the novel/story genre''',
    );

    // Add series context
    if (context != null && context.isNotEmpty) {
      buffer.writeln('\n\n4. Series Context:\n$context');
    }

    // Add glossary
    if (glossary != null && glossary.isNotEmpty) {
      buffer.writeln('\n\n5. Glossary - Use these exact translations:');
      glossary.forEach((source, translation) {
        buffer.writeln('   - "$source" → "$translation"');
      });
    }

    buffer.writeln('\n\nTranslate the following text:');

    return buffer.toString();
  }

  /// Estimate token count for text
  /// Rough estimate: 1 token ≈ 4 chars for English
  /// For Chinese: ~1 token per character
  int estimateTokenCount(String text) {
    // Check if text contains Chinese characters
    final chinesePattern = RegExp(r'[\u4e00-\u9fa5]');
    final chineseChars = chinesePattern.allMatches(text).length;

    // If mostly Chinese, use 1:1 ratio
    if (chineseChars > text.length * 0.5) {
      return text.length;
    }

    // Otherwise use 4:1 ratio (4 chars = 1 token)
    return (text.length / 4).ceil();
  }

  /// Split text into chunks for translation with overlap
  List<String> chunkText(
    String text, {
    int maxChunkSize = 2000,
    double overlapPercent = 0.10,
    String language = 'Chinese',
  }) {
    final chunks = <String>[];

    // Adjust chunk size based on language
    // Chinese/Japanese: ~1 token per character
    // English: ~1 token per 4 characters
    final adjustedMaxSize = language == 'Chinese' || language == 'Japanese'
        ? (maxChunkSize * 0.7)
              .round() // Reduce for CJK languages
        : maxChunkSize;

    print(
      'Chunking text: ${text.length} chars, max chunk: $adjustedMaxSize chars, overlap: ${(overlapPercent * 100).toInt()}%',
    );

    // Split by paragraphs first
    final paragraphs = text.split('\n\n');

    String currentChunk = '';
    String overlapBuffer = '';

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];

      // Check if adding this paragraph would exceed limit
      if (currentChunk.isNotEmpty &&
          (currentChunk.length + paragraph.length) > adjustedMaxSize) {
        // Save current chunk
        chunks.add(currentChunk.trim());

        // Calculate overlap from end of current chunk
        final overlapSize = (currentChunk.length * overlapPercent).round();
        overlapBuffer = _extractOverlap(currentChunk, overlapSize, language);

        // Start new chunk with overlap
        currentChunk = overlapBuffer;

        print('Created chunk ${chunks.length}: ${chunks.last.length} chars');
      }

      // Handle oversized single paragraph
      if (paragraph.length > adjustedMaxSize) {
        final sentenceChunks = _chunkLargeParagraph(
          paragraph,
          adjustedMaxSize,
          overlapPercent,
          language,
        );

        for (final sentenceChunk in sentenceChunks) {
          if (currentChunk.isNotEmpty &&
              (currentChunk.length + sentenceChunk.length) > adjustedMaxSize) {
            chunks.add(currentChunk.trim());

            final overlapSize = (currentChunk.length * overlapPercent).round();
            overlapBuffer = _extractOverlap(
              currentChunk,
              overlapSize,
              language,
            );
            currentChunk = overlapBuffer;

            print(
              'Created chunk ${chunks.length}: ${chunks.last.length} chars',
            );
          }
          currentChunk += '$sentenceChunk\n\n';
        }
      } else {
        currentChunk += '$paragraph\n\n';
      }
    }

    // Add remaining chunk
    if (currentChunk.trim().isNotEmpty) {
      chunks.add(currentChunk.trim());
      print('Created chunk ${chunks.length}: ${chunks.last.length} chars');
    }

    print('Total chunks created: ${chunks.length}');
    return chunks;
  }

  /// Extract overlap text from the end of a chunk
  String _extractOverlap(String text, int overlapSize, String language) {
    if (text.length <= overlapSize) {
      return text;
    }

    // Try to get overlap at a sentence boundary
    final overlapText = text.substring(text.length - overlapSize);

    // Find the first sentence ending in the overlap
    final sentencePattern = language == 'Chinese' || language == 'Japanese'
        ? RegExp(r'[。！？]')
        : RegExp(r'[.!?]');

    final match = sentencePattern.firstMatch(overlapText);
    if (match != null) {
      // Start overlap from after the first sentence ending
      return overlapText.substring(match.end).trim();
    }

    return overlapText;
  }

  /// Chunk a large paragraph into sentences
  List<String> _chunkLargeParagraph(
    String paragraph,
    int maxSize,
    double overlapPercent,
    String language,
  ) {
    final chunks = <String>[];
    final sentences = _splitIntoSentences(paragraph, language);

    String currentChunk = '';

    for (final sentence in sentences) {
      if (currentChunk.isNotEmpty &&
          (currentChunk.length + sentence.length) > maxSize) {
        chunks.add(currentChunk.trim());

        // Add overlap
        final overlapSize = (currentChunk.length * overlapPercent).round();
        final overlap = _extractOverlap(currentChunk, overlapSize, language);
        currentChunk = '$overlap ';
      }

      currentChunk += '$sentence ';
    }

    if (currentChunk.trim().isNotEmpty) {
      chunks.add(currentChunk.trim());
    }

    return chunks;
  }

  /// Split text into sentences based on language
  List<String> _splitIntoSentences(String text, [String language = 'Chinese']) {
    final sentences = <String>[];

    // Different patterns for different languages
    final pattern = language == 'Chinese' || language == 'Japanese'
        ? RegExp(r'[。！？]+\s*') // CJK sentence endings
        : RegExp(r'[.!?]+\s*'); // Latin sentence endings

    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      final sentence = text.substring(lastEnd, match.end).trim();
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        sentences.add(remaining);
      }
    }

    return sentences;
  }

  /// Translate entire text with chunking and overlap
  Future<String?> translateText(
    String sourceText, {
    String sourceLanguage = 'Chinese',
    String targetLanguage = 'English',
    String? context,
    Map<String, String>? glossary,
    Function(double, String)? onProgress,
  }) async {
    try {
      _isCancelled = false; // Reset cancellation flag

      // Split into chunks with overlap
      final chunks = chunkText(sourceText, language: sourceLanguage);

      print('Split text into ${chunks.length} chunks for translation');

      if (onProgress != null) {
        onProgress(0.0, 'Starting translation (${chunks.length} chunks)...');
      }

      final translatedChunks = <String>[];
      String? previousTranslation;

      // Translate each chunk
      for (int i = 0; i < chunks.length; i++) {
        if (_isCancelled) {
          print('Translation cancelled');
          return null;
        }

        final progress = (i / chunks.length);
        if (onProgress != null) {
          onProgress(
            progress,
            'Translating chunk ${i + 1}/${chunks.length}...',
          );
        }

        final translated = await translateChunk(
          chunks[i],
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          context: context,
          glossary: glossary,
          hasOverlap: i > 0, // First chunk has no overlap
        );

        if (translated == null) {
          print('Failed to translate chunk ${i + 1}');
          return null;
        }

        // Merge with overlap handling
        if (i > 0 && previousTranslation != null) {
          // Remove duplicate content from overlap
          final merged = _mergeOverlappingTranslations(
            previousTranslation,
            translated,
          );
          translatedChunks.add(merged);
        } else {
          translatedChunks.add(translated);
        }

        previousTranslation = translated;
      }

      if (onProgress != null) {
        onProgress(1.0, 'Translation complete!');
      }

      // Combine all chunks
      return translatedChunks.join('\n\n');
    } catch (e) {
      print('Translation failed: $e');
      return null;
    }
  }

  /// Merge overlapping translations by removing duplicate content
  String _mergeOverlappingTranslations(String previous, String current) {
    // Simple approach: look for common sentences at end of previous
    // and beginning of current, then remove duplicates

    final prevSentences = previous.split(RegExp(r'[.!?]+\s*'));
    final currSentences = current.split(RegExp(r'[.!?]+\s*'));

    // Find overlap by comparing last sentences of previous with first of current
    int overlapCount = 0;
    final maxCheck = (prevSentences.length * 0.2).ceil(); // Check last 20%

    for (int i = 1; i <= maxCheck && i <= currSentences.length; i++) {
      final prevEnd = prevSentences.sublist(prevSentences.length - i).join(' ');
      final currStart = currSentences.sublist(0, i).join(' ');

      // Check for similarity (allowing for minor translation variations)
      if (_areSimilar(prevEnd, currStart)) {
        overlapCount = i;
      }
    }

    // Remove overlapping sentences from current
    if (overlapCount > 0) {
      print('Found overlap of $overlapCount sentences, removing duplicates');
      return currSentences.sublist(overlapCount).join('. ').trim();
    }

    return current;
  }

  /// Check if two strings are similar (for overlap detection)
  bool _areSimilar(String a, String b) {
    // Simple similarity check: same length +/- 20% and some common words
    final lengthDiff = (a.length - b.length).abs() / a.length;
    if (lengthDiff > 0.2) return false;

    // Check if they share most words
    final wordsA = a.toLowerCase().split(RegExp(r'\s+'));
    final wordsB = b.toLowerCase().split(RegExp(r'\s+'));

    final commonWords = wordsA.where((word) => wordsB.contains(word)).length;
    final similarity = commonWords / wordsA.length;

    return similarity > 0.6; // 60% word overlap
  }
}
