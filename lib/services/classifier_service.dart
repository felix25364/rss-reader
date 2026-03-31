import 'package:flutter/foundation.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

/// Service to classify RSS articles into categories using local NLP heuristics.
class ClassifierService {
  /// Instance of EntityExtractor (must specify language).
  late EntityExtractor _entityExtractor;
  bool _isInitialized = false;

  /// Map of keywords to categories.
  static const Map<String, String> _keywordCategories = {
    'kernel': 'Linux',
    'distro': 'Linux',
    'ubuntu': 'Linux',
    'flutter': 'Development',
    'dart': 'Development',
    'android': 'Mobile',
    'ios': 'Mobile',
    'apple': 'Tech',
    'google': 'Tech',
    'pixel': 'Mobile',
    // More heuristics can be added here
  };

  /// Initializes the EntityExtractor with the chosen [EntityExtractorLanguage].
  Future<void> initialize(EntityExtractorLanguage language) async {
    final modelManager = EntityExtractorModelManager();
    final isModelDownloaded = await modelManager.isModelDownloaded(language.name);

    if (!isModelDownloaded) {
      await modelManager.downloadModel(language.name);
    }

    _entityExtractor = EntityExtractor(language: language);
    _isInitialized = true;
  }

  /// Classifies text into a category using both heuristic keywords and ML Kit entities.
  /// Runs inside a separate isolate using `compute`.
  Future<String> classifyText(String title, String description) async {
    if (!_isInitialized) {
      // Fallback to simple keyword heuristics if not initialized
      return await compute(_heuristicsOnlyClassification, {'title': title, 'description': description});
    }

    // Prepare text for the model
    final textToAnalyze = '$title. $description';

    // We cannot pass _entityExtractor directly to an isolate easily, so we extract entities here.
    // Entity extraction runs on native background threads anyway (handled by ML Kit).
    // Note: The ML Kit calls are asynchronous and bridge to native, making `compute` tricky
    // with ML Kit objects. We use compute for the heuristic part, and async for the ML part.

    // 1. Run ML Kit Extraction (Native background thread)
    final entities = await _entityExtractor.annotateText(textToAnalyze);

    // 2. Run Heuristics (Dart background isolate)
    final category = await compute(_analyzeHeuristicsAndEntities, {
      'text': textToAnalyze,
      'ml_entities': entities.map((e) => e.text).toList(),
    });

    return category;
  }

  /// Top-level function for simple heuristics via Isolate.
  static String _heuristicsOnlyClassification(Map<String, String> data) {
    final text = '${data['title']} ${data['description']}'.toLowerCase();

    for (final entry in _keywordCategories.entries) {
      if (text.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return 'General';
  }

  /// Top-level function to combine ML entities and text heuristics via Isolate.
  static String _analyzeHeuristicsAndEntities(Map<String, dynamic> data) {
    final text = (data['text'] as String).toLowerCase();
    final List<String> mlEntities = data['ml_entities'] as List<String>;

    // Check custom heuristics first
    for (final entry in _keywordCategories.entries) {
      if (text.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
      for (final entity in mlEntities) {
        if (entity.toLowerCase().contains(entry.key.toLowerCase())) {
          return entry.value;
        }
      }
    }

    // Default if no specific category matched
    return 'General';
  }

  /// Disposes the extractor to free up resources.
  Future<void> dispose() async {
    if (_isInitialized) {
      await _entityExtractor.close();
      _isInitialized = false;
    }
  }
}
