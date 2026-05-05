import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart'; // IMPORTED THE NEW SCREEN
import 'screens/farmer_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check the long-term memory to see if they are already logged in
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(FarmersMarketplaceApp(isLoggedIn: isLoggedIn));
}

class FarmersMarketplaceApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const FarmersMarketplaceApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmers Marketplace',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      debugShowCheckedModeBanner: false,
      // Routes to the new WelcomeScreen if they aren't logged in
      home: isLoggedIn ? const FarmerDashboard() : const WelcomeScreen(), 
    );
  }
}