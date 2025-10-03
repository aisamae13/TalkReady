class TextProcessing {
  static String processText(String text) {
    String processedText = cleanText(text.trim());

    if (processedText.isNotEmpty &&
        !processedText.endsWith('.') &&
        !processedText.endsWith('?') &&
        !processedText.endsWith('!')) {
      List<String> questionStarters = [
        'how', 'what', 'where', 'when', 'why', 'who', 'which',
        'are', 'is', 'can', 'do', 'does', 'did', 'will', 'would', 'should', 'could',
        'am', 'have', 'has', 'was', 'were',
      ];

      bool isQuestion = questionStarters.any((starter) =>
          processedText.toLowerCase().startsWith('$starter ')) ||
          processedText.toLowerCase().contains(' or ');

      processedText += isQuestion ? '?' : '.';
    }

    return processedText;
  }

  static String cleanText(String text) {
    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€ ', '"')
        .replaceAll('â€"', '–')
        .replaceAll('â€"', '—')
        .replaceAll('*', '')
        .trim();
  }

  static String cleanTextForTTS(String text) {
    // Remove emojis using a more straightforward approach
    String cleaned = text;

    // Remove common emoji ranges
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true),
      (match) => '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true),
      (match) => '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'[\u{2600}-\u{26FF}]', unicode: true),
      (match) => '',
    );

    // Clean up other characters
    cleaned = cleaned
        .replaceAll(RegExp(r'[\n\r]+'), ' ')
        .replaceAll('"', '"')
        .replaceAll('"', '"')
        .replaceAll("'", "'")
        .replaceAll("'", "'")
        .replaceAll(RegExp(r"[^a-zA-Z0-9 .,?!'""\$%-]+"), ' ')
        .trim();

    return cleaned;
  }
}