import "dart:convert";
import "package:flutter/material.dart";
import "../../core/services/api_client.dart";

class AdminMenuManagementScreen extends StatefulWidget {
  final int canteenId;
  const AdminMenuManagementScreen({super.key, required this.canteenId});

  @override
  State<AdminMenuManagementScreen> createState() => _AdminMenuManagementScreenState();
}

class _AdminMenuManagementScreenState extends State<AdminMenuManagementScreen> {
  List<dynamic> _categories = [];
  List<dynamic> _menuItems = [];
  bool _isLoading = true;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get(
        "/canteens/${widget.canteenId}/menu?include_inactive=$_showInactive",
        requiresAuth: false,
      );
      if (res.statusCode == 200) {
        final List<dynamic> cats = jsonDecode(res.body);
        final List<dynamic> items = [];
        for (var cat in cats) {
          items.addAll(cat["items"] as List<dynamic>);
        }
        setState(() {
          _categories = cats;
          _menuItems = items;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching menu: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getSuggestedImageUrl(String name) {
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

  Future<void> _openItemDialog({Map<String, dynamic>? item}) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: item?["name"] ?? "");
    final descCtrl = TextEditingController(text: item?["description"] ?? "");
    final priceCtrl = TextEditingController(text: item != null ? item["price"].toString() : "");
    final origPriceCtrl = TextEditingController(text: item != null ? item["original_price"].toString() : "");
    final stockCtrl = TextEditingController(text: item != null && item["stock_quantity"] != null ? item["stock_quantity"].toString() : "");
    final prepCtrl = TextEditingController(text: item != null ? item["preparation_time_minutes"].toString() : "10");
    final imgCtrl = TextEditingController(text: item?["image_url"] ?? "");
    final hsnCtrl = TextEditingController(text: item?["hsn_sac_code"] ?? "996331");
    final gstCtrl = TextEditingController(text: item != null && item["gst_rate_percent"] != null ? item["gst_rate_percent"].toString() : "5.00");

    int selectedCatId = item?["category_id"] ?? (_categories.isNotEmpty ? _categories.first["id"] : 1);
    bool isAvailable = item?["is_available"] ?? true;
    bool isRecommended = item?["is_recommended"] ?? false;

    final isEdit = item != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? "Edit Menu Item" : "Create Menu Item"),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedCatId,
                    decoration: const InputDecoration(labelText: "Category"),
                    items: _categories.map((c) {
                      return DropdownMenuItem<int>(
                        value: c["id"] as int,
                        child: Text(c["name"] as String),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedCatId = v!),
                  ),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Item Name"),
                    validator: (v) => (v == null || v.trim().length < 2) ? "Enter valid name" : null,
                  ),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: "Description"),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: "Sale Price (\$, incl. GST)"),
                          validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) < 0) ? "Invalid price" : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: origPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: "Orig. Price (\$)"),
                          validator: (v) => (v != null && v.isNotEmpty && double.tryParse(v) == null) ? "Invalid price" : null,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: hsnCtrl,
                          decoration: const InputDecoration(labelText: "HSN / SAC Code"),
                          validator: (v) => (v == null || v.trim().length < 4) ? "Invalid SAC" : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: gstCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: "GST Rate (%)"),
                          validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) < 0) ? "Invalid %" : null,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Stock (blank: unlimited)"),
                          validator: (v) => (v != null && v.isNotEmpty && int.tryParse(v) == null) ? "Invalid int" : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: prepCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Prep Mins"),
                          validator: (v) => (v == null || int.tryParse(v) == null) ? "Invalid int" : null,
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: imgCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: "Image URL (Direct CDN / Unsplash)",
                      hintText: "https://images.unsplash.com/...",
                      suffixIcon: imgCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                imgCtrl.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (imgCtrl.text.trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: Image.network(
                                imgCtrl.text.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFFEE2E2),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image_rounded, color: Color(0xFFEF4444), size: 20),
                                      Text("Blocked", style: TextStyle(fontSize: 8, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Live Image Preview", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                const SizedBox(height: 2),
                                Text(
                                  "If 'Blocked' shows, host blocks hotlinking (e.g. Cloudflare). Use an open CDN link.",
                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        final autoUrl = _getSuggestedImageUrl(nameCtrl.text.trim());
                        imgCtrl.text = autoUrl;
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFEA580C)),
                      label: const Text(
                        "Auto-Fill Verified HD Food Photo",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEA580C)),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text("Available for Ordering"),
                    value: isAvailable,
                    onChanged: (v) => setDialogState(() => isAvailable = v),
                  ),
                  SwitchListTile(
                    title: const Text("Highlight as Recommended"),
                    value: isRecommended,
                    onChanged: (v) => setDialogState(() => isRecommended = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(isEdit ? "Update" : "Create"),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final price = double.parse(priceCtrl.text);
    final origPrice = origPriceCtrl.text.isNotEmpty ? double.parse(origPriceCtrl.text) : price;

    final payload = {
      "canteen_id": widget.canteenId,
      "category_id": selectedCatId,
      "name": nameCtrl.text.trim(),
      "description": descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      "price": price,
      "original_price": origPrice,
      "hsn_sac_code": hsnCtrl.text.trim(),
      "gst_rate_percent": double.parse(gstCtrl.text.trim()),
      "stock_quantity": stockCtrl.text.trim().isEmpty ? null : int.parse(stockCtrl.text),
      "preparation_time_minutes": int.parse(prepCtrl.text),
      "is_available": isAvailable,
      "is_recommended": isRecommended,
      "image_url": imgCtrl.text.trim().isEmpty ? null : imgCtrl.text.trim(),
    };

    try {
      if (isEdit) {
        final itemId = item["id"];
        final res = await ApiClient.put("/admin/menu-items/$itemId", body: payload);
        if (res.statusCode == 200) _loadMenu();
      } else {
        final res = await ApiClient.post("/admin/menu-items", body: payload);
        if (res.statusCode == 201) _loadMenu();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save failed: $e")));
      }
    }
  }

  Future<void> _deactivateItem(int itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Deactivate Item"),
        content: const Text("This item will be hidden from customer menus."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Deactivate", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiClient.delete("/admin/menu-items/$itemId");
      if (res.statusCode == 200) _loadMenu();
    }
  }

  Future<void> _reactivateItem(int itemId) async {
    final res = await ApiClient.put("/admin/menu-items/$itemId", body: {"is_available": true});
    if (res.statusCode == 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text("Menu item #$itemId reactivated.")),
        );
      }
      _loadMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedItems = _showInactive
        ? _menuItems
        : _menuItems.where((i) => (i["is_available"] as bool? ?? true)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Menu Management"),
        actions: [
          Row(
            children: [
              const Text("Inactive", style: TextStyle(fontSize: 12)),
              Switch(
                value: _showInactive,
                onChanged: (v) {
                  setState(() => _showInactive = v);
                  _loadMenu();
                },
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: () => _openItemDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : displayedItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        "No menu items found",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Create First Menu Item"),
                        onPressed: () => _openItemDialog(),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  itemCount: displayedItems.length,
                  itemBuilder: (context, i) {
                    final item = displayedItems[i];
                    final isAvail = item["is_available"] as bool? ?? true;
                    final isRec = item["is_recommended"] as bool? ?? false;
                    final stock = item["stock_quantity"];
                    final price = item["price"];
                    final origPrice = item["original_price"];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 54,
                                height: 54,
                                child: (item["image_url"] != null && (item["image_url"] as String).trim().isNotEmpty)
                                    ? Image.network(
                                        (item["image_url"] as String).trim(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: isAvail ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
                                          child: Icon(
                                            Icons.fastfood_rounded,
                                            color: isAvail ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                                            size: 26,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: isAvail ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
                                        child: Icon(
                                          Icons.fastfood_rounded,
                                          color: isAvail ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                                          size: 26,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item["name"],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isAvail ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                            decoration: isAvail ? null : TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ),
                                      if (isRec) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 13),
                                              SizedBox(width: 2),
                                              Text(
                                                "Top Pick",
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        "\$$price",
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                                      ),
                                      if (origPrice != null && origPrice != price)
                                        Text(
                                          "\$$origPrice",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: stock == 0 ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          stock == null ? "Stock: Unlimited" : "Stock: $stock",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: stock == 0 ? const Color(0xFFDC2626) : const Color(0xFF475569),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isAvail ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isAvail ? "Active" : "Disabled",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isAvail ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2563EB)),
                                  tooltip: "Edit Item",
                                  onPressed: () => _openItemDialog(item: item),
                                ),
                                if (isAvail)
                                  IconButton(
                                    icon: const Icon(Icons.visibility_off_outlined, size: 20, color: Color(0xFFEF4444)),
                                    tooltip: "Deactivate",
                                    onPressed: () => _deactivateItem(item["id"] as int),
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, size: 20, color: Color(0xFF10B981)),
                                    tooltip: "Reactivate",
                                    onPressed: () => _reactivateItem(item["id"] as int),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
