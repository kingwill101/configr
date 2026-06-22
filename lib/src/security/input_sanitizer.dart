import 'dart:convert';

/// Input sanitization options
class SanitizationOptions {
  final bool removeHtml;
  final bool removeScripts;
  final bool normalizeWhitespace;
  final bool removeControlCharacters;
  final bool escapeSpecialCharacters;
  final int? maxLength;
  final List<String>? allowedTags;
  final List<String>? allowedAttributes;

  const SanitizationOptions({
    this.removeHtml = true,
    this.removeScripts = true,
    this.normalizeWhitespace = true,
    this.removeControlCharacters = true,
    this.escapeSpecialCharacters = true,
    this.maxLength,
    this.allowedTags,
    this.allowedAttributes,
  });
}

/// Input sanitizer for cleaning and validating user input
class InputSanitizer {
  static final InputSanitizer _instance = InputSanitizer._internal();

  factory InputSanitizer() => _instance;

  InputSanitizer._internal();

  /// Default sanitization options
  static const SanitizationOptions defaultOptions = SanitizationOptions();

  /// Sanitize string input
  String sanitizeString(String input, {SanitizationOptions? options}) {
    final opts = options ?? defaultOptions;
    String result = input;

    // Remove control characters
    if (opts.removeControlCharacters) {
      result = _removeControlCharacters(result);
    }

    // Remove HTML tags
    if (opts.removeHtml) {
      result = _removeHtmlTags(result, opts.allowedTags);
    }

    // Remove scripts
    if (opts.removeScripts) {
      result = _removeScripts(result);
    }

    // Normalize whitespace
    if (opts.normalizeWhitespace) {
      result = _normalizeWhitespace(result);
    }

    // Escape special characters
    if (opts.escapeSpecialCharacters) {
      result = _escapeSpecialCharacters(result);
    }

    // Truncate if too long
    if (opts.maxLength != null && result.length > opts.maxLength!) {
      result = result.substring(0, opts.maxLength!);
    }

    return result;
  }

  /// Sanitize map input
  Map<String, dynamic> sanitizeMap(
    Map<String, dynamic> input, {
    SanitizationOptions? options,
  }) {
    final result = <String, dynamic>{};

    for (final entry in input.entries) {
      final sanitizedKey = sanitizeString(entry.key, options: options);
      final sanitizedValue = sanitizeValue(entry.value, options: options);
      result[sanitizedKey] = sanitizedValue;
    }

    return result;
  }

  /// Sanitize list input
  List<dynamic> sanitizeList(
    List<dynamic> input, {
    SanitizationOptions? options,
  }) {
    return input.map((item) => sanitizeValue(item, options: options)).toList();
  }

  /// Sanitize any value
  dynamic sanitizeValue(dynamic input, {SanitizationOptions? options}) {
    if (input is String) {
      return sanitizeString(input, options: options);
    } else if (input is Map<String, dynamic>) {
      return sanitizeMap(input, options: options);
    } else if (input is List) {
      return sanitizeList(input, options: options);
    } else if (input is num || input is bool || input == null) {
      return input; // Primitive types don't need sanitization
    } else {
      // Convert to string and sanitize
      return sanitizeString(input.toString(), options: options);
    }
  }

  /// Validate email address
  bool isValidEmail(String email) {
    final pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    return RegExp(pattern).hasMatch(email);
  }

  /// Validate URL
  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Validate file path
  bool isValidFilePath(String path) {
    // Check for path traversal attempts
    if (path.contains('..') || path.contains('~')) {
      return false;
    }

    // Check for null bytes
    if (path.contains('\x00')) {
      return false;
    }

    return true;
  }

