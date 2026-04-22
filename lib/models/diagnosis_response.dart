class DiagnosisResponse {
  final String predictedDisease;
  final double confidence;
  final String severity;
  final String advice;
  final String duration;
  final bool contagious;
  final List<String> complications;
  final List<String> diagnosticTests;
  final List<String> treatment;
  final List<String> prevention;
  final String icdCode;
  final List<String> recommendedDoctors;
  final String? emergencyAlert;
  final List<TopPrediction> top3Predictions;
  final String language;
  final String? suggestedSpecialist;
  final double? specialistConfidence;
  final String? specialistMatchMethod;
  final Map<String, dynamic>? extractedSymptoms;
  final String? translatedText;

  // For simplified doctor match response
  final String? symptom;

  DiagnosisResponse({
    required this.predictedDisease,
    required this.confidence,
    required this.severity,
    required this.advice,
    required this.duration,
    required this.contagious,
    required this.complications,
    required this.diagnosticTests,
    required this.treatment,
    required this.prevention,
    required this.icdCode,
    required this.recommendedDoctors,
    this.emergencyAlert,
    required this.top3Predictions,
    required this.language,
    this.suggestedSpecialist,
    this.specialistConfidence,
    this.specialistMatchMethod,
    this.extractedSymptoms,
    this.translatedText,
    this.symptom,
  });

  factory DiagnosisResponse.fromJson(Map<String, dynamic> json) {
    return DiagnosisResponse(
      predictedDisease:
          json['predicted_disease'] ?? json['specialty'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      severity: json['severity'] ?? 'unknown',
      advice: json['advice'] ?? '',
      duration: json['duration'] ?? 'unknown',
      contagious: json['contagious'] ?? false,
      complications: List<String>.from(json['complications'] ?? []),
      diagnosticTests: List<String>.from(json['diagnostic_tests'] ?? []),
      treatment: List<String>.from(json['treatment'] ?? []),
      prevention: List<String>.from(json['prevention'] ?? []),
      icdCode: json['icd_code'] ?? '',
      recommendedDoctors: List<String>.from(json['recommended_doctors'] ?? []),
      emergencyAlert: json['emergency_alert'],
      top3Predictions: (json['top_3_predictions'] as List? ?? [])
          .map((item) => TopPrediction.fromJson(item))
          .toList(),
      language: json['language'] ?? 'english',
      suggestedSpecialist: json['suggested_specialist'],
      specialistConfidence: (json['specialist_confidence'] != null)
          ? json['specialist_confidence'].toDouble()
          : null,
      specialistMatchMethod: json['specialist_match_method'],
      extractedSymptoms: json['extracted_symptoms'],
      translatedText: json['translated_text'],
      symptom: json['symptom'],
    );
  }

  String get displayString {
    final buffer = StringBuffer();

    // For simplified doctor match response (symptom + specialty only)
    if (symptom != null &&
        suggestedSpecialist == null &&
        emergencyAlert == null) {
      buffer.writeln('Symptom: $symptom');
      buffer.writeln('Recommended Specialist: $predictedDisease');
      return buffer.toString().trim();
    }

    buffer.writeln('Likely condition: $predictedDisease');
    buffer.writeln('Severity: $severity');
    buffer.writeln('Typical duration: $duration');
    buffer.writeln('Contagious: ${contagious ? 'Yes' : 'No'}');

    if (emergencyAlert != null) {
      buffer.writeln();
      buffer.writeln('⚠️ $emergencyAlert');
    }

    if (suggestedSpecialist != null) {
      buffer.writeln();
      buffer.writeln('Recommended Specialist: $suggestedSpecialist');
    }

    if (advice.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Advice: $advice');
    }

    if (treatment.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Treatment:');
      for (var t in treatment) {
        buffer.writeln('  • $t');
      }
    }

    if (prevention.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Prevention:');
      for (var p in prevention) {
        buffer.writeln('  • $p');
      }
    }

    if (complications.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Possible Complications:');
      for (var c in complications) {
        buffer.writeln('  • $c');
      }
    }

    if (diagnosticTests.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Diagnostic Tests:');
      for (var test in diagnosticTests) {
        buffer.writeln('  • $test');
      }
    }

    if (top3Predictions.length > 1) {
      buffer.writeln();
      buffer.writeln('Other possible matches:');
      for (var pred in top3Predictions.skip(1)) {
        buffer.writeln('• ${pred.disease}');
      }
    }

    return buffer.toString().trim();
  }
}

class TopPrediction {
  final String disease;
  final double confidence;

  TopPrediction({required this.disease, required this.confidence});

  factory TopPrediction.fromJson(Map<String, dynamic> json) {
    return TopPrediction(
      disease: json['disease'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}
