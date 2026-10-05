import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "core/services/api_client.dart";
import "core/services/websocket_client.dart";
import "providers/auth_provider.dart";
import "providers/cart_provider.dart";
import "screens/splash_screen.dart";
import "screens/auth/login_screen.dart";
import "screens/auth/register_screen.dart";
import "screens/customer/main_shell.dart";
import "screens/customer/student_entry_screen.dart";
import "screens/admin/admin_dashboard_screen.dart";
import "screens/kitchen/kitchen_monitor_screen.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartCanteenApp());
}

class SmartCanteenApp extends StatefulWidget {
  const SmartCanteenApp({super.key});

  @override
  State<SmartCanteenApp> createState() => _SmartCanteenAppState();
}

class _SmartCanteenAppState extends State<SmartCanteenApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final WebSocketClient _wsClient;

  @override
  void initState() {
    super.initState();
    _wsClient = WebSocketClient();
    
    // Global 401 unauthenticated redirect interceptor
    ApiClient.onUnauthorized = () {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil("/login", (route) => false);
    };
  }

  @override
  void dispose() {
    _wsClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProxyProvider<CartProvider, AuthProvider>(
          create: (_) => AuthProvider(),
          update: (_, cart, auth) => auth!..initAuth(cart),
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: "Smart Canteen",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFEA580C),
            primary: const Color(0xFF0F172A),
            secondary: const Color(0xFFEA580C),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            color: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: false,
            backgroundColor: Color(0xFF0F172A),
            foregroundColor: Colors.white,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEA580C), width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        home: SplashScreen(wsClient: _wsClient),
        routes: {
          "/login": (_) => const LoginScreen(),
          "/register": (_) => const RegisterScreen(),
          "/entry": (_) => const StudentEntryScreen(),
          "/home": (_) => MainShell(wsClient: _wsClient),
          "/admin": (_) => AdminDashboardScreen(wsClient: _wsClient),
          "/kitchen": (_) => KitchenMonitorScreen(canteenId: 1, wsClient: _wsClient),
        },
      ),
    );
  }
}
