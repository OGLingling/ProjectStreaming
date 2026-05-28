import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://projectstreaming-1.onrender.com/api';

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static const Map<String, String> _streamProbeHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  static const Set<String> _invalidStringValues = {
    'null',
    'undefined',
    'none',
    'nan',
  };

  static String? _cleanString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || _invalidStringValues.contains(text.toLowerCase())) {
      return null;
    }
    return text;
  }

  static String? _cleanId(dynamic value) {
    final text = _cleanString(value);
    if (text == null) return null;
    return text;
  }

  static Uri _apiUri(String path, [Map<String, String?> query = const {}]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$baseUrl/$cleanPath').replace(
      queryParameters: {
        for (final entry in query.entries)
          if (_cleanString(entry.value) != null)
            entry.key: _cleanString(entry.value)!,
      },
    );
  }

  static Future<List<dynamic>> getMoviesByType(String type) async {
    try {
      final response = await http
          .get(_apiUri('movies', {'type': type, 'limit': '300'}))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error getMoviesByType: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getViewingProgress(String userId) async {
    try {
      final cleanUserId = _cleanId(userId);
      if (cleanUserId == null) return [];

      final response = await http
          .get(_apiUri('viewing-progress', {'userId': cleanUserId}))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Error getViewingProgress: $e');
    }
    return [];
  }

  static Future<void> saveViewingProgress({
    required String userId,
    int? contentId,
    String? tmdbId,
    required int seasonNumber,
    required int episodeNumber,
    required int progressSeconds,
    int? durationSeconds,
    bool completed = false,
  }) async {
    try {
      final cleanUserId = _cleanId(userId);
      final cleanTmdbId = _cleanId(tmdbId);
      if (cleanUserId == null || (contentId == null && cleanTmdbId == null)) {
        return;
      }

      await http
          .post(
            _apiUri('viewing-progress'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'userId': cleanUserId,
              if (contentId != null && contentId > 0) 'contentId': contentId,
              'tmdbId': ?cleanTmdbId,
              'seasonNumber': seasonNumber,
              'episodeNumber': episodeNumber,
              'progressSeconds': progressSeconds,
              if (durationSeconds != null && durationSeconds > 0)
                'durationSeconds': durationSeconds,
              'completed': completed,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error saveViewingProgress: $e');
    }
  }

  static Future<void> completeViewingProgress({
    required String userId,
    int? contentId,
    String? tmdbId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    try {
      final cleanUserId = _cleanId(userId);
      final cleanTmdbId = _cleanId(tmdbId);
      if (cleanUserId == null || (contentId == null && cleanTmdbId == null)) {
        return;
      }

      await http
          .post(
            _apiUri('viewing-progress/complete'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'userId': cleanUserId,
              if (contentId != null && contentId > 0) 'contentId': contentId,
              'tmdbId': ?cleanTmdbId,
              'seasonNumber': seasonNumber,
              'episodeNumber': episodeNumber,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error completeViewingProgress: $e');
    }
  }

  static Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      final response = await http
          .get(_apiUri('users', {'email': email.toLowerCase()}))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }
    } catch (e) {
      debugPrint('Error getUserDataByEmail: $e');
    }
    return null;
  }

  static Future<bool> sendOTP(String email) async {
    try {
      final response = await http
          .post(
            _apiUri('auth/send-otp'),
            headers: _jsonHeaders,
            body: jsonEncode({'email': email.toLowerCase().trim()}),
          )
          .timeout(const Duration(seconds: 12));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sendOTP: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> verifyOTP(
    String email,
    String otp,
  ) async {
    try {
      final response = await http
          .post(
            _apiUri('auth/verify-otp'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'email': email.toLowerCase().trim(),
              'code': otp.trim(),
              'otp': otp.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }
    } catch (e) {
      debugPrint('Error verifyOTP: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String name,
    required String plan,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            _apiUri('auth/register'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'email': email.toLowerCase().trim(),
              'name': name.trim(),
              'plan': plan.trim(),
              'password': password.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }
    } catch (e) {
      debugPrint('Error registerUser: $e');
    }
    return null;
  }

  static Future<bool> updateUser(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final cleanUserId = _cleanId(userId);
      if (cleanUserId == null) return false;

      final response = await http
          .put(
            _apiUri('auth/users/$cleanUserId'),
            headers: _jsonHeaders,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 12));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updateUser: $e');
      return false;
    }
  }

  static Future<bool> deleteUser(String userId) async {
    try {
      final cleanUserId = _cleanId(userId);
      if (cleanUserId == null) return false;

      final response = await http
          .delete(_apiUri('auth/users/$cleanUserId'), headers: _jsonHeaders)
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleteUser: $e');
      return false;
    }
  }

  static Future<List<String>> getExtractionCandidates({
    String? tmdbId,
    String? url,
    required String type,
    int? season,
    int? episode,
  }) async {
    try {
      final response = await http
          .get(
            _apiUri('extract', {
              'tmdbId': _cleanId(tmdbId),
              'url': _cleanString(url),
              'type': type,
              'season': season?.toString(),
              'episode': episode?.toString(),
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final candidates = decoded['candidates'] ?? decoded['urls'];
          if (candidates is List) {
            return candidates
                .map((candidate) => candidate.toString().trim())
                .where((candidate) => candidate.startsWith('http'))
                .toSet()
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error getExtractionCandidates: $e');
    }
    return [];
  }

  static Future<String?> getValidStreamUrl({
    String? tmdbId,
    String? url,
    required String type,
    int? season,
    int? episode,
  }) async {
    final candidates = await getExtractionCandidates(
      tmdbId: tmdbId,
      url: url,
      type: type,
      season: season,
      episode: episode,
    );

    for (final candidate in candidates) {
      try {
        final response = await http
            .get(Uri.parse(candidate), headers: _streamProbeHeaders)
            .timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 &&
            response.statusCode < 400 &&
            response.body.length > 800) {
          return candidate;
        }
      } catch (e) {
        debugPrint('Stream candidate rejected: $candidate - $e');
      }
    }
    return null;
  }

  static Future<String?> createStreamSession({
    required String url,
    String? sourceUrl,
    Map<String, String>? headers,
  }) async {
    try {
      final payload = <String, dynamic>{
        'url': url.trim(),
        if (sourceUrl != null && sourceUrl.trim().isNotEmpty)
          'sourceUrl': sourceUrl.trim(),
      };

      if (headers != null) {
        payload['headers'] = headers;
      }

      final response = await http
          .post(
            _apiUri('stream/register'),
            headers: _jsonHeaders,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final streamUrl = decoded['streamUrl']?.toString();
          if (streamUrl != null && streamUrl.startsWith('http')) {
            return streamUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('Error createStreamSession: $e');
    }
    return null;
  }
}
