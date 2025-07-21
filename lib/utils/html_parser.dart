import 'dart:convert';

class HtmlParser {
  /// Remove HTML tags from text and decode HTML entities
  static String stripHtml(String htmlText) {
    if (htmlText.isEmpty) return htmlText;
    
    // Remove HTML tags using regex
    String cleanText = htmlText.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Decode common HTML entities
    cleanText = cleanText
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    
    // Trim whitespace
    return cleanText.trim();
  }
} 