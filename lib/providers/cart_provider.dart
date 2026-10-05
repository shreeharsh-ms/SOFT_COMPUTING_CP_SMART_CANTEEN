import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

class CartItem {
  final int menuItemId;
  final String name;
  final double price;
  final int? availableStock;
  final String? imageUrl;
  final String? description;
  int quantity;

  CartItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    this.availableStock,
    this.imageUrl,
    this.description,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
    "menu_item_id": menuItemId,
    "name": name,
    "price": price,
    "available_stock": availableStock,
    "quantity": quantity,
    if (imageUrl != null) "image_url": imageUrl,
    if (description != null) "description": description,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    menuItemId: json["menu_item_id"] as int,
    name: json["name"] as String,
    price: (json["price"] as num).toDouble(),
    availableStock: json["available_stock"] as int?,
    imageUrl: json["image_url"] as String?,
    description: json["description"] as String?,
    quantity: json["quantity"] as int,
  );
}

class CartProvider extends ChangeNotifier {
  int? _canteenId;
  int? _currentUserId;
  final Map<int, CartItem> _items = {};

  int? get canteenId => _canteenId;
  int? get currentUserId => _currentUserId;
  List<CartItem> get items => _items.values.toList();
  int get itemCount => _items.values.fold(0, (sum, i) => sum + i.quantity);
  double get totalAmount => _items.values.fold(0.0, (sum, i) => sum + (i.price * i.quantity));

  String _getStorageKey(int userId) => "persisted_cart_state_v1_$userId";

  Future<void> loadUserCart(int userId) async {
    _currentUserId = userId;
    _items.clear();
    _canteenId = null;

    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getString(_getStorageKey(userId));
    if (rawData != null && rawData.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawData) as Map<String, dynamic>;
        _canteenId = decoded["canteen_id"] as int?;
        final itemsList = decoded["items"] as List<dynamic>;
        for (var it in itemsList) {
          final item = CartItem.fromJson(it as Map<String, dynamic>);
          _items[item.menuItemId] = item;
        }
      } catch (e) {
        debugPrint("Error restoring persisted cart: $e");
      }
    }
    notifyListeners();
  }

  Future<void> _saveToDisk() async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _getStorageKey(_currentUserId!);
    if (_items.isEmpty) {
      await prefs.remove(key);
    } else {
      final payload = {
        "canteen_id": _canteenId,
        "items": _items.values.map((i) => i.toJson()).toList(),
      };
      await prefs.setString(key, jsonEncode(payload));
    }
  }

  Future<void> clearCurrentUserCart(int userId) async {
    _items.clear();
    _canteenId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getStorageKey(userId));
    notifyListeners();
  }

  bool addItem(
    int canteenId,
    int menuItemId,
    String name,
    double price,
    int? availableStock, {
    String? imageUrl,
    String? description,
  }) {
    if (_canteenId != null && _canteenId != canteenId && _items.isNotEmpty) {
      return false; // Cross-canteen ordering constraint
    }

    _canteenId = canteenId;
    if (_items.containsKey(menuItemId)) {
      final cur = _items[menuItemId]!;
      if (availableStock != null && cur.quantity + 1 > availableStock) {
        return false; // Stock limit reached
      }
      cur.quantity += 1;
    } else {
      if (availableStock != null && availableStock < 1) {
        return false; // Out of stock
      }
      _items[menuItemId] = CartItem(
        menuItemId: menuItemId,
        name: name,
        price: price,
        availableStock: availableStock,
        imageUrl: imageUrl,
        description: description,
        quantity: 1,
      );
    }
    _saveToDisk();
    notifyListeners();
    return true;
  }

  void removeItem(int menuItemId) {
    if (!_items.containsKey(menuItemId)) return;
    _items.remove(menuItemId);
    if (_items.isEmpty) {
      _canteenId = null;
    }
    _saveToDisk();
    notifyListeners();
  }

  void removeOrDecrementItem(int menuItemId) {
    if (!_items.containsKey(menuItemId)) return;
    final cur = _items[menuItemId]!;
    if (cur.quantity > 1) {
      cur.quantity -= 1;
    } else {
      _items.remove(menuItemId);
      if (_items.isEmpty) {
        _canteenId = null;
      }
    }
    _saveToDisk();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _canteenId = null;
    _saveToDisk();
    notifyListeners();
  }
}
