import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_crop_screen.dart';
import 'profile_screen.dart';
import 'farmer_orders_screen.dart'; // NEW IMPORT
import '../services/api_service.dart';

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  String _farmerName = "Farmer"; // FIXED: was hardcoded as "Anoor"
  int _selectedIndex = 0;
  int _selectedCategoryIndex = 0;

  final List<String> _categories = ["All Produce", "Cereals", "Fruits", "Vegetables"];

  List<dynamic> _products = [];
  bool _isLoading = true;
  int _pendingOrderCount = 0; // NEW: badge counter for the Orders tab

  @override
  void initState() {
    super.initState();
    _loadFarmerData();
    _loadProduceFromDatabase();
    _loadPendingOrderCount(); // NEW: load badge on startup
  }

  // FIXED: Load farmer name from SharedPreferences instead of hardcoding
  Future<void> _loadFarmerData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _farmerName = prefs.getString('userName') ?? "Farmer";
    });
  }

  Future<void> _loadProduceFromDatabase() async {
    setState(() => _isLoading = true);
    final realProducts = await ApiService.fetchProduce();
    if (mounted) {
      setState(() {
        _products = realProducts;
        _isLoading = false;
      });
    }
  }

  // NEW: Fetch pending order count to display on the Orders tab badge
  Future<void> _loadPendingOrderCount() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? "";
    if (phone.isEmpty) return;

    final orders = await ApiService.fetchFarmerOrders(phone);
    if (mounted) {
      setState(() {
        _pendingOrderCount = orders.where((o) => o['status'] == 'Pending').length;
      });
    }
  }

  IconData _getIconForCrop(String cropName) {
    switch (cropName.toLowerCase()) {
      case 'maize':   return Icons.grass_rounded;
      case 'beans':   return Icons.spa_rounded;
      case 'tomatoes':return Icons.eco_rounded;
      case 'matooke': return Icons.park_rounded;
      case 'cassava': return Icons.energy_savings_leaf_rounded;
      default:        return Icons.local_florist_rounded;
    }
  }

  // Navigate to the Orders screen and refresh the badge when we return
  void _goToOrders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FarmerOrdersScreen()),
    );
    _loadPendingOrderCount(); // Refresh badge after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCropScreen()),
          );
          _loadProduceFromDatabase();
        },
        backgroundColor: Colors.green.shade700,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Crop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          // NEW: Navigate to orders screen when the Orders tab is tapped
          if (index == 2) _goToOrders();
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'Market',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Cart',
          ),
          // NEW: Orders tab with a live pending-order badge
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.receipt_long_outlined),
                if (_pendingOrderCount > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_pendingOrderCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Orders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Transport',
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SAMS Market',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.shade100,
                      child: const Icon(Icons.person, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text('Good Afternoon,',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              // FIXED: Now shows the real farmer name from SharedPreferences
              Text(_farmerName,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),

              // NEW: Pending orders prompt card (shown only when there are pending orders)
              if (_pendingOrderCount > 0) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _goToOrders,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_active_rounded,
                              color: Colors.orange.shade800, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_pendingOrderCount order${_pendingOrderCount > 1 ? 's' : ''} waiting for you!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Tap to accept or reject',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.orange.shade700),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search fresh produce...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 25),
              const Text('Categories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    bool selected = _selectedCategoryIndex == index;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCategoryIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.green.shade800
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            _categories[index],
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fresh from Farms',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_isLoading)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 15),

              if (!_isLoading && _products.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Icon(Icons.eco_outlined,
                            size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("No produce listed yet.",
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ),

              if (!_isLoading && _products.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final item = _products[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Icon(Icons.shopping_cart_outlined,
                                size: 20, color: Colors.green.shade700),
                          ),
                          Icon(_getIconForCrop(item['name']),
                              size: 40, color: Colors.green.shade700),
                          const Spacer(),
                          Text(item['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Farmer: ${item['farmer']}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Text('UGX / kg',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            item['price'].toString(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}