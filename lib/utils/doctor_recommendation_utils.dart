class DoctorRecommendationUtils {
  static String extractLikelyCondition(String text) {
    final match = RegExp(
      r'^\s*Likely condition:\s*(.+?)\s*(?:\(|$)',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  static String inferSearchQuery(String aiText) {
    final condition = extractLikelyCondition(aiText).toLowerCase();
    final haystack = ('$condition $aiText').toLowerCase();

    bool hasAny(Iterable<String> terms) =>
        terms.any((term) => haystack.contains(term));

    if (hasAny(['pregnan', 'menstrual', 'gynec', 'uter', 'ovary'])) {
      return 'Gynecologist';
    }
    if (hasAny(['baby', 'infant', 'child', 'pediatric'])) {
      return 'Pediatrician';
    }
    if (hasAny(['skin', 'rash', 'eczema', 'acne', 'dermat'])) {
      return 'Dermatologist';
    }
    if (hasAny(['eye', 'vision', 'blurred', 'ophthal'])) {
      return 'Ophthalmologist';
    }
    if (hasAny(['tooth', 'gum', 'dental'])) {
      return 'Dentist';
    }
    if (hasAny(['ear', 'throat', 'sinus', 'tonsil', 'ent'])) {
      return 'ENT';
    }
    if (hasAny(['heart', 'chest pain', 'hypertension', 'cardio'])) {
      return 'Cardiologist';
    }
    if (hasAny(['asthma', 'cough', 'shortness of breath', 'tb', 'lung'])) {
      return 'Pulmonologist';
    }
    if (hasAny(['stomach', 'abdominal', 'vomit', 'diarrh', 'ulcer', 'gastr'])) {
      return 'Gastroenterologist';
    }
    if (hasAny(['kidney', 'urine', 'urinary', 'uti', 'renal'])) {
      return 'Urologist';
    }
    if (hasAny(['diabetes', 'thyroid', 'hormone', 'endocr'])) {
      return 'Endocrinologist';
    }
    if (hasAny(['headache', 'migraine', 'seizure', 'stroke', 'neuro'])) {
      return 'Neurologist';
    }
    if (hasAny(['bone', 'joint', 'fracture', 'arthritis', 'orthop'])) {
      return 'Orthopedist';
    }
    if (hasAny(['depress', 'anxiety', 'panic', 'mental', 'psych'])) {
      return 'Psychiatrist';
    }
    if (hasAny(['malaria', 'flu', 'fever', 'infection', 'cold'])) {
      return 'General Practitioner';
    }

    return 'General Practitioner';
  }

  static String extractSpecialist(String aiText) {
    final normalized = aiText.trim();
    final labelMatch = RegExp(
      r'(?:specialist|doctor type|doctor|recommend(?:ed) specialist)\s*[:\-]\s*(.+)',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (labelMatch != null && labelMatch.groupCount >= 1) {
      return _normalizeSpecialty(labelMatch.group(1)!);
    }

    final lines = normalized
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) {
      final firstLine = lines.first;
      if (!firstLine.toLowerCase().contains('urgency')) {
        return _normalizeSpecialty(firstLine);
      }
    }

    return inferSearchQuery(aiText);
  }

  static String extractUrgency(String aiText) {
    final normalized = aiText.trim();
    final labelMatch = RegExp(
      r'urgency\s*[:\-]\s*(.+)',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (labelMatch != null && labelMatch.groupCount >= 1) {
      return _normalizeUrgency(labelMatch.group(1)!);
    }

    final lower = normalized.toLowerCase();
    if ([
      'emergency',
      'critical',
      'life-threatening',
      'urgent',
      'immediately',
      'severe',
      'sudden',
      'acute',
    ].any(lower.contains)) {
      return 'High';
    }
    if ([
      'moderate',
      'soon',
      'within days',
      'careful',
      'watch',
      'should see',
    ].any(lower.contains)) {
      return 'Medium';
    }
    return 'Low';
  }

  static String _normalizeSpecialty(String value) {
    return value.split(RegExp(r'[\r\n]')).first.trim();
  }

  static String _normalizeUrgency(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.contains('high') ||
        lower.contains('urgent') ||
        lower.contains('emergency') ||
        lower.contains('critical')) {
      return 'High';
    }
    if (lower.contains('medium') ||
        lower.contains('moderate') ||
        lower.contains('soon')) {
      return 'Medium';
    }
    return 'Low';
  }
}
