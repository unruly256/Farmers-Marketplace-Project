import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'buyer_orders_screen.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';
import 'profile_screen.dart';

class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  String buyerName = 'Buyer';
  String buyerPhone = '';
  String? profileUrl;

  int selectedIndex = 0;
  int selectedCategoryIndex = 0;

  String searchQuery = '';
  bool isLoading = true;

  List<dynamic> products = [];
  List<dynamic> orders = [];

  final List<String> categories = const [
    'All',
    'Cereals',
    'Vegetables',
    'Tubers',
    'Fruits',
  ];

  @override
  void initState() {
    super.initState();
    bootstrap();
  }

  List<dynamic> normalizeListResponse(dynamic response) {
    if (response is List) return response;
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) return data;
    }
    return [];
  }

  bool get hasValidProfileUrl {
    final url = profileUrl?.trim() ?? '';
    return url.isNotEmpty && url.toLowerCase() != 'null';
  }

  Future<void> bootstrap() async {
    await Future.wait([
      loadBuyerData(),
      loadProduceFromDatabase(),
      loadBuyerOrders(),
    ]);
  }

  Future<void> loadBuyerData() async {
    final prefs = await SharedPreferences.getInstance();
    buyerPhone = prefs.getString('userPhone') ?? '';

    final savedName = prefs.getString('userName') ?? 'Buyer';
    final savedProfileUrl = prefs.getString('userProfileUrl') ?? '';

    if (mounted) {
      setState(() {
        buyerName = savedName;
        if (savedProfileUrl.trim().isNotEmpty &&
            savedProfileUrl.trim().toLowerCase() != 'null') {
          profileUrl = savedProfileUrl;
        }
      });
    }

    if (buyerPhone.isEmpty) return;

    final res = await ApiService.fetchUserProfile(buyerPhone);
    if (res['status'] == 'success' && mounted) {
      final data = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      final freshName = data['fullname']?.toString().trim() ?? '';
      final freshProfileUrl = data['profileurl']?.toString().trim() ?? '';

      if (freshName.isNotEmpty) {
        await prefs.setString('userName', freshName);
      }
      if (freshProfileUrl.isNotEmpty &&
          freshProfileUrl.toLowerCase() != 'null') {
        await prefs.setString('userProfileUrl', freshProfileUrl);
      }

      setState(() {
        if (freshName.isNotEmpty) buyerName = freshName;
        if (freshProfileUrl.isNotEmpty &&
            freshProfileUrl.toLowerCase() != 'null') {
          profileUrl = freshProfileUrl;
        }
      });
    }
  }

  Future<void> loadProduceFromDatabase() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    final response = await ApiService.fetchProduce();
    final fetchedProducts = normalizeListResponse(response);

    if (mounted) {
      setState(() {
        products = fetchedProducts;
        isLoading = false;
      });
    }
  }

  Future<void> loadBuyerOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? '';
    if (phone.isEmpty) return;

    final response = await ApiService.fetchBuyerOrders(phone);
    final fetchedOrders = normalizeListResponse(response);

    if (mounted) {
      setState(() => orders = fetchedOrders);
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadBuyerData(),
      loadProduceFromDatabase(),
      loadBuyerOrders(),
    ]);
  }

  void onNavTap(int index) {
    setState(() => selectedIndex = index);

    if (index == 0) {
      refreshAll();
    } else if (index == 2) {
      loadBuyerOrders();
    } else if (index == 3) {
      loadBuyerData();
    } else {
      setState(() {});
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  IconData getIconForCrop(String cropName) {
    switch (cropName.toLowerCase()) {
      case 'maize':
      case 'millet':
      case 'sorghum':
      case 'rice':
      case 'wheat':
        return Icons.grass_rounded;
      case 'beans':
      case 'soya beans':
      case 'peas':
      case 'groundnuts':
      case 'simsim sesame':
        return Icons.spa_rounded;
      case 'cassava':
      case 'sweet potatoes':
      case 'irish potatoes':
      case 'yams':
        return Icons.energy_savings_leaf_rounded;
      case 'matooke':
      case 'bananas bogoya':
        return Icons.park_rounded;
      case 'mangoes':
      case 'pineapples':
      case 'watermelon':
      case 'avocado':
      case 'passion fruits':
        return Icons.apple_rounded;
      case 'tomatoes':
      case 'onions':
      case 'cabbage':
      case 'dodo amaranth':
      case 'eggplants':
      case 'green pepper':
      case 'carrots':
        return Icons.eco_rounded;
      default:
        return Icons.local_florist_rounded;
    }
  }

  String? normalizeImageUrl(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();

    if (value.isEmpty || value.toLowerCase() == 'null') return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('/')) {
      return '${ApiService.baseUrl}$value';
    }

    return '${ApiService.baseUrl}/$value';
  }

  String? extractFirstImage(dynamic item) {
    if (item is! Map) return null;

    final dynamic rawImages = item['imageUrls'] ??
        item['imageurls'] ??
        item['imageurl'] ??
        item['image_url'] ??
        item['images'];

    if (rawImages is List && rawImages.isNotEmpty) {
      for (final img in rawImages) {
        final normalized = normalizeImageUrl(img);
        if (normalized != null) return normalized;
      }
    }

    return normalizeImageUrl(rawImages);
  }

  List<dynamic> get displayedProducts {
    List<dynamic> filtered = List.from(products);

    if (selectedCategoryIndex != 0) {
      final category = categories[selectedCategoryIndex];
      filtered = filtered.where((item) {
        final cropName = (item['name'] ?? '').toString().toLowerCase();
        switch (category) {
          case 'Cereals':
            return ['maize', 'millet', 'sorghum', 'rice', 'wheat']
                .contains(cropName);
          case 'Fruits':
            return [
              'matooke',
              'bananas bogoya',
              'mangoes',
              'pineapples',
              'watermelon',
              'avocado',
              'passion fruits',
            ].contains(cropName);
          case 'Vegetables':
            return [
              'tomatoes',
              'onions',
              'cabbage',
              'dodo amaranth',
              'eggplants',
              'green pepper',
              'carrots',
            ].contains(cropName);
          case 'Tubers':
            return [
              'cassava',
              'sweet potatoes',
              'irish potatoes',
              'yams',
            ].contains(cropName);
          default:
            return true;
        }
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final farmer = (item['farmer'] ?? '').toString().toLowerCase();
        final query = searchQuery.toLowerCase();
        return name.contains(query) || farmer.contains(query);
      }).toList();
    }

    return filtered;
  }

  int get activeOrdersCount {
    return orders.where((o) {
      final status = (o['status'] ?? '').toString().toLowerCase();
      return status == 'pending' || status == 'accepted';
    }).length;
  }

  int get availableTodayCount => products.length;

  int get cartCount => CartService.items.length;

  String formatUgx(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    return number.toStringAsFixed(0);
  }

  Color pageBg(bool isDark) =>
      isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA);

  Color surfaceColor(bool isDark) =>
      isDark ? const Color(0xFF1E1E1E) : Colors.white;

  Widget buildQuickStat({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceColor(isDark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildShimmerCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.95),
      duration: const Duration(milliseconds: 900),
      builder: (_, opacity, child) {
        return Opacity(opacity: opacity, child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  // ✅ ADDED: The clean, requested avatar ring wrapper
  Widget buildProfileAvatar(bool isDark) {
    Widget avatarContent;

    if (!hasValidProfileUrl) {
      avatarContent = CircleAvatar(
        radius: 20, // Slightly reduced to accommodate the ring
        backgroundColor: isDark
            ? Colors.orange.shade700.withOpacity(0.16)
            : Colors.orange.shade50,
        child: Icon(Icons.person_rounded, color: Colors.orange.shade600),
      );
    } else {
      avatarContent = CircleAvatar(
        radius: 20,
        backgroundColor: isDark
            ? Colors.orange.shade700.withOpacity(0.16)
            : Colors.orange.shade50,
        child: ClipOval(
          child: Image.network(
            profileUrl!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                width: 40,
                height: 40,
                color: isDark
                    ? Colors.orange.shade700.withOpacity(0.16)
                    : Colors.orange.shade50,
                alignment: Alignment.center,
                child: Icon(Icons.person_rounded, color: Colors.orange.shade600),
              );
            },
          ),
        ),
      );
    }

    // Wrap the avatar in the requested ring
    return Container(
      padding: const EdgeInsets.all(2), // The gap between the avatar and the ring
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.orange.shade600, // Premium orange ring
          width: 2.0, // Ring thickness
        ),
      ),
      child: avatarContent,
    );
  }

  Widget buildProductCard(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final String? firstImage = extractFirstImage(item);
    final quantity = (item['quantity'] ?? 0).toString();
    final farmer = (item['farmer'] ?? 'Verified Farmer').toString();

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              item: Map<String, dynamic>.from(item),
            ),
          ),
        );
        if (mounted) setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor(isDark),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.24 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 10,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: firstImage != null
                          ? Image.network(
                              firstImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  color: isDark
                                      ? Colors.grey.shade900
                                      : Colors.orange.shade50,
                                  child: Icon(
                                    getIconForCrop(
                                      (item['name'] ?? '').toString(),
                                    ),
                                    size: 40,
                                    color: Colors.orange.shade500,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: isDark
                                  ? Colors.grey.shade900
                                  : Colors.orange.shade50,
                              child: Icon(
                                getIconForCrop((item['name'] ?? '').toString()),
                                size: 40,
                                color: Colors.orange.shade500,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.58),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.eco_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$quantity kg left',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade600.withOpacity(0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_outward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['name'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By $farmer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          color: Colors.green.shade700,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'UGX ${formatUgx(item['price'])}/kg',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
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

  Widget buildExploreTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final displayList = displayedProducts;

    return RefreshIndicator(
      onRefresh: refreshAll,
      color: Colors.orange.shade600,
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: surfaceColor(isDark),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.04),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.22 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                getGreeting(),
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                buyerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => onNavTap(3),
                          child: buildProfileAvatar(isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) {
                        setState(() => searchQuery = value);
                      },
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Search produce or farmers...',
                        hintStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: subTextColor,
                        ),
                        suffixIcon: searchQuery.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  setState(() => searchQuery = '');
                                },
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: subTextColor,
                                ),
                              ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.black.withOpacity(0.03),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        buildQuickStat(
                          isDark: isDark,
                          icon: Icons.storefront_rounded,
                          label: 'Available',
                          value: '$availableTodayCount',
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(width: 8),
                        buildQuickStat(
                          isDark: isDark,
                          icon: Icons.shopping_cart_rounded,
                          label: 'In Cart',
                          value: '$cartCount',
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        buildQuickStat(
                          isDark: isDark,
                          icon: Icons.receipt_long_rounded,
                          label: 'Active',
                          value: '$activeOrdersCount',
                          color: Colors.orange.shade700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Browse Categories',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${displayList.length} listings',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: categories.length,
                  itemBuilder: (_, index) {
                    final selected = selectedCategoryIndex == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedCategoryIndex = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.orange.shade600
                              : surfaceColor(isDark),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: selected
                                ? Colors.orange.shade600
                                : isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.05),
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: Colors.orange.shade600.withOpacity(
                                      0.22,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            categories[index],
                            style: TextStyle(
                              color: selected ? Colors.white : textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Text(
                  'Fresh Picks',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: isLoading
                  ? SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, __) => buildShimmerCard(),
                        childCount: 6,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.73,
                      ),
                    )
                  : displayList.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 50),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.orange.shade700.withOpacity(
                                            0.12,
                                          )
                                        : Colors.orange.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.search_off_rounded,
                                    size: 36,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  searchQuery.isNotEmpty
                                      ? 'No results for "$searchQuery"'
                                      : 'No produce available yet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  searchQuery.isNotEmpty
                                      ? 'Try another crop name or clear your search.'
                                      : 'Pull down to refresh and check again shortly.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (_, index) => buildProductCard(
                              Map<String, dynamic>.from(displayList[index]),
                            ),
                            childCount: displayList.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.73,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartCount = this.cartCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.35)
                : Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: onNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedFontSize: 11.5,
          unselectedFontSize: 11.5,
          selectedItemColor: Colors.orange.shade700,
          unselectedItemColor:
              isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          showUnselectedLabels: true,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  if (cartCount > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          cartCount > 9 ? '9+' : '$cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_rounded),
                  if (cartCount > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          cartCount > 9 ? '9+' : '$cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = pageBg(Theme.of(context).brightness == Brightness.dark);

    return Scaffold(
      backgroundColor: scaffoldBg,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: buildBottomNav(),
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          buildExploreTab(),
          CartScreen(key: UniqueKey()),
          const BuyerOrdersScreen(),
          const ProfileScreen(),
        ],
      ),
    );
  }
}