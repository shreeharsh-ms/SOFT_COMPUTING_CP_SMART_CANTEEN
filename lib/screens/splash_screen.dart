import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../core/services/websocket_client.dart";
import "../providers/auth_provider.dart";

class SplashScreen extends StatefulWidget {
  final WebSocketClient wsClient;
  const SplashScreen({super.key, required this.wsClient});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  void _navigate(AuthProvider auth) {
    if (!mounted) return;
    if (auth.isAuthenticated) {
      widget.wsClient.connect();
      final role = auth.user?.role;
      if (role == "ADMIN" || role == "SUPER_ADMIN") {
        Navigator.pushNamedAndRemoveUntil(context, "/admin", (r) => false);
      } else if (role == "KITCHEN") {
        Navigator.pushNamedAndRemoveUntil(context, "/kitchen", (r) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, "/home", (r) => false);
      }
    } else {
      Navigator.pushNamedAndRemoveUntil(context, "/login", (r) => false);
    }
  }

  void _checkInitialAuth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isLoading) {
        void listener() {
          if (!auth.isLoading) {
            auth.removeListener(listener);
            _navigate(auth);
          }
        }
        auth.addListener(listener);
      } else {
        _navigate(auth);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood, size: 84, color: Colors.deepOrange),
            SizedBox(height: 16),
            Text("Smart Canteen", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("AI-Powered Pre-Ordering & Management", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 32),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
