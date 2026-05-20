import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_crop_screen.dart';
import 'profile_screen.dart';
import 'farmer_orders_screen.dart';
import 'farmer_inventory_screen.dart';
import 'farmer_chats_screen.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  String _farmerName = "Farmer";
  String? _profileUrl;
  int _selectedIndex = 0;
  int _selectedCategoryIndex = 0;
  int _pendingOrderCount = 0;
  int _unreadChatCount = 0;
  String _searchQuery = "";
  bool _isLoading = true;

  static const String _cacheFarmerProfileKey = 'cache_farmer_profile';
  static const String _cacheMarketplaceKey = 'cache_marketplace_products';
  static const String _cachePendingOrdersKey = 'cache_farmer_pending_orders';
  static const String _cacheUnreadChatsKey = 'cache_farmer_unread_chats';

  final List<String> _categories = const [
    "All Produce",
    "Cereals",
    "Fruits",
    "Vegetables",
    "Tubers",
  ];

  List _products = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardCachedFirst();
  }

  String? _normalizeImageUrl(dynamic raw) {
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

  List _normalizeListResponse(dynamic response) {
    List raw = [];

    if (response is List) {
      raw = response;
    } else if (response is Map) {
      final data = response['data'];
      if (data is List) raw = data;
    }

    return raw.map((item) {
      if (item is Map) {
        final mapped = Map<String, dynamic>.from(item);

        final dynamic rawImages =
            mapped['imageUrls'] ??
            mapped['imageurls'] ??
            mapped['image_url'] ??
            mapped['image_urls'] ??
            mapped['images'];

        List<String> imageList = [];

        if (rawImages is List) {
          imageList = rawImages
              .map(_normalizeImageUrl)
              .whereType<String>()
              .toList();
        } else {
          final single = _normalizeImageUrl(rawImages);
          if (single != null) imageList = [single];
        }

        mapped['imageUrls'] = imageList;
        mapped['imageurls'] = imageList;

        if ((mapped['name'] == null ||
                mapped['name'].toString().trim().isEmpty) &&
            mapped['crop_type'] != null) {
          mapped['name'] = mapped['crop_type'].toString();
        }

        if ((mapped['farmer'] == null ||
                mapped['farmer'].toString().trim().isEmpty) &&
            mapped['farmer_name'] != null) {
          mapped['farmer'] = mapped['farmer_name'].toString();
        }

        return mapped;
      }

      return item;
    }).toList();
  }

  bool get _hasValidProfileUrl {
    final url = _profileUrl?.trim() ?? '';
    return url.isNotEmpty && url.toLowerCase() != 'null';
  }

  Future<void> _loadDashboardCachedFirst() async {
    await _loadCachedDashboard();
    if (mounted) {
      setState(() => _isLoading = false);
    }
    _refreshDashboardInBackground();
  }

  Future<void> _loadCachedDashboard() async {
    await Future.wait([
      _loadCachedFarmerData(),
      _loadCachedProduce(),
      _loadCachedPendingOrderCount(),
      _loadCachedUnreadChatCount(),
    ]);
  }

  Future<void> _refreshDashboardInBackground() async {
    await Future.wait([
      _loadFarmerData(saveToCache: true),
      _loadProduceFromDatabase(saveToCache: true, showLoader: false),
      _loadPendingOrderCount(saveToCache: true),
      _loadUnreadChatCount(saveToCache: true),
    ]);
  }

  Future<void> _loadCachedFarmerData() async {
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        _farmerName = prefs.getString('userName') ?? "Farmer";
        final savedProfileUrl = prefs.getString('userProfileUrl') ?? '';
        if (savedProfileUrl.trim().isNotEmpty &&
            savedProfileUrl.trim().toLowerCase() != 'null') {
          _profileUrl = savedProfileUrl;
        }
      });
    }

    final cached = await CacheService.readJson(_cacheFarmerProfileKey);
    if (cached is Map && mounted) {
      final data = cached['data'] is Map ? cached['data'] as Map : cached;

      setState(() {
        final cachedProfileUrl = data['profile_url']?.toString() ?? '';
        if (cachedProfileUrl.trim().isNotEmpty &&
            cachedProfileUrl.trim().toLowerCase() != 'null') {
          _profileUrl = cachedProfileUrl;
        }

        if (data['full_name'] != null &&
            data['full_name'].toString().trim().isNotEmpty) {
          _farmerName = data['full_name'].toString();
        }
      });
    }
  }

  Future<void> _loadCachedProduce() async {
    final cached = await CacheService.readJson(_cacheMarketplaceKey);
    final products = _normalizeListResponse(cached);

    if (mounted && products.isNotEmpty) {
      setState(() {
        _products = products;
      });
    }
  }

  Future<void> _loadCachedPendingOrderCount() async {
    final cached = await CacheService.readJson(_cachePendingOrdersKey);
    if (cached is Map && mounted) {
      setState(() {
        _pendingOrderCount = (cached['count'] as num?)?.toInt() ?? 0;
      });
    }
  }

  Future<void> _loadCachedUnreadChatCount() async {
    final cached = await CacheService.readJson(_cacheUnreadChatsKey);
    if (cached is Map && mounted) {
      setState(() {
        _unreadChatCount = (cached['count'] as num?)?.toInt() ?? 0;
      });
    }
  }

  Future<void> _loadFarmerData({bool saveToCache = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? "";

    if (mounted) {
      setState(() {
        _farmerName = prefs.getString('userName') ?? _farmerName;
        final savedProfileUrl = prefs.getString('userProfileUrl') ?? '';
        if (savedProfileUrl.trim().isNotEmpty &&
            savedProfileUrl.trim().toLowerCase() != 'null') {
          _profileUrl = savedProfileUrl;
        }
      });
    }

    if (phone.isEmpty) return;

    final res = await ApiService.fetchUserProfile(phone);
    if (res['status'] == 'success' && mounted) {
      final data = res['data'] is Map ? res['data'] as Map : {};

      final freshProfileUrl = data['profile_url']?.toString() ?? '';

      if (freshProfileUrl.trim().isNotEmpty &&
          freshProfileUrl.trim().toLowerCase() != 'null') {
        await prefs.setString('userProfileUrl', freshProfileUrl);
      }

      if (data['full_name'] != null &&
          data['full_name'].toString().trim().isNotEmpty) {
        await prefs.setString('userName', data['full_name'].toString());
      }

      setState(() {
        if (freshProfileUrl.trim().isNotEmpty &&
            freshProfileUrl.trim().toLowerCase() != 'null') {
          _profileUrl = freshProfileUrl;
        }

        if (data['full_name'] != null &&
            data['full_name'].toString().trim().isNotEmpty) {
          _farmerName = data['full_name'].toString();
        }
      });

      if (saveToCache) {
        await CacheService.saveJson(_cacheFarmerProfileKey, res);
      }
    }
  }

  Future<void> _loadProduceFromDatabase({
    bool saveToCache = false,
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }

    final response = await ApiService.fetchProduce();
    final products = _normalizeListResponse(response);

    debugPrint('RAW PRODUCE: $response');
    debugPrint('NORMALIZED PRODUCE: $products');

    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }

    if (saveToCache) {
      await CacheService.saveJson(_cacheMarketplaceKey, products);
    }
  }

  Future<void> _loadPendingOrderCount({bool saveToCache = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? "";
    if (phone.isEmpty) return;

    final response = await ApiService.fetchFarmerOrders(phone);
    final orders = _normalizeListResponse(response);

    final pendingCount = orders.where((o) {
      final status = (o['status'] ?? '').toString().toLowerCase();
      return status == 'pending';
    }).length;

    if (mounted) {
      setState(() {
        _pendingOrderCount = pendingCount;
      });
    }

    if (saveToCache) {
      await CacheService.saveJson(_cachePendingOrdersKey, {'count': pendingCount});
    }
  }

  Future<void> _loadUnreadChatCount({bool saveToCache = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? "";
    if (phone.isEmpty) return;

    final unreadMap = await ApiService.fetchUnreadCounts(phone);
    final total = unreadMap.values.fold(0, (sum, count) => sum + count);

    if (mounted) {
      setState(() {
        _unreadChatCount = total;
      });
    }

    if (saveToCache) {
      await CacheService.saveJson(_cacheUnreadChatsKey, {'count': total});
    }
  }

  Future<void> _refreshMarketTab() async {
    await Future.wait([
      _loadFarmerData(saveToCache: true),
      _loadProduceFromDatabase(saveToCache: true, showLoader: false),
      _loadPendingOrderCount(saveToCache: true),
      _loadUnreadChatCount(saveToCache: true),
    ]);
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0 || index == 2 || index == 3) {
      _loadPendingOrderCount(saveToCache: true);
      _loadUnreadChatCount(saveToCache: true);
      _loadFarmerData(saveToCache: true);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return "Farmer";
    return trimmed.split(' ').first;
  }

  IconData _getIconForCrop(String cropName) {
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
      case 'simsim (sesame)':
        return Icons.spa_rounded;
      case 'cassava':
      case 'sweet potatoes':
      case 'irish potatoes':
      case 'yams':
        return Icons.energy_savings_leaf_rounded;
      case 'matooke':
      case 'bananas (bogoya)':
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
      case 'dodo (amaranth)':
      case 'eggplants':
      case 'green pepper':
      case 'carrots':
        return Icons.eco_rounded;
      default:
        return Icons.local_florist_rounded;
    }
  }

  List get _displayedProducts {
    List filtered = List.from(_products);

    if (_selectedCategoryIndex > 0) {
      final category = _categories[_selectedCategoryIndex];
      filtered = filtered.where((item) {
        final cropName =
            (item['name'] ?? item['crop_type'] ?? '').toString().toLowerCase();
        switch (category) {
          case 'Cereals':
            return ['maize', 'millet', 'sorghum', 'rice', 'wheat']
                .contains(cropName);
          case 'Fruits':
            return [
              'matooke',
              'bananas (bogoya)',
              'mangoes',
              'pineapples',
              'watermelon',
              'avocado',
              'passion fruits'
            ].contains(cropName);
          case 'Vegetables':
            return [
              'tomatoes',
              'onions',
              'cabbage',
              'dodo (amaranth)',
              'eggplants',
              'green pepper',
              'carrots'
            ].contains(cropName);
          case 'Tubers':
            return ['cassava', 'sweet potatoes', 'irish potatoes', 'yams']
                .contains(cropName);
          default:
            return true;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final name =
            (item['name'] ?? item['crop_type'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  Widget _buildDashboardAvatar(bool isDark) {
    if (!_hasValidProfileUrl) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: isDark ? const Color(0xFF232323) : Colors.green.shade50,
        child: Icon(Icons.person_rounded, color: Colors.green.shade700),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: isDark ? const Color(0xFF232323) : Colors.green.shade50,
      child: ClipOval(
        child: Image.network(
          _profileUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              width: 44,
              height: 44,
              color: isDark ? const Color(0xFF232323) : Colors.green.shade50,
              alignment: Alignment.center,
              child: Icon(Icons.person_rounded, color: Colors.green.shade700),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 128,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.28)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111B15),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroMetric({
    required bool isDark,
    required String label,
    required String value,
    required Color accent,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111B15),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greeting = _getGreeting();
    final firstName = _firstName(_farmerName);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF121212),
                    Color(0xFF173624),
                    Color(0xFF1E1E1E),
                  ]
                : [
                    const Color(0xFFF7FFF8),
                    Colors.green.shade50,
                    Colors.orange.shade50,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.38)
                  : Colors.green.shade100.withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -20,
              right: -10,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade700.withOpacity(0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -10,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.shade600.withOpacity(0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.07)
                                  : Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.white.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.agriculture_rounded,
                                  color: Colors.green.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "SAMS Market",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF23412D),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _onNavTap(4),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green.shade700.withOpacity(0.35),
                              width: 2,
                            ),
                          ),
                          child: _buildDashboardAvatar(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    greeting,
                    style: TextStyle(
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    firstName,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111B15),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Manage inventory, review buyer orders, and explore live produce listings from one premium farmer workspace.',
                    style: TextStyle(
                      color:
                          isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      fontSize: 13.2,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.white.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.white.withOpacity(0.55),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _heroMetric(
                                isDark: isDark,
                                label: 'Pending Orders',
                                value: '$_pendingOrderCount',
                                accent: Colors.orange.shade600,
                                icon: Icons.notifications_active_rounded,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 48,
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.06),
                            ),
                            Expanded(
                              child: _heroMetric(
                                isDark: isDark,
                                label: 'Market Listings',
                                value: '${_products.length}',
                                accent: Colors.green.shade700,
                                icon: Icons.storefront_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_pendingOrderCount == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.24)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade700.withOpacity(0.12),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're all caught up",
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF111B15),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No pending buyer orders need action right now.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: GestureDetector(
        onTap: () => _onNavTap(2),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Colors.orange.shade900.withOpacity(0.55),
                      const Color(0xFF1E1E1E),
                    ]
                  : [
                      Colors.orange.shade50,
                      Colors.white,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.orange.shade600.withOpacity(0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.shade600
                    .withOpacity(isDark ? 0.18 : 0.10),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.shade600.withOpacity(0.14),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.orange.shade600,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_pendingOrderCount pending order${_pendingOrderCount == 1 ? '' : 's'} need attention',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF111B15),
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review, accept, or reject buyer requests now.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.orange.shade600,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111B15);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marketplace Feed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Explore live produce listings from across the platform.',
              style: TextStyle(
                fontSize: 12.8,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.22)
                        : Colors.black.withOpacity(0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search produce by crop name...',
                  hintStyle: TextStyle(color: subTextColor),
                  prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () => setState(() => _searchQuery = ''),
                          icon: Icon(Icons.close_rounded, color: subTextColor),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 54,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          itemCount: _categories.length,
          itemBuilder: (_, index) {
            final selected = _selectedCategoryIndex == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategoryIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: [
                            Colors.green.shade700,
                            Colors.green.shade800,
                          ],
                        )
                      : null,
                  color: selected
                      ? null
                      : isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? Colors.green.shade700
                        : isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Center(
                  child: Text(
                    _categories[index],
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : isDark
                              ? Colors.white
                              : const Color(0xFF111B15),
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
    );
  }

  Widget _buildSectionHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayList = _displayedProducts;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
        child: Row(
          children: [
            Text(
              'Fresh from Farms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111B15),
              ),
            ),
            const Spacer(),
            if (_isLoading)
              SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.green.shade700,
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.shade600.withOpacity(0.16)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${displayList.length} listing${displayList.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.orange.shade600,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.8),
      duration: const Duration(milliseconds: 850),
      builder: (_, opacity, __) => Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Container(
                height: 118,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 90,
                        decoration: BoxDecoration(
                          color:
                              isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 10,
                        width: 60,
                        decoration: BoxDecoration(
                          color:
                              isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 16,
                        width: 70,
                        decoration: BoxDecoration(
                          color:
                              isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cropImagePlaceholder(String cropName, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.green.shade50,
      child: Center(
        child: Icon(
          _getIconForCrop(cropName),
          size: 38,
          color: Colors.green.shade700,
        ),
      ),
    );
  }

  Widget _buildProductCard(Map item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111B15);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final List? imageUrls =
        (item['imageUrls'] as List?) ?? (item['imageurls'] as List?);
    final String? firstImage =
        imageUrls != null && imageUrls.isNotEmpty ? imageUrls.first.toString() : null;

    final cropName = (item['name'] ?? '').toString();
    final farmerName = (item['farmer'] ?? 'Unknown farmer').toString();
    final price = (item['price'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: firstImage != null
                        ? Image.network(
                            firstImage,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: isDark
                                    ? const Color(0xFF121212)
                                    : Colors.green.shade50,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) =>
                                _cropImagePlaceholder(cropName, isDark),
                          )
                        : _cropImagePlaceholder(cropName, isDark),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.eco_rounded,
                                size: 12,
                                color: Colors.green.shade300,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                cropName,
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
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cropName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Farmer $farmerName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'UGX / kg',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      price,
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
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

  Widget _buildEmptyMarketplace() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 120),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.green.shade50,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 44,
                  color: isDark ? Colors.grey.shade600 : Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'No produce matched your search',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111B15),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try another crop name or switch category filters to discover more listings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketTab() {
    final displayList = _displayedProducts;

    return RefreshIndicator(
      onRefresh: _refreshMarketTab,
      color: Colors.green.shade700,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeroSection(),
                  _buildPendingBanner(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Row(
                      children: [
                        _buildQuickAction(
                          isDark: Theme.of(context).brightness == Brightness.dark,
                          icon: Icons.add_box_rounded,
                          title: 'Add Crop',
                          subtitle: 'Create a fresh listing.',
                          color: Colors.green.shade700,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddCropScreen(),
                              ),
                            );
                            await _refreshMarketTab();
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildQuickAction(
                          isDark: Theme.of(context).brightness == Brightness.dark,
                          icon: Icons.inventory_2_rounded,
                          title: 'Inventory',
                          subtitle: 'Manage active stock.',
                          color: Colors.orange.shade600,
                          onTap: () => _onNavTap(1),
                        ),
                        const SizedBox(width: 12),
                        _buildQuickAction(
                          isDark: Theme.of(context).brightness == Brightness.dark,
                          icon: Icons.receipt_long_rounded,
                          title: 'Orders',
                          subtitle: 'Process requests.',
                          color: Colors.red.shade400,
                          onTap: () => _onNavTap(2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildSearchAndFilter(),
          _buildCategorySection(),
          _buildSectionHeader(),
          if (_isLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => _buildShimmerCard(),
                  childCount: 6,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
              ),
            )
          else if (displayList.isEmpty)
            _buildEmptyMarketplace()
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, index) =>
                      _buildProductCard(Map.from(displayList[index] as Map)),
                  childCount: displayList.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedFontSize: 11.5,
          unselectedFontSize: 11.5,
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor:
              isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          showUnselectedLabels: true,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.space_dashboard_rounded),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Inventory',
            ),
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
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _pendingOrderCount > 9 ? '9+' : '$_pendingOrderCount',
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
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded),
                  if (_unreadChatCount > 0)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 3,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _unreadChatCount > 99 ? '99+' : '$_unreadChatCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Chats',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF6F8F5);

    return Scaffold(
      backgroundColor: scaffoldBg,
      bottomNavigationBar: _buildBottomNav(),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMarketTab(),
          const FarmerInventoryScreen(),
          const FarmerOrdersScreen(),
          const FarmerChatsScreen(),
          const ProfileScreen(),
        ],
      ),
    );
  }
}