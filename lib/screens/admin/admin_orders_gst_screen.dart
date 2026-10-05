import "dart:convert";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../core/services/api_client.dart";
import "../../core/utils/download_helper.dart";
import "../customer/invoice_screen.dart";

class AdminOrdersGstScreen extends StatefulWidget {
  final int? initialCanteenId;
  const AdminOrdersGstScreen({super.key, this.initialCanteenId});

  @override
  State<AdminOrdersGstScreen> createState() => _AdminOrdersGstScreenState();
}

class _AdminOrdersGstScreenState extends State<AdminOrdersGstScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
  Map<String, dynamic> _summary = {};
  List<dynamic> _orders = [];
  String _selectedStatus = "ALL";

  @override
  void initState() {
    super.initState();
    _fetchLedger();
  }

  Future<void> _fetchLedger() async {
    setState(() => _isLoading = true);
    try {
      String query = "/admin/orders-ledger";
      final params = <String>[];
      if (widget.initialCanteenId != null) {
        params.add("canteen_id=${widget.initialCanteenId}");
      }
      if (_selectedStatus != "ALL") {
        params.add("order_status=$_selectedStatus");
      }
      if (params.isNotEmpty) {
        query += "?${params.join("&")}";
      }

      final res = await ApiClient.get(query);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _summary = data["summary"] as Map<String, dynamic>? ?? {};
          _orders = data["orders"] as List<dynamic>? ?? [];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text("Failed to load ledger: ${res.body}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Network error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      String query = "/admin/orders-ledger/export-csv";
      if (widget.initialCanteenId != null) {
        query += "?canteen_id=${widget.initialCanteenId}";
      }
      final res = await ApiClient.get(query);
      if (res.statusCode == 200) {
        final nowStr = DateFormat("yyyyMMdd_HHmm").format(DateTime.now());
        final filename = "GST_Tax_Audit_Report_$nowStr.csv";
        downloadFile(filename, res.body, mimeType: "text/csv");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text("Statutory GST Audit Report exported as $filename"),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.red, content: Text("Failed to generate CSV export")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Export failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "COMPLETED":
        return const Color(0xFF10B981);
      case "READY":
        return const Color(0xFF059669);
      case "PREPARING":
        return const Color(0xFFEA580C);
      case "CONFIRMED":
        return const Color(0xFF2563EB);
      case "PLACED":
        return const Color(0xFF64748B);
      case "CANCELLED":
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("GST Audit & Orders Ledger"),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.file_download_outlined),
            tooltip: "Export GSTR-1 CSV",
            onPressed: _isExporting ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Refresh Ledger",
            onPressed: _fetchLedger,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : RefreshIndicator(
              onRefresh: _fetchLedger,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Executive GST KPI Cards
                    _buildGstSummaryBanner(),

                    const SizedBox(height: 20),

                    // Filter and Export Toolbar
                    _buildToolbar(),

                    const SizedBox(height: 16),

                    // Orders List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Tax Invoices & Orders (${_orders.length})",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          "FY 2026-27 Compliant",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_orders.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text("No orders match the selected criteria", style: TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _orders.length,
                        itemBuilder: (context, idx) {
                          final o = _orders[idx];
                          return _buildOrderCard(o);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGstSummaryBanner() {
    final gross = _summary["gross_turnover"] ?? 0.0;
    final taxable = _summary["total_taxable_value"] ?? 0.0;
    final cgst = _summary["total_cgst"] ?? 0.0;
    final sgst = _summary["total_sgst"] ?? 0.0;
    final totalTax = _summary["total_tax_collected"] ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Statutory GST & Turnover Ledger",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text("Rule 46 CGST", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildKpiItem("Gross Sales Turnover", "\$$gross", Colors.white),
              _buildKpiItem("Net Taxable Value", "\$$taxable", const Color(0xFFCBD5E1)),
              _buildKpiItem("CGST (2.5%)", "\$$cgst", const Color(0xFF93C5FD)),
              _buildKpiItem("SGST (2.5%)", "\$$sgst", const Color(0xFF93C5FD)),
              _buildKpiItem("Total GST Collected", "\$$totalTax", const Color(0xFF4ADE80)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, String val, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(val, style: TextStyle(color: valColor, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Status Filter Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              icon: const Icon(Icons.filter_list_rounded, size: 18),
              items: const [
                DropdownMenuItem(value: "ALL", child: Text("All Statuses", style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: "COMPLETED", child: Text("Completed", style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: "READY", child: Text("Ready", style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: "PREPARING", child: Text("Preparing", style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: "PLACED", child: Text("Placed", style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: "CANCELLED", child: Text("Cancelled", style: TextStyle(fontSize: 13))),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedStatus = v);
                  _fetchLedger();
                }
              },
            ),
          ),
        ),

        // Export CSV Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.table_view_rounded, size: 17),
          label: const Text("Export GSTR-1 CSV", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          onPressed: _isExporting ? null : _exportCsv,
        ),
      ],
    );
  }

  Widget _buildOrderCard(dynamic o) {
    final status = o["status"] as String? ?? "PLACED";
    final statusColor = _getStatusColor(status);
    final invNum = o["invoice_number"] as String? ?? "N/A";
    final orderNum = o["order_number"] as String? ?? "N/A";
    final canteenName = o["canteen_name"] as String? ?? "Canteen";
    final buyerName = o["buyer_name"] as String? ?? "Student";
    final buyerMobile = o["buyer_mobile"] as String? ?? "N/A";
    final total = (o["total_amount"] as num?)?.toDouble() ?? 0.0;
    final taxable = (o["subtotal_taxable_value"] as num?)?.toDouble() ?? 0.0;
    final cgst = (o["total_cgst"] as num?)?.toDouble() ?? 0.0;
    final sgst = (o["total_sgst"] as num?)?.toDouble() ?? 0.0;
    final totalTax = (o["total_tax"] as num?)?.toDouble() ?? 0.0;
    final orderId = o["id"] as int;
    final items = o["items"] as List<dynamic>? ?? [];

    String dateStr = "N/A";
    if (o["created_at"] != null && (o["created_at"] as String).isNotEmpty) {
      try {
        dateStr = DateFormat("dd MMM yyyy, hh:mm a").format(DateTime.parse(o["created_at"]).toLocal());
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Invoice Number & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_outlined, size: 18, color: Color(0xFF0F172A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          invNum,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text("Order: #$orderNum", style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                Text("• $canteenName", style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                Text("• $dateStr", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Billed To: $buyerName (Mobile: $buyerMobile)",
              style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const Divider(height: 16),

            // Line items breakdown
            Text(
              items.map((it) => "${it["quantity"]}x ${it["item_name"]} (SAC: ${it["hsn_sac_code"]})").join(", "),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
            ),
            const SizedBox(height: 8),

            // Tax Breakdown Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  Text("Taxable: \$$taxable", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  Text("CGST: \$$cgst", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text("SGST: \$$sgst", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text("Total GST: \$$totalTax", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  Text("Grand Total: \$$total", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Button
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 15),
                label: const Text("View & Download Invoice", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceScreen(orderId: orderId),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
