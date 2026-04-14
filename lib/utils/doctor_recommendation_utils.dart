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
}