  /// Validate JSON string
  bool isValidJson(String json) {
    try {
      jsonDecode(json);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove control characters
  String _removeControlCharacters(String input) {
    return input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// Remove HTML tags
  String _removeHtmlTags(String input, List<String>? allowedTags) {
    if (allowedTags != null && allowedTags.isNotEmpty) {
      // Remove all tags except allowed ones
      final allowedPattern = allowedTags.join('|');
      final regex = RegExp(
        r'</?(?!(?:' + allowedPattern + r')\b)[^>]*>',
        caseSensitive: false,
      );
      return input.replaceAll(regex, '');
    } else {
      // Remove all HTML tags
      return input.replaceAll(RegExp(r'<[^>]*>'), '');
    }
  }

  /// Remove script tags and JavaScript
  String _removeScripts(String input) {
    // Remove script tags
    String result = input.replaceAll(
      RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true),
      '',
    );

    // Remove JavaScript URLs
    result = result.replaceAll(
      RegExp(r'javascript:', caseSensitive: false),
      '',
    );

    // Remove VBScript URLs
    result = result.replaceAll(RegExp(r'vbscript:', caseSensitive: false), '');

    // Remove data URLs
    result = result.replaceAll(
      RegExp(r'data:text/html', caseSensitive: false),
      '',
    );

    // Remove event handlers
    result = result.replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');

    return result;
  }

  /// Normalize whitespace
  String _normalizeWhitespace(String input) {
    return input
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        ) // Replace multiple whitespace with single space
        .trim(); // Remove leading/trailing whitespace
  }

  /// Escape special characters
  String _escapeSpecialCharacters(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  /// Sanitize file name
  String sanitizeFileName(String fileName) {
    // Remove or replace dangerous characters
    String result = fileName
        .replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        ) // Replace invalid filename characters
        .replaceAll(RegExp(r'\.\.'), '_') // Replace path traversal
        .replaceAll(RegExp(r'^\.'), '_') // Replace leading dots
        .replaceAll(RegExp(r'\s+$'), '') // Remove trailing spaces
        .replaceAll(RegExp(r'^\s+'), ''); // Remove leading spaces

    // Limit length
    if (result.length > 255) {
      final extension = _getFileExtension(result);
      final nameWithoutExt = result.substring(
        0,
        result.length - extension.length,
      );
      result = nameWithoutExt.substring(0, 255 - extension.length) + extension;
    }

    return result;
  }

  /// Get file extension
  String _getFileExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return '';
    return fileName.substring(lastDot);
  }

  /// Sanitize command line arguments
  List<String> sanitizeCommandArgs(List<String> args) {
    return args.map((arg) {
      // Remove or escape dangerous characters
      String sanitized = arg
          .replaceAll(RegExp(r'[;&|`$]'), '') // Remove command separators
          .replaceAll(RegExp(r'[<>]'), '') // Remove redirection operators
          .replaceAll(
            RegExp(r'[\x00-\x1F\x7F]'),
            '',
          ); // Remove control characters

      // Limit length
      if (sanitized.length > 1000) {
        sanitized = sanitized.substring(0, 1000);
      }

      return sanitized;
    }).toList();
  }

  /// Sanitize SQL query (basic protection)
  String sanitizeSql(String query) {
    // Remove or escape dangerous SQL patterns
    String result = query
        .replaceAll(RegExp(r'--.*$', multiLine: true), '') // Remove comments
        .replaceAll(
          RegExp(r'/\*.*?\*/', dotAll: true),
          '',
        ) // Remove block comments
        .replaceAll(
          RegExp(r';\s*drop\s+', caseSensitive: false),
          '',
        ) // Remove DROP statements
        .replaceAll(
          RegExp(r';\s*delete\s+', caseSensitive: false),
          '',
        ) // Remove DELETE statements
        .replaceAll(
          RegExp(r';\s*update\s+', caseSensitive: false),
          '',
        ) // Remove UPDATE statements
        .replaceAll(
          RegExp(r';\s*insert\s+', caseSensitive: false),
          '',
        ) // Remove INSERT statements
        .replaceAll(
          RegExp(r';\s*create\s+', caseSensitive: false),
          '',
        ) // Remove CREATE statements
        .replaceAll(
          RegExp(r';\s*alter\s+', caseSensitive: false),
          '',
        ) // Remove ALTER statements
        .replaceAll(
          RegExp(r';\s*exec\s+', caseSensitive: false),
          '',
        ) // Remove EXEC statements
        .replaceAll(
          RegExp(r';\s*execute\s+', caseSensitive: false),
          '',
        ); // Remove EXECUTE statements

    return result;
  }

  /// Check if input contains only safe characters
  bool isSafeInput(String input) {
    // Check for dangerous patterns
    final dangerousPatterns = [
      r'<script[^>]*>', // Script tags
      r'javascript:', // JavaScript URLs
      r'vbscript:', // VBScript URLs
      r'data:text/html', // Data URLs
      r'on\w+\s*=', // Event handlers
      r'\.\./', // Path traversal
      r'\.\.\\', // Path traversal (Windows)
      r'%2e%2e%2f', // URL encoded path traversal
      r'%2e%2e%5c', // URL encoded path traversal (Windows)
      r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', // Control characters
    ];

    for (final pattern in dangerousPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
        return false;
      }
    }

    return true;
  }
}
