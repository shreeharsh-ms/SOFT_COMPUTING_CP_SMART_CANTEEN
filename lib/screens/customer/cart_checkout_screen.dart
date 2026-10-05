import "dart:convert";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";
import "../../core/services/api_client.dart";
import "../../core/services/websocket_client.dart";
import "../../providers/auth_provider.dart";
import "../../providers/cart_provider.dart";
import "order_detail_screen.dart";

class CartCheckoutScreen extends StatefulWidget {
  final WebSocketClient wsClient;
  final VoidCallback? onNavigateHome;

  const CartCheckoutScreen({
    super.key,
    required this.wsClient,
    this.onNavigateHome,
  });

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  final TextEditingController _promoController = TextEditingController();
  bool _isSubmitting = false;
  String? _appliedPromoCode;
  double _discountAmount = 0.0;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  void _applyPromoCode(double subtotal) {
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code == "CAMPUS50") {
      setState(() {
        _appliedPromoCode = code;
        _discountAmount = (subtotal * 0.50).clamp(0.0, 50.0);
      });
      _showSnack("🎉 CAMPUS50 applied! Saved ₹${_discountAmount.toStringAsFixed(2)}", isError: false);
    } else if (code == "WELCOME20") {
      setState(() {
        _appliedPromoCode = code;
        _discountAmount = (subtotal * 0.20).clamp(0.0, 30.0);
      });
      _showSnack("🎉 WELCOME20 applied! Saved ₹${_discountAmount.toStringAsFixed(2)}", isError: false);
    } else if (code == "STUDENT10") {
      setState(() {
        _appliedPromoCode = code;
        _discountAmount = (subtotal * 0.10).clamp(0.0, 20.0);
      });
      _showSnack("🎉 STUDENT10 applied! Saved ₹${_discountAmount.toStringAsFixed(2)}", isError: false);
    } else {
      _showSnack("Invalid promo code. Try CAMPUS50, WELCOME20 or STUDENT10", isError: true);
    }
  }

  void _removePromo() {
    setState(() {
      _appliedPromoCode = null;
      _discountAmount = 0.0;
      _promoController.clear();
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleCheckout(double finalPayable) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (cart.items.isEmpty) return;

    if (auth.user == null) {
      _showSnack("Please log in to place an order", isError: true);
      return;
    }

    if (auth.user!.walletBalance < finalPayable) {
      _showSnack(
        "Insufficient tokens! Balance: ₹${auth.user!.walletBalance.toStringAsFixed(2)}, Required: ₹${finalPayable.toStringAsFixed(2)}",
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      "canteen_id": cart.canteenId,
      "order_type": "IMMEDIATE",
      "items": cart.items.map((i) => {
        "menu_item_id": i.menuItemId,
        "quantity": i.quantity,
      }).toList(),
    };

    try {
      final res = await ApiClient.post("/orders", body: payload);
      if (res.statusCode == 201) {
        final orderData = jsonDecode(res.body);
        final remainingBal = (orderData["wallet_balance_remaining"] as num?)?.toDouble();
        if (remainingBal != null) {
          auth.updateWalletBalance(remainingBal);
        }

        cart.clear();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                orderId: orderData["id"] as int,
                wsClient: widget.wsClient,
                onBackToHome: () {
                  Navigator.pop(context);
                  widget.onNavigateHome?.call();
                },
              ),
            ),
          );
        }
      } else {
        final err = jsonDecode(res.body);
        _showSnack(err["detail"] ?? "Order failed", isError: true);
      }
    } catch (e) {
      _showSnack("Network error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _confirmClearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Clear Cart?",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          "Are you sure you want to remove all items from your order cart?",
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<CartProvider>(context, listen: false).clear();
              _removePromo();
            },
            child: Text("Clear All", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _getFoodImage(String name, String? imgUrl) {
    if (imgUrl != null && imgUrl.isNotEmpty && (imgUrl.startsWith("http://") || imgUrl.startsWith("https://"))) {
      return imgUrl;
    }
    final lower = name.toLowerCase();
    if (lower.contains("pizza")) {
      return "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80";
    } else if (lower.contains("burger")) {
      return "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80";
    } else if (lower.contains("taco")) {
      return "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=400&q=80";
    } else if (lower.contains("sandwich") || lower.contains("toast")) {
      return "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=400&q=80";
    } else if (lower.contains("chicken") || lower.contains("grill")) {
      return "https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=400&q=80";
    } else if (lower.contains("pasta") || lower.contains("noodle")) {
      return "https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=400&q=80";
    } else if (lower.contains("salad") || lower.contains("bowl") || lower.contains("rice")) {
      return "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&q=80";
    } else if (lower.contains("combo") || lower.contains("meal")) {
      return "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400&q=80";
    } else if (lower.contains("coffee") || lower.contains("tea") || lower.contains("shake") || lower.contains("drink")) {
      return "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=400&q=80";
    }
    return "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&q=80";
  }

  String _getFoodSubtitle(CartItem item) {
    if (item.description != null && item.description!.trim().isNotEmpty) {
      return item.description!.trim();
    }
    final lower = item.name.toLowerCase();
    if (lower.contains("chicken") || lower.contains("grill")) {
      return "Served with fresh veggies and dip";
    } else if (lower.contains("taco")) {
      return "Crisp taco shell, seasoned fill, cheddar";
    } else if (lower.contains("combo") || lower.contains("meal")) {
      return "Warm side fries, house dip & drink";
    } else if (lower.contains("burger")) {
      return "Toasted brioche bun with creamy sauce";
    } else if (lower.contains("pizza")) {
      return "Stone-baked crust with loaded mozzarella";
    } else if (lower.contains("sandwich")) {
      return "Multigrain bread toasted with herb spread";
    }
    return "Freshly prepared • Campus kitchen special";
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    final subtotal = cart.totalAmount;
    final payable = (subtotal - _discountAmount).clamp(0.0, double.infinity);
    final userBalance = auth.user?.walletBalance ?? 0.0;
    final hasEnoughBalance = userBalance >= payable;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back / Return Button
                  GestureDetector(
                    onTap: () {
                      if (widget.onNavigateHome != null) {
                        widget.onNavigateHome!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),

                  // Center Title
                  Text(
                    "Cart",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),

                  // More / Clear Action Button
                  if (cart.items.isNotEmpty)
                    GestureDetector(
                      onTap: _confirmClearCart,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 42),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: cart.items.isEmpty
                  ? _buildEmptyCart(context)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        const SizedBox(height: 8),

                        // Cart Items List
                        ...cart.items.map((item) => _buildCartItemCard(cart, item)),

                        const SizedBox(height: 18),

                        // Promo Code Pill
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildPromoSection(subtotal),
                        ),

                        const SizedBox(height: 20),

                        // Order Summary Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildOrderSummary(subtotal, payable, userBalance, hasEnoughBalance),
                        ),

                        const SizedBox(height: 24),

                        // Checkout Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildCheckoutButton(payable, hasEnoughBalance),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(CartProvider cart, CartItem item) {
    final foodImg = _getFoodImage(item.name, item.imageUrl);
    final subtitle = _getFoodSubtitle(item);

    return Dismissible(
      key: ValueKey("cart_item_${item.menuItemId}"),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (_) {
        cart.removeItem(item.menuItemId);
        _showSnack("Removed ${item.name} from cart");
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Dish Thumbnail Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Image.network(
                  foodImg,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFFFF7ED),
                    child: const Center(
                      child: Icon(Icons.lunch_dining_rounded, color: Color(0xFFEA580C), size: 32),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${item.price.toStringAsFixed(2)}",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ),

            // Right Actions: Option & Quantity Pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick menu / remove
                GestureDetector(
                  onTap: () {
                    cart.removeItem(item.menuItemId);
                    _showSnack("Removed ${item.name} from cart");
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 12, right: 4),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ),
                ),

                // Modern Quantity Pill: [-  Qty  (+)]
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minus Button
                      InkWell(
                        onTap: () => cart.removeOrDecrementItem(item.menuItemId),
                        borderRadius: BorderRadius.circular(14),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),

                      // Quantity Text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          "${item.quantity}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),

                      // Filled Black Plus Circle Button
                      GestureDetector(
                        onTap: () {
                          cart.addItem(
                            cart.canteenId!,
                            item.menuItemId,
                            item.name,
                            item.price,
                            item.availableStock,
                            imageUrl: item.imageUrl,
                            description: item.description,
                          );
                        },
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoSection(double subtotal) {
    if (_appliedPromoCode != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$_appliedPromoCode applied (-₹${_discountAmount.toStringAsFixed(2)})",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: const Color(0xFF065F46),
                ),
              ),
            ),
            GestureDetector(
              onTap: _removePromo,
              child: const Icon(Icons.close_rounded, color: Color(0xFF065F46), size: 18),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 18, right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _promoController,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: "Promo code",
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: () => _applyPromoCode(subtotal),
            child: Text(
              "Apply",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(double subtotal, double payable, double userBalance, bool hasEnoughBalance) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Order Summary",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          // Subtotal
          _summaryRow("Subtotal", "₹${subtotal.toStringAsFixed(2)}"),
          const SizedBox(height: 8),

          // Delivery/Handling
          _summaryRow("Delivery/Packaging", "Free", isFree: true),
          const SizedBox(height: 8),

          // Promo Discount
          if (_discountAmount > 0) ...[
            _summaryRow("Promo Discount", "-₹${_discountAmount.toStringAsFixed(2)}", isGreen: true),
            const SizedBox(height: 8),
          ],

          const Divider(color: Color(0xFFF1F5F9), thickness: 1.2, height: 18),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                "₹${payable.toStringAsFixed(2)}",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Wallet Balance Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: hasEnoughBalance ? const Color(0xFFF8FAFC) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasEnoughBalance ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 17,
                  color: hasEnoughBalance ? const Color(0xFFEA580C) : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasEnoughBalance
                        ? "Wallet Balance: ₹${userBalance.toStringAsFixed(2)}"
                        : "Low Balance (₹${userBalance.toStringAsFixed(2)}) - Needs ₹${(payable - userBalance).toStringAsFixed(2)} more",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: hasEnoughBalance ? const Color(0xFF475569) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String val, {bool isFree = false, bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          val,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isFree
                ? const Color(0xFF10B981)
                : isGreen
                    ? const Color(0xFF10B981)
                    : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutButton(double payable, bool hasEnoughBalance) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        onPressed: _isSubmitting ? null : () => _handleCheckout(payable),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
              )
            : Text(
                "Checkout",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFEDD5), width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 48,
                  color: Color(0xFFEA580C),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Your cart is empty",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Looks like you haven't added anything to your cart yet. Explore food outlets to discover delicious meals!",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              onPressed: () {
                if (widget.onNavigateHome != null) {
                  widget.onNavigateHome!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: Text(
                "Explore Menu",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
