import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Thrown when `/commit` returns 409 — `main` moved since this draft's
/// `baseSha` was loaded. The caller's only recourse is to reload and redo
/// the edit; there is no merge UI (see EXECUTION.md's G-4 conflict policy).
class CommitConflictException implements Exception {
  const CommitConflictException(this.message);
  final String message;
  @override
  String toString() => 'CommitConflictException: $message';
}

class CmsApiException implements Exception {
  const CmsApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'CmsApiException($statusCode): $message';
}

class ContentAtHead {
  const ContentAtHead(this.sha, this.files);
  final String sha;
  final Map<String, String> files;
}

class PublishRunStatus {
  const PublishRunStatus({
    required this.status,
    required this.conclusion,
    required this.htmlUrl,
    required this.createdAt,
  });

  factory PublishRunStatus.fromJson(Map<String, dynamic> json) => PublishRunStatus(
    status: json['status'] as String,
    conclusion: json['conclusion'] as String?,
    htmlUrl: json['htmlUrl'] as String,
    createdAt: json['createdAt'] as String,
  );

  final String status;
  final String? conclusion;
  final String htmlUrl;
  final String createdAt;

  bool get isRunning => status != 'completed';
  bool get succeeded => status == 'completed' && conclusion == 'success';
}

/// Talks to `services/cms_api` (the Cloudflare Worker) — the CMS never
/// holds a GitHub token or R2 keys itself. [idTokenProvider] is called
/// fresh on every request since Firebase ID tokens expire hourly.
class CmsApiClient {
  CmsApiClient({required this.baseUrl, required this.idTokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final Future<String> Function() idTokenProvider;
  final http.Client _client;

  Future<Map<String, String>> _headers({String? contentType}) async {
    final token = await idTokenProvider();
    return {
      'Authorization': 'Bearer $token',
      if (contentType != null) 'Content-Type': contentType,
    };
  }

  Future<ContentAtHead> getContent() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/content'),
      headers: await _headers(),
    );
    _throwIfError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ContentAtHead(
      body['sha'] as String,
      (body['files'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
    );
  }

  /// [files] maps path → new text, or null to delete. Throws
  /// [CommitConflictException] on a 409.
  Future<String> commit({
    required String baseSha,
    required Map<String, String?> files,
    required String message,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/commit'),
      headers: await _headers(contentType: 'application/json'),
      body: jsonEncode({'baseSha': baseSha, 'files': files, 'message': message}),
    );
    if (res.statusCode == 409) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw CommitConflictException(body['error'] as String? ?? 'main moved');
    }
    _throwIfError(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['sha'] as String;
  }

  Future<void> putMedia({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/media').replace(queryParameters: {'path': path}),
      headers: await _headers(contentType: contentType),
      body: bytes,
    );
    _throwIfError(res);
  }

  Future<Uint8List> getMedia(String path) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/media').replace(queryParameters: {'path': path}),
      headers: await _headers(),
    );
    _throwIfError(res);
    return res.bodyBytes;
  }

  Future<void> publish({required bool dryRun}) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/publish'),
      headers: await _headers(contentType: 'application/json'),
      body: jsonEncode({'dryRun': dryRun}),
    );
    _throwIfError(res);
  }

  Future<PublishRunStatus?> publishStatus() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/publish/status'),
      headers: await _headers(),
    );
    _throwIfError(res);
    final body = jsonDecode(res.body);
    if (body == null) return null;
    return PublishRunStatus.fromJson(body as Map<String, dynamic>);
  }

  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String message = res.body;
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) message = body['error'] as String;
    } catch (_) {
      // Non-JSON error body — use the raw text.
    }
    throw CmsApiException(res.statusCode, message);
  }
}
