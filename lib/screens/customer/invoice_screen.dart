import "dart:convert";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../core/services/api_client.dart";
import "../../core/utils/download_helper.dart";

class InvoiceScreen extends StatefulWidget {
  final int orderId;
  const InvoiceScreen({super.key, required this.orderId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  Map<String, dynamic>? _invoice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInvoice();
  }

  Future<void> _fetchInvoice() async {
    try {
      final res = await ApiClient.get("/orders/${widget.orderId}/invoice");
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _invoice = jsonDecode(res.body) as Map<String, dynamic>;
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

  void _printInvoice() {
    printReceipt();
  }

  void _downloadInvoice() {
    if (_invoice == null) return;
    final invNum = _invoice!["invoice_number"] as String? ?? "INV-${widget.orderId}";
    final cleanName = invNum.replaceAll(RegExp(r"[^\w\-]"), "_");
    final items = _invoice!["line_items"] as List<dynamic>? ?? [];
    final dtStr = _invoice!["invoice_date"] as String?;
    final dateFormatted = dtStr != null
        ? DateFormat("dd MMM yyyy, hh:mm a").format(DateTime.parse(dtStr).toLocal())
        : "N/A";

    final itemsRows = items.map((it) => """
      <tr>
        <td><strong>${it["item_name"]}</strong><br><small style="color: #64748b;">SAC: ${it["hsn_sac_code"]} @ ${it["gst_rate_percent"]}%</small></td>
        <td class="text-center">${it["quantity"]}</td>
        <td class="text-right">\$${it["taxable_value"]}</td>
        <td class="text-right"><strong>\$${it["line_total"]}</strong></td>
      </tr>
    """).join("\n");

    final htmlContent = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>GST Tax Invoice - $invNum</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; margin: 0; padding: 24px; color: #0f172a; }
    .invoice-box { max-width: 650px; margin: auto; padding: 30px; border: 1px solid #e2e8f0; background: #ffffff; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
    .header { text-align: center; border-bottom: 2px solid #e2e8f0; padding-bottom: 16px; margin-bottom: 20px; }
    .header h1 { margin: 0; font-size: 20px; color: #0f172a; }
    .header .gstin { color: #ea580c; font-weight: bold; margin: 4px 0; font-size: 14px; }
    .header .address { color: #64748b; font-size: 12px; margin: 0; }
    .badge { font-size: 11px; font-weight: bold; color: #475569; letter-spacing: 1px; margin-top: 10px; display: inline-block; }
    .meta-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px 16px; margin-bottom: 20px; }
    .meta-row { display: flex; justify-content: space-between; margin: 4px 0; font-size: 13px; }
    .meta-label { color: #64748b; }
    .meta-val { font-weight: 600; color: #0f172a; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; font-size: 13px; }
    th { background: #f1f5f9; padding: 10px; text-align: left; font-weight: bold; color: #334155; }
    td { padding: 10px; border-bottom: 1px solid #f1f5f9; }
    .text-right { text-align: right; }
    .text-center { text-align: center; }
    .summary-box { background: #f8fafc; border-radius: 8px; padding: 14px; margin-bottom: 20px; }
    .summary-row { display: flex; justify-content: space-between; margin: 5px 0; font-size: 13px; color: #475569; }
    .grand-total { border-top: 1px solid #cbd5e1; padding-top: 8px; font-size: 16px; font-weight: bold; color: #ea580c; }
    .footer { text-align: center; font-size: 11px; color: #94a3b8; font-style: italic; margin-top: 24px; }
    .print-btn { display: block; margin: 0 auto 20px auto; background: #ea580c; color: #fff; border: none; padding: 10px 20px; font-size: 14px; font-weight: bold; border-radius: 6px; cursor: pointer; }
    @media print { .print-btn { display: none; } body { background: #fff; padding: 0; } .invoice-box { box-shadow: none; border: none; padding: 0; } }
  </style>
</head>
<body>
  <button class="print-btn" onclick="window.print()">🖨️ Print / Save as PDF</button>
  <div class="invoice-box">
    <div class="header">
      <h1>${_invoice!["seller_legal_name"] ?? _invoice!["seller_name"]}</h1>
      <div class="gstin">GSTIN: ${_invoice!["seller_gstin"] ?? "NOT REGISTERED"}</div>
      <p class="address">${_invoice!["seller_address"] ?? ""}</p>
      <div class="badge">TAX INVOICE (RULE 46 OF CGST RULES)</div>
    </div>
    <div class="meta-box">
      <div class="meta-row"><span class="meta-label">Invoice No:</span><span class="meta-val">$invNum</span></div>
      <div class="meta-row"><span class="meta-label">Order Ref:</span><span class="meta-val">${_invoice!["order_number"]}</span></div>
      <div class="meta-row"><span class="meta-label">Date:</span><span class="meta-val">$dateFormatted</span></div>
      <div class="meta-row"><span class="meta-label">Billed To:</span><span class="meta-val">${_invoice!["buyer_name"]}</span></div>
      <div class="meta-row"><span class="meta-label">Payment Mode:</span><span class="meta-val" style="color: #16a34a;">Digital Campus Wallet</span></div>
    </div>
    <table>
      <thead>
        <tr>
          <th>Item (SAC)</th>
          <th class="text-center">Qty</th>
          <th class="text-right">Taxable</th>
          <th class="text-right">Total</th>
        </tr>
      </thead>
      <tbody>
        $itemsRows
      </tbody>
    </table>
    <div class="summary-box">
      <div class="summary-row"><span>Total Net Taxable Value:</span><strong>\$${_invoice!["subtotal_taxable_value"]}</strong></div>
      <div class="summary-row"><span>CGST:</span><span>\$${_invoice!["total_cgst"]}</span></div>
      <div class="summary-row"><span>SGST:</span><span>\$${_invoice!["total_sgst"]}</span></div>
      <div class="summary-row"><span>Total Tax Component:</span><strong>\$${_invoice!["total_tax"]}</strong></div>
      <div class="summary-row grand-total"><span>Grand Total Paid:</span><span>\$${_invoice!["grand_total"]}</span></div>
    </div>
    <div class="footer">
      All food prices displayed are inclusive of GST.<br>
      This is a computer-generated tax invoice and requires no physical signature.
    </div>
  </div>
</body>
</html>""";

    downloadFile("Receipt_$cleanName.html", htmlContent);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16A34A),
        content: Text("Tax Receipt downloaded as Receipt_$cleanName.html"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Tax Invoice")),
        body: const Center(child: Text("Tax invoice unavailable for this order")),
      );
    }

    final items = _invoice!["line_items"] as List<dynamic>? ?? [];
    final dtStr = _invoice!["invoice_date"] as String?;
    final dateFormatted = dtStr != null
        ? DateFormat("dd MMM yyyy, hh:mm a").format(DateTime.parse(dtStr).toLocal())
        : "N/A";

    return Scaffold(
      appBar: AppBar(
        title: const Text("GST Tax Invoice"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: "Download Receipt",
            onPressed: _downloadInvoice,
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: "Print / Save PDF",
            onPressed: _printInvoice,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller Header
                Center(
                  child: Column(
                    children: [
                      Text(
                        _invoice!["seller_legal_name"] ?? _invoice!["seller_name"],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "GSTIN: ${_invoice!["seller_gstin"] ?? "NOT REGISTERED"}",
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepOrange),
                      ),
                      if (_invoice!["seller_address"] != null)
                        Text(
                          _invoice!["seller_address"],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        "TAX INVOICE (RULE 46 OF CGST RULES)",
                        style: TextStyle(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24, thickness: 1.5),

                // Invoice Metadata Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Invoice No: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                          Expanded(
                            child: Text(
                              "${_invoice!["invoice_number"]}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Order Ref: ", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Expanded(
                            child: Text(
                              "${_invoice!["order_number"]}",
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 12, color: Color(0xFFE2E8F0)),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text("Date: $dateFormatted", style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          const Text("Mode: Digital Wallet", style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text("Billed To: ${_invoice!["buyer_name"]}", style: const TextStyle(fontWeight: FontWeight.w500)),
                const Divider(height: 24),

                // Line Items Table Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text("Item (SAC)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 1, child: Text("Qty", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text("Taxable", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text("Total", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Line Items
                ...items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it["item_name"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text("SAC: ${it["hsn_sac_code"]} @ ${it["gst_rate_percent"]}%", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text("${it["quantity"]}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text("\$${it["taxable_value"]}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text("\$${it["line_total"]}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 12, color: Color(0xFFEEEEEE)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),

                // Tax Breakdown Summary
                Builder(
                  builder: (context) {
                    final effectiveRate = (items.isNotEmpty && items.first["gst_rate_percent"] != null)
                        ? (items.first["gst_rate_percent"] as num).toDouble()
                        : 5.0;
                    final halfRate = (effectiveRate / 2).toStringAsFixed(1);
                    final totalRateStr = effectiveRate.toStringAsFixed(1);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(child: Text("Total Net Taxable Value:", style: TextStyle(fontSize: 13))),
                              Text("\$${_invoice!["subtotal_taxable_value"]}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text("CGST ($halfRate%):", style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
                              Text("\$${_invoice!["total_cgst"]}", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text("SGST ($halfRate%):", style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
                              Text("\$${_invoice!["total_sgst"]}", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                            ],
                          ),
                          if ((_invoice!["total_igst"] as num?)?.toDouble() != 0.0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text("IGST ($totalRateStr%):", style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
                                Text("\$${_invoice!["total_igst"]}", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(child: Text("Total Tax Component:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                              Text("\$${_invoice!["total_tax"]}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(child: Text("Grand Total Paid:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                              Text(
                                "\$${_invoice!["grand_total"]}",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                              ),
                            ],
                          ),
                    ],
                  ),
                );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFEA580C)),
                          foregroundColor: const Color(0xFFEA580C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text("Print / PDF"),
                        onPressed: _printInvoice,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text("Download"),
                        onPressed: _downloadInvoice,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    "All food prices displayed are inclusive of GST.\nThis is a computer generated invoice and requires no physical signature.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
