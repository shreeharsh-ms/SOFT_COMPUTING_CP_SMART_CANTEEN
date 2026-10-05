import "dart:async";
import "dart:convert";
import "package:flutter/material.dart";
import "package:qr_flutter/qr_flutter.dart";
import "../../core/services/api_client.dart";
import "../../core/services/websocket_client.dart";
import "invoice_screen.dart";

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final WebSocketClient wsClient;
  final VoidCallback? onBackToHome;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.wsClient,
    this.onBackToHome,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    _listenWebSockets();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _listenWebSockets() {
    _wsSubscription = widget.wsClient.messages.listen((msg) {
      if ((msg["type"] == "ORDER_STATUS_UPDATE" ||
           msg["type"] == "ORDER_REFUNDED" ||
           msg["type"] == "ORDER_CANCELLED") &&
          msg["order_id"] == widget.orderId) {
        _fetchDetail();
      }
    });
  }

  Future<void> _fetchDetail() async {
    try {
      final res = await ApiClient.get("/orders/${widget.orderId}");
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _order = jsonDecode(res.body) as Map<String, dynamic>;
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

  Color _getStatusColor(String status) {
    switch (status) {
      case "PLACED":
        return Colors.blueGrey;
      case "CONFIRMED":
        return Colors.blue;
      case "PREPARING":
        return Colors.amber.shade800;
      case "READY":
        return Colors.green;
      case "COMPLETED":
        return Colors.teal;
      case "CANCELLED":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Order Detail")),
        body: const Center(child: Text("Order not found or inaccessible")),
      );
    }

    final token = _order!["digital_token"] as String? ?? "N/A";
    final status = _order!["status"] as String? ?? "UNKNOWN";
    final items = _order!["items"] as List<dynamic>? ?? [];
    final statusColor = _getStatusColor(status);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onBackToHome != null) {
              widget.onBackToHome!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushNamedAndRemoveUntil(context, "/home", (r) => false);
            }
          },
        ),
        title: Text(
          "Order #${_order!["order_number"]}",
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text("Digital Pickup Token", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      token,
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: token,
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Status: $status",
                        style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Order Summary", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const Divider(),
                    ...items.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${i["quantity"]}x ${i["item_name"]}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text("\$${(i["unit_price"] * i["quantity"]).toStringAsFixed(2)}"),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Paid (incl. GST):", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("\$${_order!["total_amount"]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange,
                          side: const BorderSide(color: Colors.deepOrange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.receipt),
                        label: const Text("View GST Tax Invoice"),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InvoiceScreen(orderId: widget.orderId),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
