import "dart:convert";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";
import "../../core/services/api_client.dart";
import "../../core/services/websocket_client.dart";
import "../../providers/auth_provider.dart";
import "menu_browse_screen.dart";

class CanteenListScreen extends StatefulWidget {
  final WebSocketClient wsClient;
  final Function(int)? onNavigateTab;
  final void Function(int canteenId, String canteenName)? onSelectCanteen;

  const CanteenListScreen({
    super.key,
    required this.wsClient,
    this.onNavigateTab,
    this.onSelectCanteen,
  });

  @override
  State<CanteenListScreen> createState() => _CanteenListScreenState();
}

class _CanteenListScreenState extends State<CanteenListScreen> {
  List<dynamic> _canteens = [];
  bool _isLoading = true;
  String _searchQuery = "";

  final TextEditingController _searchController = TextEditingController();

  final List<String> _canteenImages = [
    "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&auto=format&fit=crop&q=80",
    "https://images.unsplash.com/photo-1552566626-52f8b828add9?w=600&auto=format&fit=crop&q=80",
  ];

  @override
  void initState() {
    super.initState();
    _fetchCanteens();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCanteens() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get("/canteens", requiresAuth: false);
      if (res.statusCode == 200) {
        setState(() => _canteens = jsonDecode(res.body));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading canteens: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> _getFilteredCanteens() {
    if (_searchQuery.trim().isEmpty) return _canteens;
    final query = _searchQuery.toLowerCase();
    return _canteens.where((c) {
      final name = (c["name"] as String? ?? "").toLowerCase();
      final loc = (c["location"] as String? ?? "").toLowerCase();
      final desc = (c["description"] as String? ?? "").toLowerCase();
      return name.contains(query) || loc.contains(query) || desc.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.name ?? "Foodie";
    final firstName = userName.split(" ").first;
    final filteredCanteens = _getFilteredCanteens();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
            : RefreshIndicator(
                color: const Color(0xFFEA580C),
                onRefresh: _fetchCanteens,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Top Bar: App Title & User Avatar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Campus Outlets",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    "Choose a canteen to order",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : "U",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFEA580C),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 2. Greeting Pill Tag & Header
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
                              text: "where to eat?",
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
                        "Tap any campus outlet below to explore its live menu & offers.",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 3. Search Bar for Outlets
                      Container(
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
                            hintText: 'Search campus canteens or locations...',
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
                                : const Icon(Icons.storefront_rounded, color: Color(0xFFEA580C), size: 20),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 4. Section Title
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
                            "Available Campus Canteens",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${filteredCanteens.length} canteens",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5. Canteen Cards with Online Photography
                      if (filteredCanteens.isEmpty)
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
                              const Icon(Icons.store_mall_directory_outlined, size: 48, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 8),
                              Text(
                                "No canteens found",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Try adjusting your search keywords.",
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
                          itemCount: filteredCanteens.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, idx) {
                            final c = filteredCanteens[idx];
                            final crowd = c["crowd_status"] as Map<String, dynamic>? ?? {};
                            final crowdLevel = (crowd["crowd_level"] as String?) ?? "LOW";
                            final waitMins = crowd["estimated_wait_minutes"] ?? 5;
                            final activeOrders = crowd["active_orders"] ?? 0;
                            final isOpen = c["is_open"] as bool? ?? true;
                            final imgUrl = _canteenImages[idx % _canteenImages.length];

                            Color badgeColor = const Color(0xFF10B981);
                            Color badgeBg = const Color(0xFFECFDF5);
                            if (crowdLevel == "MODERATE") {
                              badgeColor = const Color(0xFFF59E0B);
                              badgeBg = const Color(0xFFFFFBEB);
                            } else if (crowdLevel == "HIGH" || crowdLevel == "PEAK") {
                              badgeColor = const Color(0xFFEF4444);
                              badgeBg = const Color(0xFFFEF2F2);
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    if (widget.onSelectCanteen != null) {
                                      widget.onSelectCanteen!(
                                        c["id"] as int,
                                        c["name"] as String,
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MenuBrowseScreen(
                                            canteenId: c["id"] as int,
                                            canteenName: c["name"] as String,
                                            wsClient: widget.wsClient,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Image with live badges
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                            child: SizedBox(
                                              height: 150,
                                              width: double.infinity,
                                              child: Image.network(
                                                imgUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: const Color(0xFFFED7AA),
                                                  child: const Icon(Icons.storefront, size: 60, color: Color(0xFFEA580C)),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isOpen ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.2),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isOpen ? "OPEN NOW" : "CLOSED",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: badgeBg,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.1),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                "$crowdLevel CROWD",
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: badgeColor,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Canteen info & Action
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    c["name"] as String,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w800,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFF7ED),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: const Color(0xFFFDBA74)),
                                                  ),
                                                  child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFFEA580C)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    c["location"] as String? ?? "Campus",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12.5,
                                                      color: const Color(0xFF64748B),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "~$waitMins mins wait",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    color: const Color(0xFF475569),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                const Icon(Icons.people_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "$activeOrders in queue",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    color: const Color(0xFF475569),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
