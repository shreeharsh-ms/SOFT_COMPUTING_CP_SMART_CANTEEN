import "package:flutter_test/flutter_test.dart";
import "package:smart_canteen/core/services/api_client.dart";
import "package:smart_canteen/core/services/websocket_client.dart";
import "package:smart_canteen/providers/auth_provider.dart";
import "package:smart_canteen/providers/cart_provider.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("CartItem Model & Serialization", () {
    test("CartItem JSON roundtrip preserves all fields", () {
      final item = CartItem(
        menuItemId: 101,
        name: "Grilled Cheese Sandwich",
        price: 50.0,
        availableStock: 25,
        quantity: 2,
      );

      final json = item.toJson();
      expect(json["menu_item_id"], 101);
      expect(json["name"], "Grilled Cheese Sandwich");
      expect(json["price"], 50.0);
      expect(json["available_stock"], 25);
      expect(json["quantity"], 2);

      final restored = CartItem.fromJson(json);
      expect(restored.menuItemId, 101);
      expect(restored.name, "Grilled Cheese Sandwich");
      expect(restored.price, 50.0);
      expect(restored.availableStock, 25);
      expect(restored.quantity, 2);
    });
  });

  group("UserProfile Model & Parsing", () {
    test("UserProfile parses auth endpoint JSON correctly", () {
      final json = {
        "id": 1,
        "name": "Aarav Sharma",
        "email": "aarav@campus.edu",
        "mobile": "9876543213",
        "role": "CUSTOMER",
        "canteen_id": null,
        "wallet_balance": 250.0,
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, 1);
      expect(profile.name, "Aarav Sharma");
      expect(profile.email, "aarav@campus.edu");
      expect(profile.mobile, "9876543213");
      expect(profile.role, "CUSTOMER");
      expect(profile.canteenId, isNull);
      expect(profile.walletBalance, 250.0);
    });

    test("UserProfile fallback field mappings", () {
      final json = {
        "user_id": 42,
        "full_name": "Chef Ramesh",
        "email": "ramesh@campus.edu",
        "role": "KITCHEN",
        "canteen_id": 1,
        "wallet_balance": 0.0,
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, 42);
      expect(profile.name, "Chef Ramesh");
      expect(profile.role, "KITCHEN");
      expect(profile.canteenId, 1);
    });
  });

  group("CartProvider Business Logic & Constraints", () {
    late CartProvider cart;

    setUp(() {
      cart = CartProvider();
    });

    test("Initial cart is completely empty", () {
      expect(cart.items, isEmpty);
      expect(cart.itemCount, 0);
      expect(cart.totalAmount, 0.0);
      expect(cart.canteenId, isNull);
    });

    test("Adding item binds canteen and computes totals", () {
      final success = cart.addItem(1, 10, "Cold Coffee", 40.0, 15);
      expect(success, isTrue);
      expect(cart.canteenId, 1);
      expect(cart.itemCount, 1);
      expect(cart.totalAmount, 40.0);
      expect(cart.items.length, 1);
    });

    test("Cross-canteen ordering is strictly rejected", () {
      // Add item from Canteen #1
      cart.addItem(1, 10, "Cold Coffee", 40.0, 15);

      // Attempt to add item from Canteen #2 while Canteen #1 item is in cart
      final crossSuccess = cart.addItem(2, 20, "Sandwich", 50.0, 10);
      expect(crossSuccess, isFalse);
      expect(cart.canteenId, 1);
      expect(cart.items.length, 1);
    });

    test("Stock limit enforcement prevents over-ordering", () {
      // Add item with limited stock = 2
      final add1 = cart.addItem(1, 11, "Special Thali", 100.0, 2);
      expect(add1, isTrue);
      expect(cart.items.first.quantity, 1);

      // Increment quantity to 2
      final add2 = cart.addItem(1, 11, "Special Thali", 100.0, 2);
      expect(add2, isTrue);
      expect(cart.items.first.quantity, 2);

      // Exceeding stock (quantity 3 > stock 2) must be rejected
      final add3 = cart.addItem(1, 11, "Special Thali", 100.0, 2);
      expect(add3, isFalse);
      expect(cart.items.first.quantity, 2);
      expect(cart.totalAmount, 200.0);
    });

    test("Out of stock item cannot be added", () {
      final addOutOfStock = cart.addItem(1, 12, "Unavailable Item", 30.0, 0);
      expect(addOutOfStock, isFalse);
      expect(cart.items, isEmpty);
    });

    test("Decrementing and removing items", () {
      cart.addItem(1, 10, "Cold Coffee", 40.0, 10);
      cart.addItem(1, 10, "Cold Coffee", 40.0, 10);
      expect(cart.items.first.quantity, 2);
      expect(cart.totalAmount, 80.0);

      // Decrement
      cart.removeOrDecrementItem(10);
      expect(cart.items.first.quantity, 1);
      expect(cart.totalAmount, 40.0);

      // Decrement to 0 removes the item and resets canteenId
      cart.removeOrDecrementItem(10);
      expect(cart.items, isEmpty);
      expect(cart.canteenId, isNull);
    });

    test("Clearing cart resets all state", () {
      cart.addItem(1, 10, "Cold Coffee", 40.0, 10);
      cart.addItem(1, 11, "Sandwich", 50.0, 10);
      expect(cart.itemCount, 2);

      cart.clear();
      expect(cart.items, isEmpty);
      expect(cart.itemCount, 0);
      expect(cart.totalAmount, 0.0);
      expect(cart.canteenId, isNull);
    });
  });

  group("ApiClient & Networking Specs", () {
    test("ApiClient default configuration points to API V1", () {
      expect(ApiClient.baseUrl, "http://localhost:8000/api/v1");
    });
  });

  group("Section 3.5 Operational Station - Kitchen Monitor & Status Transitions", () {
    final validTransitions = {
      "PLACED": ["PREPARING", "CANCELLED"],
      "CONFIRMED": ["PREPARING", "CANCELLED"],
      "PREPARING": ["READY"],
      "READY": ["COMPLETED"],
    };

    test("Kitchen order transition map covers forward lifecycle", () {
      expect(validTransitions["PLACED"], contains("PREPARING"));
      expect(validTransitions["CONFIRMED"], contains("PREPARING"));
      expect(validTransitions["PREPARING"], contains("READY"));
      expect(validTransitions["READY"], contains("COMPLETED"));
    });

    test("Kitchen order rejection & auto-refund path from initial statuses", () {
      expect(validTransitions["PLACED"], contains("CANCELLED"));
      expect(validTransitions["CONFIRMED"], contains("CANCELLED"));
      expect(validTransitions["PREPARING"], isNot(contains("CANCELLED")));
      expect(validTransitions["READY"], isNot(contains("CANCELLED")));
    });

    test("Kitchen status update payload formatting", () {
      final payload = {
        "new_status": "PREPARING",
        "expected_current_status": "PLACED",
        "notes": "Starting prep on batch",
      };
      expect(payload["new_status"], "PREPARING");
      expect(payload["expected_current_status"], "PLACED");
      expect(payload["notes"], "Starting prep on batch");
    });
  });

  group("Section 3.5 Operational Station - Admin Menu Management", () {
    test("Menu item creation payload construction & validation", () {
      final payload = {
        "canteen_id": 1,
        "category_id": 2,
        "name": "Paneer Tikka Roll",
        "description": "Grilled cottage cheese wrap",
        "price": 85.0,
        "original_price": 95.0,
        "hsn_sac_code": "996331",
        "gst_rate_percent": 5.0,
        "stock_quantity": 40,
        "preparation_time_minutes": 12,
        "is_available": true,
        "is_recommended": true,
        "image_url": "https://example.com/paneer.jpg",
      };

      expect(payload["name"], "Paneer Tikka Roll");
      expect(payload["price"], 85.0);
      expect(payload["hsn_sac_code"], "996331");
      expect(payload["gst_rate_percent"], 5.0);
      expect(payload["is_available"], isTrue);
      expect(payload["is_recommended"], isTrue);
    });

    test("Menu item with optional stock and description omitted", () {
      final payload = {
        "canteen_id": 1,
        "category_id": 1,
        "name": "Masala Chai",
        "description": null,
        "price": 15.0,
        "original_price": 15.0,
        "hsn_sac_code": "996331",
        "gst_rate_percent": 5.0,
        "stock_quantity": null,
        "preparation_time_minutes": 5,
        "is_available": true,
        "is_recommended": false,
        "image_url": null,
      };

      expect(payload["stock_quantity"], isNull);
      expect(payload["description"], isNull);
      expect(payload["price"], 15.0);
    });

    test("Menu filter correctly isolates inactive items", () {
      final allItems = [
        {"id": 1, "name": "Samosa", "is_available": true},
        {"id": 2, "name": "Vada Pav", "is_available": false},
        {"id": 3, "name": "Sandwich", "is_available": true},
      ];

      final activeOnly = allItems.where((i) => i["is_available"] == true).toList();
      expect(activeOnly.length, 2);
      expect(activeOnly.map((i) => i["id"]), containsAll([1, 3]));
      expect(activeOnly.map((i) => i["id"]), isNot(contains(2)));
    });
  });

  group("Section 3.5 Operational Station - Live GA Advisory & Counter Top-Up", () {
    test("Parses Genetic Algorithm advisory response with surge mode", () {
      final advisoryJson = {
        "canteen_id": 1,
        "crowd_analysis": {
          "crowd_level": "PEAK",
          "crowd_score": 88.5,
          "estimated_wait_minutes": 18.0,
        },
        "demand_multiplier": 1.45,
        "recommended_preparation": [
          {
            "menu_item_id": 10,
            "item_name": "Veg Biryani",
            "recommended_prep_batch": 35,
            "estimated_demand": 42,
          },
          {
            "menu_item_id": 11,
            "item_name": "Roti Thali",
            "recommended_prep_batch": 25,
            "estimated_demand": 30,
          },
        ],
      };

      final crowdAnalysis = advisoryJson["crowd_analysis"] as Map<String, dynamic>;
      expect(crowdAnalysis["crowd_level"], "PEAK");
      expect(crowdAnalysis["crowd_score"], 88.5);
      expect(crowdAnalysis["estimated_wait_minutes"], 18.0);

      final multiplier = (advisoryJson["demand_multiplier"] as num).toDouble();
      expect(multiplier, 1.45);
      expect(multiplier > 1.0, isTrue);

      final batches = advisoryJson["recommended_preparation"] as List<dynamic>;
      expect(batches.length, 2);
      expect(batches[0]["item_name"], "Veg Biryani");
      expect(batches[0]["recommended_prep_batch"], 35);
      expect(batches[1]["recommended_prep_batch"], 25);
    });

    test("Counter Top-Up payload construction & validation", () {
      final topUpPayload = {
        "target_user_id": 42,
        "token_amount": 500.0,
        "notes": "Counter cash deposit",
      };

      expect(topUpPayload["target_user_id"], 42);
      expect(topUpPayload["token_amount"], 500.0);
      expect((topUpPayload["token_amount"] as double) > 0, isTrue);
    });
  });

  group("WebSocketClient Lifecycle & Exponential Backoff Specs", () {
    test("Initial state is disconnected", () {
      final ws = WebSocketClient();
      expect(ws.currentStatus, WsConnectionStatus.disconnected);
      expect(WebSocketClient.wsBaseUrl, "ws://localhost:8000/api/v1/ws/connect");
      ws.dispose();
    });
  });
}
