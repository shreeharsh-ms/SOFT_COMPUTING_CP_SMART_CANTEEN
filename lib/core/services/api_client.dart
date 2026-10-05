import "dart:convert";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:flutter_secure_storage/flutter_secure_storage.dart";

class ApiClient {
  static const String baseUrl = "https://backend-gules-three-14.vercel.app/api/v1";
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static VoidCallback? onUnauthorized;

  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: "jwt_token");
    } catch (_) {
      return null;
    }
  }

  static Future<void> setToken(String token) async {
    await _storage.write(key: "jwt_token", value: token);
  }

  static Future<void> clearAuth() async {
    await _storage.delete(key: "jwt_token");
  }

  static Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
    if (requiresAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers["Authorization"] = "Bearer $token";
      }
    }
    return headers;
  }

  static Future<http.Response> get(String endpoint, {bool requiresAuth = true}) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final headers = await _headers(requiresAuth: requiresAuth);
    final response = await http.get(url, headers: headers);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> post(String endpoint, {Map<String, dynamic>? body, bool requiresAuth = true}) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final headers = await _headers(requiresAuth: requiresAuth);
    final response = await http.post(url, headers: headers, body: body != null ? jsonEncode(body) : null);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> put(String endpoint, {Map<String, dynamic>? body, bool requiresAuth = true}) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final headers = await _headers(requiresAuth: requiresAuth);
    final response = await http.put(url, headers: headers, body: body != null ? jsonEncode(body) : null);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> patch(String endpoint, {Map<String, dynamic>? body, bool requiresAuth = true}) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final headers = await _headers(requiresAuth: requiresAuth);
    final response = await http.patch(url, headers: headers, body: body != null ? jsonEncode(body) : null);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> delete(String endpoint, {bool requiresAuth = true}) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final headers = await _headers(requiresAuth: requiresAuth);
    final response = await http.delete(url, headers: headers);
    _checkUnauthorized(response);
    return response;
  }

  static void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      clearAuth();
      if (onUnauthorized != null) {
        onUnauthorized!();
      }
    }
  }
}
