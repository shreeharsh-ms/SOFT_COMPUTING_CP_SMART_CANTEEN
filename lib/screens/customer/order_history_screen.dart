import "dart:async";
import "dart:convert";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";
import "../../core/services/api_client.dart";
import "../../core/services/websocket_client.dart";
import "../../providers/cart_provider.dart";
import "order_detail_screen.dart";
import "invoice_screen.dart";

class OrderHistoryScreen extends StatefulWidget {
  final WebSocketClient wsClient;
  const OrderHistoryScreen({super.key, required this.wsClient});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String _searchQuery = "";
  StreamSubscription? _wsSubscription;

  final TextEditingController _searchController = TextEditingController();

  // Curated online grocery & food dish images for visual previews
  final List<String> _sampleImages = [
    "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=200&auto=format&fit=crop&q=60",
    "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=200&auto=format&fit=crop&q=60",
    "https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=200&auto=format&fit=crop&q=60",
    "https://images.unsplash.com/photo-1610192244261-3f33de3f55e4?w=200&auto=format&fit=crop&q=60",
    "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=200&auto=format&fit=crop&q=60",
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _listenWebSockets();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenWebSockets() {
    _wsSubscription = widget.wsClient.messages.listen((msg) {
      final type = msg["type"] as String?;
      if (type == "ORDER_STATUS_UPDATE" ||
          type == "ORDER_REFUNDED" ||
          type == "ORDER_CANCELLED" ||
          type == "NEW_ORDER") {
        _fetchOrders();
      }
    });
  }

  Future<void> _fetchOrders() async {
    try {
      final res = await ApiClient.get("/orders");
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _orders = jsonDecode(res.body) as List<dynamic>;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getFilteredOrders() {
    if (_searchQuery.trim().isEmpty) return _orders;
    final q = _searchQuery.toLowerCase();
    return _orders.where((o) {
      final numStr = (o["order_number"] as String? ?? "").toLowerCase();
      final items = (o["items"] as List<dynamic>? ?? []);
      final itemMatch = items.any((it) => (it["item_name"] as String? ?? "").toLowerCase().contains(q));
      return numStr.contains(q) || itemMatch;
    }).toList();
  }

  void _showOrderInfoBottomSheet(dynamic order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Order Info",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),

                // Delete order tile
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                  title: Text(
                    "Delete order",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    "You won't be able to access this order once deleted",
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmationDialog(order);
                  },
                ),

                const Divider(height: 1),

                // Share order items tile
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0F172A), size: 20),
                  ),
                  title: Text(
                    "Share order items",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    "We will not share other details, only items will get shared",
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Order items link copied to clipboard!")),
                    );
                  },
                ),

                const Divider(height: 1),

                // View GST Invoice tile
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFEA580C), size: 20),
                  ),
                  title: Text(
                    "Tax Invoice & Receipt",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    "Download statutory GST invoice PDF / HTML",
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceScreen(orderId: order["id"] as int),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(dynamic order) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Text(
            "Are you sure you want to delete this order?",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildBulletPoint("You won't be able to access details of this and other related orders through your account"),
              const SizedBox(height: 8),
              _buildBulletPoint("If this order was placed by/ for someone else, it will still be visible in their account"),
              const SizedBox(height: 8),
              _buildBulletPoint("Any form of customer support won't be available for this and related orders"),
              const SizedBox(height: 8),
              _buildBulletPoint("Recommendations for deleted items may take up to 24 hours to update"),
            ],
          ),
          actionsPadding: EdgeInsets.zero,
          actions: [
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20)),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 48, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _executeDeleteOrder(order["id"] as int);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(bottomRight: Radius.circular(20)),
                      ),
                    ),
                    child: Text(
                      "Delete",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 8),
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Color(0xFF64748B),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _executeDeleteOrder(int orderId) async {
    try {
      final res = await ApiClient.delete("/orders/$orderId");
      if (res.statusCode == 200) {
        setState(() {
          _orders.removeWhere((o) => o["id"] == orderId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Order removed from your history")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete order")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  void _handleReorder(dynamic order) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final items = order["items"] as List<dynamic>? ?? [];
    final canteenId = order["canteen_id"] as int;

    int addedCount = 0;
    for (final it in items) {
      final ok = cart.addItem(
        canteenId,
        it["menu_item_id"] as int,
        it["item_name"] as String,
        (it["unit_price"] as num).toDouble(),
        10,
      );
      if (ok) addedCount++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added $addedCount items to your cart!"),
        action: SnackBarAction(
          label: "View Cart",
          textColor: const Color(0xFFFED7AA),
          onPressed: () {
            // Cart navigation
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _getFilteredOrders();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          "Order History",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
          : RefreshIndicator(
              color: const Color(0xFFEA580C),
              onRefresh: _fetchOrders,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: [
                    // 1. Search Bar
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: "Search your campus orders...",
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            color: const Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF16A34A), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = "");
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. Order Cards
                    if (filteredOrders.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 60, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text(
                              "No orders found",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Orders placed in campus canteens will appear here.",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, idx) {
                          final order = filteredOrders[idx];
                          final total = (order["total_amount"] as num).toDouble();
                          final status = (order["status"] as String?) ?? "COMPLETED";
                          final items = order["items"] as List<dynamic>? ?? [];
                          final orderDate = DateTime.tryParse(order["created_at"] as String? ?? "") ?? DateTime.now();
                          final formattedDate = DateFormat("dd MMM, h:mm a").format(orderDate.toLocal());
                          final isCompleted = status == "COMPLETED" || status == "READY";

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header: Status Checkmark + Price + 3-dots action
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Rounded Square Checkmark Badge
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isCompleted ? Icons.check_rounded : Icons.hourglass_top_rounded,
                                          color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isCompleted ? "Arrived in 6 minutes" : "Status: $status",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "₹${total.toStringAsFixed(0)} • $formattedDate",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 3-dots Menu Button
                                      IconButton(
                                        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
                                        onPressed: () => _showOrderInfoBottomSheet(order),
                                      ),
                                    ],
                                  ),
                                ),

                                // Optional Customer Banner (like "Order placed by 86250XXXXX")
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 14),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.shopping_bag_rounded, size: 14, color: Color(0xFFEA580C)),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Order #${order["order_number"] ?? order["id"]}",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Food Items Avatars Row
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Row(
                                    children: [
                                      ...List.generate(
                                        items.length > 4 ? 4 : items.length,
                                        (i) {
                                          final img = _sampleImages[i % _sampleImages.length];
                                          return Container(
                                            margin: const EdgeInsets.only(right: 10),
                                            width: 54,
                                            height: 54,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(11),
                                              child: Image.network(
                                                img,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: const Color(0xFFF8FAFC),
                                                  child: const Icon(Icons.fastfood, size: 24, color: Color(0xFFEA580C)),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (items.length > 4)
                                        Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              "+${items.length - 4}",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),
                                const Divider(height: 1),

                                // Bottom Actions: "Reorder" and "Rate order"
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => _handleReorder(order),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: Text(
                                          "Reorder",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(width: 1, height: 28, color: const Color(0xFFF1F5F9)),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => OrderDetailScreen(
                                                orderId: order["id"] as int,
                                                wsClient: widget.wsClient,
                                              ),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: Text(
                                          "View Details",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
