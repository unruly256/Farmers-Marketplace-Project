import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import 'buyer_orders_screen.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'cart_screen.dart';
import 'chat_screen.dart';
import 'product_detail_screen.dart';

class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  String _buyerName  = "Buyer";
  String _buyerPhone = "";
  int _selectedIndex = 0;
  int _selectedCategoryIndex = 0;
  String _searchQuery = "";

  final List<String> _categories = ["All", "Cereals", "Fruits", "Vegetables", "Tubers"];

  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBuyerData();
    _loadProduceFromDatabase();
  }

  Future<void> _loadBuyerData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _buyerName  = prefs.getString('userName')  ?? "Buyer";
      _buyerPhone = prefs.getString('userPhone') ?? "";
    });
  }

  Future<void> _loadProduceFromDatabase() async {
    setState(() => _isLoading = true);
    final realProducts = await ApiService.fetchProduce();
    if (mounted) {
      setState(() {
        _products   = realProducts;
        _isLoading  = false;
      });
    }
  }

  // Returns products filtered by both search query and selected category chip
  List<dynamic> get _filteredProducts {
    return _products.where((item) {
      final name    = (item['name']    ?? '').toString().toLowerCase();
      final farmer  = (item['farmer']  ?? '').toString().toLowerCase();
      final query   = _searchQuery.toLowerCase();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          farmer.contains(query);

      final matchesCategory = _selectedCategoryIndex == 0 || (() {
        switch (_selectedCategoryIndex) {
          case 1: return ['maize', 'beans'].contains(name);          // Cereals
          case 2: return ['tomatoes'].contains(name);                // Fruits
          case 3: return ['tomatoes'].contains(name);                // Vegetables
          case 4: return ['cassava', 'matooke'].contains(name);      // Tubers
          default: return true;
        }
      })();

      return matchesSearch && matchesCategory;
    }).toList();
  }

  IconData _getIconForCrop(String cropName) {
    switch (cropName.toLowerCase()) {
      case 'maize':    return Icons.grass_rounded;
      case 'beans':    return Icons.spa_rounded;
      case 'tomatoes': return Icons.eco_rounded;
      case 'matooke':  return Icons.park_rounded;
      case 'cassava':  return Icons.energy_savings_leaf_rounded;
      default:         return Icons.local_florist_rounded;
    }
  }

  void _addToCart(Map<String, dynamic> item) {
    CartService.addToCart(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item['name']} added to your cart!'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------
  // BOTTOM NAV ROUTING — each tab navigates to its real screen
  // ---------------------------------------------------------------
  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        // Already on Shop — just refresh
        _loadProduceFromDatabase();
        break;
      case 1:
        // Explore — no dedicated screen yet, stay put
        break;
      case 2:
        // My Orders
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BuyerOrdersScreen()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 3:
        // Profile
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;

    return Scaffold(
      backgroundColor: Colors.white,

      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CartScreen()),
        ),
        backgroundColor: Colors.orange.shade700,
        child: const Icon(Icons.shopping_cart_rounded, color: Colors.white),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,   // <-- wired up
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange.shade700,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront),           label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded),       label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined),label: 'My Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),       label: 'Profile'),
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
                      backgroundColor: Colors.orange.shade50,
                      child: Icon(Icons.person, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text('Ready to shop,', style: TextStyle(fontSize: 16, color: Colors.grey)),
              Text(_buyerName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),

              const SizedBox(height: 20),
              // Live search field
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search fresh produce in your district...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => _searchQuery = ""),
                        )
                      : Icon(Icons.tune_rounded, color: Colors.orange.shade700),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 25),
              const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final selected = _selectedCategoryIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategoryIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: selected ? Colors.orange.shade700 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            _categories[index],
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
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
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Results for "$_searchQuery"'
                        : 'Available Nearby',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                    ),
                ],
              ),
              const SizedBox(height: 15),

              if (!_isLoading && filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No results for "$_searchQuery"'
                              : "No produce available right now.",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!_isLoading && filtered.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.70,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(item: item),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                                  child: Icon(_getIconForCrop(item['name'] ?? ''), size: 24, color: Colors.green.shade700),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    '${item['quantity']} kg',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('By ${item['farmer'] ?? ''}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('UGX', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    Text(item['price'].toString(),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            currentPhone: _buyerPhone,
                                            contactPhone: item['farmer_phone'] ?? "00000",
                                            contactName: item['farmer'] ?? 'Farmer',
                                          ),
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                        child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.green.shade700, size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _addToCart(item),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
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