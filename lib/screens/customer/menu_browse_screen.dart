import "dart:convert";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";
import "../../core/services/api_client.dart";
import "../../core/services/websocket_client.dart";
import "../../providers/auth_provider.dart";
import "../../providers/cart_provider.dart";
import "cart_checkout_screen.dart";

class MenuBrowseScreen extends StatefulWidget {
  final int canteenId;
  final String canteenName;
  final WebSocketClient wsClient;
  final VoidCallback? onBackToCanteens;
  final VoidCallback? onNavigateToCart;

  const MenuBrowseScreen({
    super.key,
    required this.canteenId,
    required this.canteenName,
    required this.wsClient,
    this.onBackToCanteens,
    this.onNavigateToCart,
  });

  @override
  State<MenuBrowseScreen> createState() => _MenuBrowseScreenState();
}

class _MenuBrowseScreenState extends State<MenuBrowseScreen> {
  List<dynamic> _allItems = [];
  bool _isLoading = true;
  bool _vegOnly = false;
  String _searchQuery = "";
  String? _selectedCategoryFilter;

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _visualCategories = [
    {
      "name": "Biryani",
      "image": "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=300&auto=format&fit=crop&q=60",
    },
    {
      "name": "Meals",
      "image": "https://images.unsplash.com/photo-1610192244261-3f33de3f55e4?w=300&auto=format&fit=crop&q=60",
    },
    {
      "name": "Rice",
      "image": "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=300&auto=format&fit=crop&q=60",
    },
    {
      "name": "Tandoori",
      "image": "https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=300&auto=format&fit=crop&q=60",
    },
    {
      "name": "Quick Snacks",
      "image": "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=300&auto=format&fit=crop&q=60",
    },
    {
      "name": "Beverages",
      "image": "https://images.unsplash.com/photo-1517701604599-bb29b565090c?w=300&auto=format&fit=crop&q=60",
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get("/canteens/${widget.canteenId}/menu", requiresAuth: false);
      if (res.statusCode == 200) {
        final cats = jsonDecode(res.body) as List<dynamic>;
        final List<dynamic> flatItems = [];
        for (final cat in cats) {
          final items = cat["items"] as List<dynamic>? ?? [];
          for (final it in items) {
            it["category_name"] = cat["name"];
            flatItems.add(it);
          }
        }
        setState(() {
          _allItems = flatItems;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load menu: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _resolveFoodImage(String name, String? imgUrl) {
    if (imgUrl != null && imgUrl.trim().isNotEmpty && (imgUrl.startsWith("http://") || imgUrl.startsWith("https://"))) {
      return imgUrl.trim();
    }
    final lower = name.toLowerCase();
    if (lower.contains("sandwich") || lower.contains("toast") || lower.contains("cheese")) {
      return "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80";
    } else if (lower.contains("coffee") || lower.contains("tea") || lower.contains("latte")) {
      return "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=600&auto=format&fit=crop&q=80";
    } else if (lower.contains("biryani") || lower.contains("rice")) {
      return "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop&q=80";
    } else if (lower.contains("burger")) {
      return "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80";
    } else if (lower.contains("pizza")) {
      return "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80";
    } else if (lower.contains("thali") || lower.contains("meal")) {
      return "https://images.unsplash.com/photo-1610192244261-3f33de3f55e4?w=600&auto=format&fit=crop&q=80";
    } else if (lower.contains("chicken") || lower.contains("tandoori") || lower.contains("murgh")) {
      return "https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=600&auto=format&fit=crop&q=80";
    } else if (lower.contains("dal") || lower.contains("curry")) {
      return "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=600&auto=format&fit=crop&q=80";
    }
    return "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80";
  }

  List<dynamic> _getFilteredItems() {
    return _allItems.where((item) {
      final name = (item["name"] as String? ?? "").toLowerCase();
      final desc = (item["description"] as String? ?? "").toLowerCase();
      final cat = (item["category_name"] as String? ?? "").toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase()) ||
          cat.contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategoryFilter == null ||
          cat == _selectedCategoryFilter!.toLowerCase();

      final isVeg = desc.contains("veg") ||
          desc.contains("paneer") ||
          desc.contains("cheese") ||
          desc.contains("thali") ||
          desc.contains("dal") ||
          name.contains("paneer") ||
          name.contains("veg") ||
          name.contains("cheese") ||
          name.contains("coffee") ||
          name.contains("tea");

      final matchesVeg = !_vegOnly || isVeg;

      return matchesQuery && matchesCategory && matchesVeg;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final userName = authProvider.user?.name ?? "Foodie";
    final firstName = userName.split(" ").first;
    final filteredItems = _getFilteredItems();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () {
            if (widget.onBackToCanteens != null) {
              widget.onBackToCanteens!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.canteenName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "Campus Outlet Menu",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: cartProvider.itemCount > 0,
              label: Text("${cartProvider.itemCount}"),
              backgroundColor: const Color(0xFFEA580C),
              child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0F172A)),
            ),
            onPressed: () {
              if (widget.onNavigateToCart != null) {
                widget.onNavigateToCart!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartCheckoutScreen(wsClient: widget.wsClient),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
          : RefreshIndicator(
              color: const Color(0xFFEA580C),
              onRefresh: _loadMenu,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Personalized Greeting
                    Row(
                      children: [
                        const Text("💖", style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          "Start your day with a treat",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEA580C),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        text: "Hey $firstName, ",
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 26,
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.normal,
                        ),
                        children: [
                          TextSpan(
                            text: "we've got you!",
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 26,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Discover authentic flavours prepared fresh at ${widget.canteenName}.",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. Search Bar + Veg Toggle
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Search in ${widget.canteenName}...',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: const Color(0xFF94A3B8),
                                ),
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 22),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = "");
                                        },
                                      )
                                    : const Icon(Icons.mic_rounded, color: Color(0xFFEA580C), size: 20),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => setState(() => _vegOnly = !_vegOnly),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _vegOnly ? const Color(0xFFDCFCE7) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _vegOnly ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "VEG",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _vegOnly ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Icon(
                                  Icons.eco_rounded,
                                  size: 16,
                                  color: _vegOnly ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 3. "What's on your mind?" Category Circle Scroller
                    Row(
                      children: [
                        Container(
                          width: 3.5,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "What's on your mind?",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (_selectedCategoryFilter != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _selectedCategoryFilter = null),
                            child: Text(
                              "Clear filter",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFEA580C),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _visualCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, idx) {
                          final cat = _visualCategories[idx];
                          final catName = cat["name"]!;
                          final isSelected = _selectedCategoryFilter?.toLowerCase() == catName.toLowerCase();

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedCategoryFilter = null;
                                } else {
                                  _selectedCategoryFilter = catName;
                                }
                              });
                            },
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFEA580C) : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      cat["image"]!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFFFED7AA),
                                        child: const Icon(Icons.fastfood, color: Color(0xFFEA580C)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  catName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 4. Promotional Hero Banner: Orange Theme
                    Row(
                      children: [
                        Container(
                          width: 3.5,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Exclusive campus offers",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDBA74).withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            bottom: -20,
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              size: 140,
                              color: const Color(0xFFEA580C).withValues(alpha: 0.07),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEA580C),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "CAMPUS SPECIAL",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Saffron Feast\nThali & Biryani",
                                        style: GoogleFonts.dmSerifDisplay(
                                          fontSize: 20,
                                          color: const Color(0xFF0F172A),
                                          height: 1.15,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFEA580C)),
                                            ),
                                            child: Text(
                                              "ORDER ABOVE ₹199",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFFEA580C),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "GET ₹50 OFF",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFFEA580C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=300&auto=format&fit=crop&q=60",
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 60, color: Color(0xFFEA580C)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 18,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 5. Dishes List
                    Row(
                      children: [
                        Container(
                          width: 3.5,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedCategoryFilter != null ? "$_selectedCategoryFilter Specialities" : "Popular at ${widget.canteenName}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${filteredItems.length} items",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (filteredItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              "No dishes found",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Try clearing the search or category filter.",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
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
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final item = filteredItems[idx];
                          final price = (item["price"] as num).toDouble();
                          final origPrice = item["original_price"] != null ? (item["original_price"] as num).toDouble() : null;
                          final stock = item["stock_quantity"] as int? ?? 10;
                          final isOutOfStock = stock <= 0;
                          final rawImg = item["image_url"] as String?;
                          final imgUrl = _resolveFoodImage(item["name"] as String, rawImg);
                          final itemId = item["id"] as int;

                          final matchingCartItem = cartProvider.items.cast<CartItem?>().firstWhere(
                            (ci) => ci?.menuItemId == itemId,
                            orElse: () => null,
                          );
                          final cartQty = matchingCartItem?.quantity ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 90,
                                    height: 90,
                                    child: Image.network(
                                      imgUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Image.network(
                                        _resolveFoodImage(item["name"] as String, null),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFFFFF7ED),
                                          child: const Icon(Icons.fastfood, color: Color(0xFFEA580C)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item["name"] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item["description"] as String? ?? "",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          color: const Color(0xFF64748B),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            "₹${price.toStringAsFixed(0)}",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (origPrice != null && origPrice > price) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              "₹${origPrice.toStringAsFixed(0)}",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                color: const Color(0xFF94A3B8),
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          if (isOutOfStock)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                "Out of Stock",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            )
                                          else if (cartQty > 0)
                                            Container(
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF7ED),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFEA580C)),
                                              ),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                    icon: const Icon(Icons.remove, size: 16, color: Color(0xFFEA580C)),
                                                    onPressed: () => cartProvider.removeOrDecrementItem(itemId),
                                                  ),
                                                  Text(
                                                    "$cartQty",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                      color: const Color(0xFFEA580C),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                    icon: const Icon(Icons.add, size: 16, color: Color(0xFFEA580C)),
                                                    onPressed: () {
                                                      final ok = cartProvider.addItem(
                                                        widget.canteenId,
                                                        itemId,
                                                        item["name"] as String,
                                                        price,
                                                        stock,
                                                        imageUrl: imgUrl,
                                                        description: item["description"] as String?,
                                                      );
                                                      if (!ok) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text("Cannot add more items or different outlet active")),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFEA580C),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                minimumSize: const Size(60, 32),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                elevation: 0,
                                              ),
                                              onPressed: () {
                                                final ok = cartProvider.addItem(
                                                  widget.canteenId,
                                                  itemId,
                                                  item["name"] as String,
                                                  price,
                                                  stock,
                                                  imageUrl: imgUrl,
                                                  description: item["description"] as String?,
                                                );
                                                if (!ok) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text("Cannot add item or cross-outlet cart conflict")),
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      duration: const Duration(seconds: 1),
                                                      content: Text("Added ${item["name"]} to cart!"),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Text(
                                                "ADD",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
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
