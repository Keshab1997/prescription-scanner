import 'dart:convert';

import 'package:prescription_scanner/services/gemini_vision_service.dart';

/// Parses a Gemini candidate [candidate] into a JSON object, repairing the
/// common ways Gemini breaks otherwise-valid JSON so a transient glitch
/// doesn't fail the whole scan.
///
/// Repairs: markdown fences, leading/trailing prose, trailing commas, a
/// response cut off mid-object (by closing it), and a top-level array that
/// wraps a single object. Throws [VisionException] with a debug snippet when
/// every attempt fails.
Map<String, dynamic> parsePrescriptionJson(String candidate) {
  final attempts = [candidate, _stripCodeFence(candidate)];
  for (final source in attempts) {
    // 1. Try the whole thing as-is (works when responseMimeType held).
    final direct = _tryDecode(source);
    if (direct != null) return direct;

    // 2. Pull the first balanced {...} out of surrounding prose/fences.
    final object = _extractJsonObject(source);
    if (object != null) {
      final parsed = _tryDecode(object);
      if (parsed != null) return parsed;

      // 3. The object was cut off mid-stream — close it and retry.
      final repaired = _tryDecode(_repairTruncated(object));
      if (repaired != null) return repaired;
    }
  }
  final snippet =
      candidate.length > 200 ? '${candidate.substring(0, 200)}…' : candidate;
  throw VisionException(
    'The AI provider returned invalid JSON. Response: $snippet',
    statusCode: 502,
  );
}

Map<String, dynamic>? _tryDecode(String text) {
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    // Accept a top-level array that wraps a single object (defensive).
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Removes a ```json / ``` fence if present.
String _stripCodeFence(String text) {
  var t = text.trim();
  final fenceStart = RegExp(r'^```(?:json|JSON)?\s*');
  final fenceEnd = RegExp(r'\s*```$');
  if (t.startsWith('```')) {
    t = t.replaceFirst(fenceStart, '');
    if (t.endsWith('```')) t = t.replaceFirst(fenceEnd, '');
  }
  return t.trim();
}

/// Extracts the first JSON object `{...}` from [text], tolerating leading/
/// trailing prose and string-escaped braces. Returns the balanced object when
/// complete, or the truncated span `text[start..end]` when the object was cut
/// off mid-stream (so the caller can repair and parse it). Returns null if no
/// `{` is found at all.
String? _extractJsonObject(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escape = false;
  for (var i = start; i < text.length; i++) {
    final ch = text[i];
    if (inString) {
      if (escape) {
        escape = false;
      } else if (ch == '\\') {
        escape = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
  }
  // Reached end without balancing braces: this is a truncated object.
  if (depth > 0) return text.substring(start);
  return null;
}

/// Best-effort repair of a JSON object truncated mid-stream: closes any open
/// string, drops a dangling `"key"` with no value, then appends the correct
/// closing brackets/braces (in reverse order of the openers still pending) so
/// `jsonDecode` can parse the partial-but-usable data.
String _repairTruncated(String object) {
  var t = object.trim();
  // Close any string still open (covers `"key": "partial value` → valid value).
  if (t.contains('"') && _isStringOpen(t)) t = '$t"';
  // Drop a trailing dangling key (`"strength` with no `:` yet) and its comma.
  t = _stripDanglingKey(t);

  // Track opener/closer depth per bracket type, ignoring brackets inside
  // string literals, so we can close exactly what's still open.
  final closers = <String>[];
  var inString = false;
  var escape = false;
  for (var i = 0; i < t.length; i++) {
    final ch = t[i];
    if (inString) {
      if (escape) {
        escape = false;
      } else if (ch == '\\') {
        escape = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      closers.add('}');
    } else if (ch == '[') {
      closers.add(']');
    } else if (ch == '}' || ch == ']') {
      if (closers.isNotEmpty) closers.removeLast();
    }
  }
  // Append closers in reverse order: the most recently opened is closed first.
  t = '$t${closers.reversed.join()}';
  return t;
}

/// Removes a trailing dangling key such as `"strength` (no `:` + value yet) and
/// the comma before it. A complete `"key": "value"` is left untouched. Returns
/// the text unchanged when there is no trailing dangling key.
String _stripDanglingKey(String text) {
  // Locate the last quoted token in the string.
  var lastQuote = -1;
  for (var i = text.length - 1; i >= 0; i--) {
    if (text[i] == '"') {
      lastQuote = i;
      break;
    }
  }
  if (lastQuote < 0) return text;

  // The char immediately before the quote (ignoring spaces) tells us whether
  // this token is a value (preceded by `:`) or a dangling key (preceded by
  // `,`/`{`/`[`). Only a key position needs stripping.
  var j = lastQuote - 1;
  while (j >= 0 && text[j] == ' ') {
    j--;
  }
  if (j < 0 || text[j] == ':' || text[j] == '}') return text;

  // Back up to the preceding comma (or the enclosing opener) to drop the key.
  var comma = -1;
  for (var m = lastQuote - 1; m >= 0; m--) {
    if (text[m] == ',') {
      comma = m;
      break;
    }
    if (text[m] == '{' || text[m] == '[' || text[m] == '}') break;
  }
  if (comma < 0) return text;
  return text.substring(0, comma);
}

bool _isStringOpen(String text) {
  var inString = false;
  var escape = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (escape) {
      escape = false;
    } else if (ch == '\\') {
      escape = true;
    } else if (ch == '"') {
      inString = !inString;
    }
  }
  return inString;
}
