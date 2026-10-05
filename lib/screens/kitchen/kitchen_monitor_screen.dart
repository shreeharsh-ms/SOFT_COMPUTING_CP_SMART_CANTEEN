import "dart:async";
import "dart:convert";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../core/services/api_client.dart";
import "../../core/services/websocket_client.dart";
import "../../providers/auth_provider.dart";
import "../../providers/cart_provider.dart";

class KitchenMonitorScreen extends StatefulWidget {
  final int canteenId;
  final WebSocketClient wsClient;

  const KitchenMonitorScreen({super.key, required this.canteenId, required this.wsClient});

  @override
  State<KitchenMonitorScreen> createState() => _KitchenMonitorScreenState();
}

class _KitchenMonitorScreenState extends State<KitchenMonitorScreen> {
  List<dynamic> _kitchenOrders = [];
  bool _isLoading = true;
  Timer? _psoDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadKitchenQueue();
    _subscribeKitchenEvents();
  }

  void _subscribeKitchenEvents() {
    widget.wsClient.messages.listen((event) {
      if (event["type"] == "NEW_ORDER" ||
          event["type"] == "ORDER_STATUS_UPDATE" ||
          event["type"] == "KITCHEN_ORDER_STATUS_CHANGED" ||
          event["type"] == "ORDER_CANCELLED") {
        _psoDebounceTimer?.cancel();
        _psoDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
          _loadKitchenQueue();
        });
      }
    });
  }

  Future<void> _loadKitchenQueue() async {
    try {
      final res = await ApiClient.get("/kitchen/orders?canteen_id=${widget.canteenId}");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _kitchenOrders = data["orders"] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading kitchen orders: $e");
    }
  }

  Future<void> _updateStatus(int orderId, String targetStatus, String expectedStatus, {String? reason}) async {
    try {
      final res = await ApiClient.patch(
        "/kitchen/orders/$orderId/status",
        body: {
          "new_status": targetStatus,
          "expected_current_status": expectedStatus,
          "notes": reason,
        },
      );
      if (res.statusCode == 200) {
        _loadKitchenQueue();
      } else {
        final err = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text(err["detail"] ?? "Transition rejected")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Network error: $e")),
        );
      }
    }
  }

  Future<void> _handleRejectOrder(int orderId, String currentStatus) async {
    final reasonCtrl = TextEditingController(text: "Ingredient out of stock");
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Order & Refund Student"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("This will cancel the order and immediately refund 100% of tokens to the student's digital wallet."),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: "Rejection Reason")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reject & Refund", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateStatus(orderId, "CANCELLED", currentStatus, reason: reasonCtrl.text.trim());
    }
  }

  @override
  void dispose() {
    _psoDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Kitchen Station - Canteen #${widget.canteenId}",
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Refresh Queue",
            onPressed: _loadKitchenQueue,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Sign Out",
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Sign Out"),
                  content: const Text("Are you sure you want to sign out of the Kitchen Station?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Sign Out"),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final cart = Provider.of<CartProvider>(context, listen: false);
                await auth.logout(cart);
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _kitchenOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, size: 54, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Kitchen Queue All Clear",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "No orders currently waiting for preparation.\nNew orders will appear here automatically via WebSocket.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisExtent: 280,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _kitchenOrders.length,
                  itemBuilder: (context, idx) {
                final order = _kitchenOrders[idx];
                final status = order["status"] as String;
                final items = order["items"] as List<dynamic>? ?? [];

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Token: ${order["token"]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("#${order["id"]}", style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                        const Divider(),
                        Expanded(
                          child: ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (c, i) => Text(
                              "${items[i]["quantity"]}x ${items[i]["name"]}",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        const Divider(),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (status == "PLACED" || status == "CONFIRMED") ...[
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _handleRejectOrder(order["id"] as int, status),
                                child: const Text("Reject"),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _updateStatus(order["id"] as int, "PREPARING", status),
                                child: const Text("Start Prep", style: TextStyle(color: Colors.white)),
                              ),
                            ],
                            if (status == "PREPARING")
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _updateStatus(order["id"] as int, "READY", "PREPARING"),
                                child: const Text("Mark Ready", style: TextStyle(color: Colors.white)),
                              ),
                            if (status == "READY")
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _updateStatus(order["id"] as int, "COMPLETED", "READY"),
                                child: const Text("Handover", style: TextStyle(color: Colors.white)),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
