import "dart:convert";
import "package:flutter/material.dart";
import "../core/services/api_client.dart";
import "cart_provider.dart";

class UserProfile {
  final int id;
  final String name;
  final String email;
  final String? mobile;
  final String role;
  final int? canteenId;
  final double walletBalance;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.mobile,
    required this.role,
    this.canteenId,
    required this.walletBalance,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json["id"] ?? json["user_id"] as int,
      name: (json["name"] ?? json["full_name"] ?? "") as String,
      email: (json["email"] ?? "") as String,
      mobile: json["mobile"] as String?,
      role: (json["role"] ?? "CUSTOMER") as String,
      canteenId: json["canteen_id"] as int?,
      walletBalance: (json["wallet_balance"] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  UserProfile? _user;
  bool _isLoading = true;
  String? _errorMessage;

  UserProfile? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Restores session and automatically reloads the user's cart
  Future<void> initAuth(CartProvider cartProvider) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = await ApiClient.getToken();
      if (token != null && token.isNotEmpty) {
        final res = await ApiClient.get("/auth/me");
        if (res.statusCode == 200) {
          _user = UserProfile.fromJson(jsonDecode(res.body));
          await cartProvider.loadUserCart(_user!.id);
        } else {
          await ApiClient.clearAuth();
          _user = null;
        }
      }
    } catch (e) {
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String mobile,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        "/auth/register",
        body: {
          "name": name,
          "email": email,
          "mobile": mobile,
          "password": password,
        },
        requiresAuth: false,
      );

      _isLoading = false;
      if (res.statusCode == 201) {
        notifyListeners();
        return true;
      } else {
        final err = jsonDecode(res.body);
        _errorMessage = _parseError(err) ?? "Registration failed";
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = "Network error during registration: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String? _parseError(dynamic err) {
    if (err is Map) {
      final detail = err["detail"];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first["msg"] != null) {
          final loc = (first["loc"] as List?)?.last?.toString();
          return loc != null ? "$loc: ${first["msg"]}" : "${first["msg"]}";
        }
        return detail.join(", ");
      }
    }
    return null;
  }

  Future<bool> login(String identifier, String password, CartProvider cartProvider) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        "/auth/login",
        body: {"identifier": identifier, "password": password},
        requiresAuth: false,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data["access_token"] as String;
        await ApiClient.setToken(token);
        
        _user = UserProfile.fromJson(data);
        await cartProvider.loadUserCart(_user!.id);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final err = jsonDecode(res.body);
        _errorMessage = _parseError(err) ?? "Invalid credentials";
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = "Network error: unable to connect to server";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout(CartProvider cartProvider) async {
    final currentUserId = _user?.id;
    if (currentUserId != null) {
      await cartProvider.clearCurrentUserCart(currentUserId);
    }
    await ApiClient.clearAuth();
    _user = null;
    notifyListeners();
  }

  void updateWalletBalance(double newBalance) {
    if (_user != null) {
      _user = UserProfile(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        mobile: _user!.mobile,
        role: _user!.role,
        canteenId: _user!.canteenId,
        walletBalance: newBalance,
      );
      notifyListeners();
    }
  }
}
