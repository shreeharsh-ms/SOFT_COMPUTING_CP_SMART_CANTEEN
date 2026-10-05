import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";
import "../../core/services/websocket_client.dart";
import "../../providers/cart_provider.dart";
import "canteen_list_screen.dart";
import "menu_browse_screen.dart";
import "cart_checkout_screen.dart";
import "order_history_screen.dart";
import "wallet_screen.dart";
import "profile_screen.dart";

class MainShell extends StatefulWidget {
  final WebSocketClient wsClient;
  const MainShell({super.key, required this.wsClient});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int? _selectedCanteenId;
  String? _selectedCanteenName;

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    final homeScreen = _selectedCanteenId != null
        ? MenuBrowseScreen(
            key: ValueKey("menu_browse_canteen_$_selectedCanteenId"),
            canteenId: _selectedCanteenId!,
            canteenName: _selectedCanteenName ?? "Campus Outlet",
            wsClient: widget.wsClient,
            onBackToCanteens: () => setState(() {
              _selectedCanteenId = null;
              _selectedCanteenName = null;
            }),
            onNavigateToCart: () => setState(() => _currentIndex = 1),
          )
        : CanteenListScreen(
            key: const ValueKey("canteen_list_home"),
            wsClient: widget.wsClient,
            onNavigateTab: (idx) => setState(() => _currentIndex = idx),
            onSelectCanteen: (id, name) => setState(() {
              _selectedCanteenId = id;
              _selectedCanteenName = name;
            }),
          );

    final screens = [
      homeScreen,
      CartCheckoutScreen(
        wsClient: widget.wsClient,
        onNavigateHome: () => setState(() => _currentIndex = 0),
      ),
      OrderHistoryScreen(wsClient: widget.wsClient),
      const WalletScreen(),
      ProfileScreen(wsClient: widget.wsClient),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedCanteenId != null) {
          setState(() {
            _selectedCanteenId = null;
            _selectedCanteenName = null;
          });
        } else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF7F2),
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  label: "Home",
                  activeIcon: Icons.home_rounded,
                  inactiveIcon: Icons.home_outlined,
                  isPrimaryFab: true,
                ),
                _buildNavItem(
                  index: 1,
                  label: "Cart",
                  activeIcon: Icons.shopping_bag_rounded,
                  inactiveIcon: Icons.shopping_bag_outlined,
                  badgeCount: cart.itemCount,
                ),
                _buildNavItem(
                  index: 2,
                  label: "Orders",
                  activeIcon: Icons.receipt_long_rounded,
                  inactiveIcon: Icons.receipt_long_outlined,
                ),
                _buildNavItem(
                  index: 3,
                  label: "Wallet",
                  activeIcon: Icons.account_balance_wallet_rounded,
                  inactiveIcon: Icons.account_balance_wallet_outlined,
                ),
                _buildNavItem(
                  index: 4,
                  label: "Profile",
                  activeIcon: Icons.person_rounded,
                  inactiveIcon: Icons.person_outline_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData activeIcon,
    required IconData inactiveIcon,
    bool isPrimaryFab = false,
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;

    void onSelectTab() {
      if (index == 0 && _currentIndex == 0 && _selectedCanteenId != null) {
        setState(() {
          _selectedCanteenId = null;
          _selectedCanteenName = null;
        });
      } else {
        setState(() => _currentIndex = index);
      }
    }

    // Premium primary floating action button for Home
    if (isPrimaryFab && isSelected) {
      return GestureDetector(
        onTap: onSelectTab,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B4A), Color(0xFFEA580C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.home_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFEA580C),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    Widget iconWidget = Icon(
      isSelected ? activeIcon : inactiveIcon,
      size: 23,
      color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
    );

    if (badgeCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -8,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                "$badgeCount",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onSelectTab,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 40,
              alignment: Alignment.center,
              child: iconWidget,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
