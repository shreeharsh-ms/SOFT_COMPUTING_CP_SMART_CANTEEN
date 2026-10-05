import "dart:convert";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";
import "../../core/services/api_client.dart";
import "../../providers/auth_provider.dart";

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0.0;
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  bool _isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get("/wallet");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _balance = (data["balance"] as num).toDouble();
          _transactions = data["recent_transactions"] as List<dynamic>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load wallet: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTopUpDialog() {
    final amountController = TextEditingController(text: "100");
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Top Up Campus Tokens",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add tokens to your digital campus wallet instantly via UPI or NetBanking.",
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Token Amount (₹)",
                  prefixText: "₹ ",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amt <= 0) return;
                Navigator.pop(ctx);
                await _executeTopUp(amt);
              },
              child: const Text("Add Tokens"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeTopUp(double amount) async {
    try {
      final res = await ApiClient.post(
        "/wallet/recharge",
        body: {"token_amount": amount, "payment_method": "Campus UPI"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _balance = (data["balance"] as num).toDouble();
          _transactions = data["recent_transactions"] as List<dynamic>;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Successfully added ₹${amount.toStringAsFixed(0)} to your wallet!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Recharge failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final userName = user?.name ?? "Student";

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
            : RefreshIndicator(
                color: const Color(0xFFEA580C),
                onRefresh: _fetchWallet,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Top Bar: Avatar + "Hello, {Name}" + Notification Bell
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFEA580C), width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFEA580C),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Hello,",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    userName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A), size: 20),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // 2. High-Impact Gradient Card (Orange & White Theme)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.38),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Balance",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _isBalanceVisible ? "₹${_balance.toStringAsFixed(2)}" : "₹ ••••••",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                                  child: Icon(
                                    _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 22),

                            // 4 Action Buttons Pill Row (Transfer, Receive, Top up, More)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildGradientActionItem(
                                  icon: Icons.send_rounded,
                                  label: "Transfer",
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Peer-to-peer campus token transfer available at canteen counters")),
                                    );
                                  },
                                ),
                                _buildGradientActionItem(
                                  icon: Icons.call_received_rounded,
                                  label: "Receive",
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Receive QR code active for token credit")),
                                    );
                                  },
                                ),
                                _buildGradientActionItem(
                                  icon: Icons.add_circle_outline_rounded,
                                  label: "Top up",
                                  onTap: _showTopUpDialog,
                                ),
                                _buildGradientActionItem(
                                  icon: Icons.grid_view_rounded,
                                  label: "More",
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 3. "My Pockets" / Campus Budgets Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "My Pockets",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            "See All",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Two Pockets Cards Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildPocketCard(
                              emoji: "🍱",
                              title: "Meals Plan",
                              isLocked: true,
                              target: "₹2,500",
                              progress: 0.69,
                              percentText: "69%",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPocketCard(
                              emoji: "☕",
                              title: "Snacks & Cafe",
                              isLocked: false,
                              target: "₹1,200",
                              progress: 0.45,
                              percentText: "45%",
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      // 4. "Recent Transactions" Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Recent Transactions",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            "See All",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Transactions List
                      if (_transactions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 44, color: Color(0xFFCBD5E1)),
                              const SizedBox(height: 8),
                              Text(
                                "No transactions yet",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Campus food payments will record here.",
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _transactions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final tx = _transactions[idx];
                            final type = (tx["transaction_type"] as String?) ?? "DEBIT";
                            final isCredit = type == "CREDIT" || type == "REFUND";
                            final amt = (tx["amount"] as num).toDouble();
                            final desc = (tx["description"] as String?) ?? "Canteen Purchase";
                            final dt = DateTime.tryParse(tx["created_at"] as String? ?? "") ?? DateTime.now();
                            final dateStr = DateFormat("dd MMM, h:mm a").format(dt.toLocal());

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Icon / Brand pill
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isCredit ? Icons.arrow_downward_rounded : Icons.fastfood_rounded,
                                        color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          desc,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          dateStr,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "${isCredit ? '+' : '-'}₹${amt.toStringAsFixed(0)}",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
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
      ),
    );
  }

  Widget _buildGradientActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPocketCard({
    required String emoji,
    required String title,
    required bool isLocked,
    required String target,
    required double progress,
    required String percentText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              if (isLocked)
                const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your Target",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
            ),
          ),
          Text(
            target,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: const Color(0xFF16A34A),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                percentText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
