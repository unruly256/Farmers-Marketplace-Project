import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart'; 
import 'screens/farmer_dashboard.dart';

// ── 1. GLOBAL THEME NOTIFIER (Defaults to System) ──
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // Check their saved theme preference when the app boots up
  final String? themeStr = prefs.getString('themeMode');
  if (themeStr == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  } else if (themeStr == 'light') {
    themeNotifier.value = ThemeMode.light;
  } else {
    themeNotifier.value = ThemeMode.system; // Follows the device settings!
  }

  runApp(FarmersMarketplaceApp(isLoggedIn: isLoggedIn));
}

class FarmersMarketplaceApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const FarmersMarketplaceApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    // ── 2. LISTEN TO THEME CHANGES ──
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'SAMS Market',
          debugShowCheckedModeBanner: false,
          
          // ── 3. PREMIUM LIGHT THEME ──
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.green.shade700,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF8F9FA),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black87),
              titleTextStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700,
              secondary: Colors.orange.shade600,
            ),
          ),

          // ── 4. PREMIUM DARK THEME ──
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.greenAccent.shade400,
            scaffoldBackgroundColor: const Color(0xFF121212), // Deep AMOLED Dark
            cardColor: const Color(0xFF1E1E1E), 
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            colorScheme: ColorScheme.dark(
              primary: Colors.greenAccent.shade400,
              secondary: Colors.orangeAccent.shade200,
              surface: const Color(0xFF1E1E1E),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF1E1E1E),
              selectedItemColor: Colors.greenAccent,
              unselectedItemColor: Colors.white54,
            ),
          ),

          // ── 5. THE ACTIVE MODE ──
          themeMode: currentMode,
          
          home: isLoggedIn ? const FarmerDashboard() : const WelcomeScreen(), 
        );
      },
    );
  }
}