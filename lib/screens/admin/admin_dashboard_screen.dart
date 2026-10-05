import "dart:convert";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../core/services/api_client.dart";
import "../../core/services/websocket_client.dart";
import "../../providers/auth_provider.dart";
import "../../providers/cart_provider.dart";
import "admin_menu_management_screen.dart";
import "admin_advisory_wallet_screen.dart";
import "admin_orders_gst_screen.dart";
import "../kitchen/kitchen_monitor_screen.dart";
import "../customer/main_shell.dart";

class AdminDashboardScreen extends StatefulWidget {
  final WebSocketClient wsClient;
  const AdminDashboardScreen({super.key, required this.wsClient});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  int _selectedCanteenId = 1;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get("/admin/dashboard-stats");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _stats = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final user = auth.user;

    final activeOrders = _stats?["active_orders"] ?? 0;
    final totalRevenue = (_stats?["total_revenue"] as num?)?.toDouble() ?? 0.0;
    final totalStudents = _stats?["total_students"] ?? 0;
    final canteens = (_stats?["canteens"] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Admin Portal",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.2),
                  ),
                  Text(
                    "Executive Operations",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: "Refresh Metrics",
            onPressed: _fetchStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22),
            tooltip: "Sign Out",
            onPressed: () async {
              await auth.logout(cart);
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, "/login");
              }
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            )
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Admin Banner Card with Outlet Selector
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white.withValues(alpha: 0.15),
                                child: const Icon(Icons.person, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Welcome, ${user?.name ?? 'Administrator'}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    Text(
                                      "Role: ${user?.role ?? 'ADMIN'} • ID #${user?.id ?? 1}",
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Color(0xFF334155), height: 1),
                          const SizedBox(height: 12),
                          // Outlet Scoping Selector
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Select Canteen Outlet:",
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF334155),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF475569)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF1E293B),
                                    value: _selectedCanteenId,
                                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                    items: canteens.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c["id"] as int,
                                        child: Text(
                                          c["name"] as String,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _selectedCanteenId = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Live Performance Metrics",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          "Auto-Synced",
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 4 Responsive Stat Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 700;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isWide ? 4 : 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: isWide ? 1.7 : 1.25,
                          children: [
                            _buildStatCard(
                              title: "Active Orders",
                              value: "$activeOrders",
                              subtitle: "In kitchen prep",
                              icon: Icons.receipt_long_rounded,
                              iconColor: const Color(0xFFF97316),
                              bgColor: const Color(0xFFFFF7ED),
                            ),
                            _buildStatCard(
                              title: "Total Revenue",
                              value: "\$${totalRevenue.toStringAsFixed(2)}",
                              subtitle: "Gross campus sales",
                              icon: Icons.account_balance_wallet_rounded,
                              iconColor: const Color(0xFF10B981),
                              bgColor: const Color(0xFFECFDF5),
                            ),
                            _buildStatCard(
                              title: "Students",
                              value: "$totalStudents",
                              subtitle: "Registered users",
                              icon: Icons.people_alt_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              bgColor: const Color(0xFFEFF6FF),
                            ),
                            _buildStatCard(
                              title: "Outlets",
                              value: "${canteens.length}",
                              subtitle: "Service kitchens",
                              icon: Icons.store_mall_directory_rounded,
                              iconColor: const Color(0xFF8B5CF6),
                              bgColor: const Color(0xFFF5F3FF),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 28),
                    const Text(
                      "Operations & Station Portals",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Portals Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 700;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isWide ? 2 : 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: isWide ? 2.6 : 3.2,
                          children: [
                            _buildPortalCard(
                              title: "GST Audit & Orders Ledger",
                              subtitle: "Statutory GSTR compliance, tax breakdowns (CGST/SGST), sales audit & CSV export",
                              icon: Icons.receipt_long_rounded,
                              accentColor: const Color(0xFF0D9488),
                              badgeText: "Tax Audit",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminOrdersGstScreen(initialCanteenId: _selectedCanteenId),
                                  ),
                                );
                              },
                            ),
                            _buildPortalCard(
                              title: "Menu & Inventory Management",
                              subtitle: "Full CRUD item catalog, prices, 5% GST, HSN 996331 & stock toggles",
                              icon: Icons.restaurant_menu_rounded,
                              accentColor: const Color(0xFF2563EB),
                              badgeText: "Catalog",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminMenuManagementScreen(canteenId: _selectedCanteenId),
                                  ),
                                );
                              },
                            ),
                            _buildPortalCard(
                              title: "GA Advisory & Surge Intelligence",
                              subtitle: "Soft Computing Genetic Algorithm batch sizing to prevent spoilage & delay",
                              icon: Icons.psychology_rounded,
                              accentColor: const Color(0xFFEA580C),
                              badgeText: "AI Engine",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminAdvisoryWalletScreen(canteenId: _selectedCanteenId),
                                  ),
                                );
                              },
                            ),
                            _buildPortalCard(
                              title: "Counter Cash Deposit Desk",
                              subtitle: "Accept student cash deposits at campus desk and credit tokens instantly",
                              icon: Icons.point_of_sale_rounded,
                              accentColor: const Color(0xFF059669),
                              badgeText: "Finance",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminAdvisoryWalletScreen(canteenId: _selectedCanteenId),
                                  ),
                                );
                              },
                            ),
                            _buildPortalCard(
                              title: "Live Kitchen Monitor Station",
                              subtitle: "Real-time kitchen order queue, stage dispatching & instant refund rejection",
                              icon: Icons.kitchen_rounded,
                              accentColor: const Color(0xFF7C3AED),
                              badgeText: "Station",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => KitchenMonitorScreen(
                                      canteenId: _selectedCanteenId,
                                      wsClient: widget.wsClient,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Canteen Outlets Overview",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 15),
                          label: const Text("Student App View", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MainShell(wsClient: widget.wsClient),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Canteens List
                    ...canteens.map((c) {
                      final isOpen = c["is_open"] as bool? ?? true;
                      final cActive = c["active_orders"] as int? ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.storefront_rounded,
                                color: isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c["name"] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isOpen ? "OPEN" : "CLOSED",
                                          style: TextStyle(
                                            color: isOpen ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Location: ${c["location"]}",
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFEDD5)),
                              ),
                              child: Text(
                                "$cActive In Queue",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortalCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
