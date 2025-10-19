// lib/services/answer_matcher.dart (or wherever you keep utility files)

class AnswerMatcher {
  /// Normalize text for comparison
  static String normalizeText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .replaceAll(RegExp(r'[.,!?;:]'), '') // Remove common punctuation
        .replaceAll(RegExp(r"['']"), "'") // Normalize quotes/apostrophes
        .replaceAll(RegExp(r'["""]'), '"'); // Normalize double quotes
  }

  /// Check if student answer matches any correct answer
  static bool isAnswerCorrect(
    String studentAnswer,
    List<String> correctAnswers, {
    bool strictMode = false,
  }) {
    if (studentAnswer.trim().isEmpty) return false;

    final normalizedStudent = normalizeText(studentAnswer);

    for (var correctAnswer in correctAnswers) {
      final normalizedCorrect = normalizeText(correctAnswer);

      if (strictMode) {
        // Strict mode: exact match after normalization
        if (normalizedStudent == normalizedCorrect) {
          return true;
        }
      } else {
        // Flexible mode: handle common variations

        // Exact match
        if (normalizedStudent == normalizedCorrect) {
          return true;
        }

        // Check if answer contains the correct answer (for longer responses)
        if (normalizedStudent.contains(normalizedCorrect) ||
            normalizedCorrect.contains(normalizedStudent)) {
          // Only accept if length difference is not too large
          final lengthDiff = (normalizedStudent.length - normalizedCorrect.length).abs();
          if (lengthDiff <= 3) {
            return true;
          }
        }

        // Handle number formatting
        final studentNumbers = normalizedStudent.replaceAll(RegExp(r'[,\s]'), '');
        final correctNumbers = normalizedCorrect.replaceAll(RegExp(r'[,\s]'), '');
        if (_isNumeric(studentNumbers) && _isNumeric(correctNumbers)) {
          if (studentNumbers == correctNumbers) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Calculate similarity percentage between two strings (Levenshtein distance)
  static double calculateSimilarity(String s1, String s2) {
    final normalized1 = normalizeText(s1);
    final normalized2 = normalizeText(s2);

    if (normalized1 == normalized2) return 100.0;
    if (normalized1.isEmpty || normalized2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(normalized1, normalized2);
    final maxLength = normalized1.length > normalized2.length
        ? normalized1.length
        : normalized2.length;

    final similarity = ((maxLength - distance) / maxLength) * 100;
    return similarity;
  }

  /// Levenshtein distance algorithm
  static int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    final matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );

    for (var i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= len1; i++) {
      for (var j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  /// Check if string is numeric
  static bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  /// Get helpful feedback for student
  static String getFeedback(
    String studentAnswer,
    List<String> correctAnswers,
  ) {
    if (isAnswerCorrect(studentAnswer, correctAnswers)) {
      return 'Correct!';
    }

    // Find closest match
    double highestSimilarity = 0;
    String closestAnswer = '';

    for (var correctAnswer in correctAnswers) {
      final similarity = calculateSimilarity(studentAnswer, correctAnswer);
      if (similarity > highestSimilarity) {
        highestSimilarity = similarity;
        closestAnswer = correctAnswer;
      }
    }

    if (highestSimilarity >= 80) {
      return 'Very close! Check your spelling.';
    } else if (highestSimilarity >= 60) {
      return 'You\'re on the right track, but not quite.';
    } else if (highestSimilarity >= 40) {
      return 'Partially correct. Review the question.';
    } else {
      return 'Incorrect. The correct answer is: $closestAnswer';
    }
  }

  /// Get the best matching correct answer for display
  static String getBestMatch(
    String studentAnswer,
    List<String> correctAnswers,
  ) {
    if (correctAnswers.isEmpty) return '';
    if (correctAnswers.length == 1) return correctAnswers[0];

    double highestSimilarity = 0;
    String closestAnswer = correctAnswers[0];

    for (var correctAnswer in correctAnswers) {
      final similarity = calculateSimilarity(studentAnswer, correctAnswer);
      if (similarity > highestSimilarity) {
        highestSimilarity = similarity;
        closestAnswer = correctAnswer;
      }
    }

    return closestAnswer;
  }
}