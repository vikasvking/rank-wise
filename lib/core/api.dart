import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'json.dart';

/// An error from the Rankwise API. [code] is machine-readable ("pin_required", "blocked"...),
/// [message] is ready to show to the user.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [J? body])
    : body = body ?? <String, dynamic>{};

  final int status;
  final String code;
  final String message;
  final J body;

  @override
  String toString() => message;
}

/// Talks to `<kSiteUrl>/api/v1` with the signed-in user's token.
class ApiClient {
  String? token;

  /// Called when the server says the token is no longer valid (signed out elsewhere, deleted...).
  void Function()? onUnauthorized;

  Uri uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(kSiteUrl);
    final params = <String, String>{
      if (query != null)
        for (final e in query.entries)
          if (e.value != null && e.value.toString().isNotEmpty)
            e.key: e.value.toString(),
    };
    return base.replace(
      path: '/api/v1$path',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<J> get(String path, [Map<String, dynamic>? query]) =>
      _send('GET', path, query: query);
  Future<J> post(String path, [J? body]) =>
      _send('POST', path, body: body ?? <String, dynamic>{});
  Future<J> patch(String path, [J? body]) =>
      _send('PATCH', path, body: body ?? <String, dynamic>{});
  Future<J> delete(String path) => _send('DELETE', path);

  Future<J> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    J? body,
  }) async {
    final request = http.Request(method, uri(path, query));
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';
    final t = token;
    if (t != null) request.headers['Authorization'] = 'Bearer $t';
    if (body != null) request.body = jsonEncode(body);

    final http.Response res;
    try {
      final streamed = await request.send().timeout(kRequestTimeout);
      res = await http.Response.fromStream(streamed).timeout(kRequestTimeout);
    } on TimeoutException {
      throw ApiException(
        0,
        'timeout',
        'Rankwise is taking too long to answer. It may be waking up; please try again.',
      );
    } catch (e) {
      // Say which server failed and why, so a wrong address or a blocked connection is easy to spot.
      final host = Uri.parse(kSiteUrl).host;
      final reason = e.toString().contains('Failed host lookup')
          ? 'the address $host was not found (check RANKWISE_URL in lib/core/config.dart)'
          : '${e.runtimeType} while contacting $host';
      throw ApiException(
        0,
        'offline',
        'Could not reach Rankwise: $reason. Check your internet connection and try again.',
      );
    }

    J data = <String, dynamic>{};
    if (res.bodyBytes.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // not JSON (e.g. an HTML error page); handled below
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final error = data.obj('error');
    final code = error.str('code', 'http_${res.statusCode}');
    final message = error.str(
      'message',
      res.statusCode >= 500
          ? 'Something went wrong on the server. Please try again.'
          : 'Request failed (${res.statusCode}).',
    );
    if (res.statusCode == 401 && t != null) onUnauthorized?.call();
    throw ApiException(res.statusCode, code, message, data);
  }
}
