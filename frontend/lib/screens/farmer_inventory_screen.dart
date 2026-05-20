import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'add_crop_screen.dart';

const _kGreenDeep = Color(0xFF0D3320);
const _kGreenMid = Color(0xFF1A5C35);
const _kGreenLight = Color(0xFFE8F5EE);
const _kAmber = Color(0xFFD4840A);
const _kAmberLight = Color(0xFFFFF3E0);

class FarmerInventoryScreen extends StatefulWidget {
  const FarmerInventoryScreen({super.key});

  @override
  State<FarmerInventoryScreen> createState() => _FarmerInventoryScreenState();
}

class _FarmerInventoryScreenState extends State<FarmerInventoryScreen> {
  List<dynamic> _listings = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _statsLoading = true;
  String _farmerPhone = "";

  final _ugx = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    _farmerPhone = prefs.getString('userPhone') ?? "";

    if (_farmerPhone.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statsLoading = false;
        });
      }
      _showErrorDialog('Session expired. Please log out and log in again.');
      return;
    }

    await Future.wait([_loadListings(), _loadStats()]);
  }

  Future<void> _loadListings() async {
    if (mounted) setState(() => _isLoading = true);

    final data = await ApiService.fetchFarmerProduce(_farmerPhone);

    if (mounted) {
      setState(() {
        _listings = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _statsLoading = true);

    final data = await ApiService.fetchFarmerStats(_farmerPhone);

    if (mounted) {
      setState(() {
        _stats = data;
        _statsLoading = false;
      });
    }
  }

  Future<void> _openAddCrop() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCropScreen()),
    );
    await _loadAll();
  }

  void _confirmDelete(int index) {
    final item = _listings[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cropName = (item['name'] ?? item['crop_type'] ?? 'Unknown')
        .toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade600.withOpacity(0.12),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete listing?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF111B15),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Remove "$cropName" from the marketplace? Buyers will no longer see this listing.',
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            height: 1.55,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteListing(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteListing(int index) async {
    final item = _listings[index];
    final rawProduceId = item['id'];

    if (rawProduceId == null) {
      _showErrorDialog('This produce item has no valid ID.');
      return;
    }

    final produceId = int.tryParse(rawProduceId.toString());
    if (produceId == null) {
      _showErrorDialog('Invalid produce ID: $rawProduceId');
      return;
    }

    setState(() => _listings.removeAt(index));

    final response = await ApiService.deleteProduce(produceId, _farmerPhone);
    debugPrint('DELETE RESPONSE: $response');

    if (!mounted) return;

    if (response['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Listing removed successfully.'),
            ],
          ),
          backgroundColor: _kGreenMid,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      await _loadAll();
    } else {
      setState(() => _listings.insert(index, item));
      _showErrorDialog(response['message'] ?? 'Failed to delete listing.');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade600),
            const SizedBox(width: 10),
            Text(
              'Error',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCrop(String name) {
    switch (name.toLowerCase()) {
      case 'maize':
        return Icons.grass_rounded;
      case 'beans':
        return Icons.spa_rounded;
      case 'tomatoes':
        return Icons.eco_rounded;
      case 'matooke':
        return Icons.park_rounded;
      case 'cassava':
        return Icons.energy_savings_leaf_rounded;
      default:
        return Icons.local_florist_rounded;
    }
  }

  String _harvestLabel(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final d = DateTime.parse(isoDate);
      final days = DateTime.now().difference(d).inDays;
      if (days == 0) return 'Harvested today';
      if (days == 1) return 'Harvested yesterday';
      return 'Harvested $days days ago';
    } catch (_) {
      return '';
    }
  }

  Widget _glassPanel({
    required Widget child,
    required bool isDark,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    BorderRadius? radius,
  }) {
    final borderRadius = radius ?? BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.74),
            borderRadius: borderRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.75),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.22)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
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
    return _glassPanel(
      isDark: isDark,
      radius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
          const SizedBox(width: 12),
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
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
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

  Widget _buildHeroSectionBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalListings = (_stats['total_listings'] ?? _listings.length)
        .toString();
    final pendingOrders = (_stats['pending_orders'] ?? 0).toString();
    final totalEarned = _ugx.format(_stats['total_earned_ugx'] ?? 0);

    return SafeArea(
      bottom: false,
      child: Padding(
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
                      const Color(0xFFF8FFF8),
                      Color(0xFFE8F5E9),
                      Color(0xFFFFF3E0),
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
                top: -16,
                right: -12,
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
                bottom: -28,
                left: -8,
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
                    _glassPanel(
                      isDark: isDark,
                      radius: BorderRadius.circular(24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            color: Colors.orange.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stock Control Center',
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
                    const SizedBox(height: 22),
                    Text(
                      'Farm Inventory',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF111B15),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _listings.isNotEmpty
                          ? '${_listings.length} active listing${_listings.length == 1 ? '' : 's'} ready for buyers right now.'
                          : 'Build your market shelf by adding fresh harvest listings buyers can discover instantly.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        fontSize: 13.2,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _heroMetric(
                            isDark: isDark,
                            label: 'Listings',
                            value: totalListings,
                            accent: Colors.green.shade700,
                            icon: Icons.inventory_2_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _heroMetric(
                            isDark: isDark,
                            label: 'Pending',
                            value: pendingOrders,
                            accent: Colors.orange.shade600,
                            icon: Icons.notifications_active_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _heroMetric(
                      isDark: isDark,
                      label: 'Total Earned',
                      value: 'UGX $totalEarned',
                      accent: Colors.green.shade700,
                      icon: Icons.paid_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
      child: Row(
        children: [
          Text(
            'Available Produce',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF111B15),
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(width: 10),
          if (_listings.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.green.shade700.withOpacity(0.16)
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_listings.length}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Text(
        'Manage your available harvest and keep your market shelf fresh.',
        style: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          fontSize: 13.2,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildLoadingSliver() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 0.75),
            duration: Duration(milliseconds: 700 + i * 80),
            builder: (_, op, __) => Opacity(
              opacity: op,
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                height: 132,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.04),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.22)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
          childCount: 4,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // TOLERANT LISTING CARD (handles multiple field name variations + price parsing)
  // ------------------------------------------------------------------
  Widget _buildListingCard(int index) {
    final item = _listings[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Flexible image URL extraction
    final List? urls =
        (item['imageUrls'] ??
                item['imageurls'] ??
                item['image_urls'] ??
                item['images'])
            as List?;
    final String? imageUrl = urls != null && urls.isNotEmpty
        ? urls.first.toString()
        : null;

    // Flexible field names
    final cropName = (item['name'] ?? item['crop_type'] ?? 'Unknown')
        .toString();
    final quantity = (item['quantity'] ?? 0).toString();

    // ✅ FIXED PRICE PARSING (handles decimal values like 8000.0, 500.0, 200.0)
    final num price = item['price'] is num
        ? item['price']
        : (num.tryParse('${item['price'] ?? 0}') ?? 0);

    final harvestText = _harvestLabel(
      (item['harvestDate'] ?? item['harvest_date'] ?? item['created_at'])
          ?.toString(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
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
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700, const Color(0xFF80C89A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Container(
                width: 92,
                margin: const EdgeInsets.fromLTRB(14, 14, 0, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: isDark
                                  ? Colors.grey.shade900
                                  : _kGreenLight,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _kGreenMid.withOpacity(0.5),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              _cropIconPlaceholder(cropName, isDark),
                        )
                      : _cropIconPlaceholder(cropName, isDark),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 8, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cropName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111B15),
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(
                            '$quantity kg/bunch',
                            isDark ? _kAmber.withOpacity(0.20) : _kAmberLight,
                            _kAmber,
                            Icons.scale_outlined,
                          ),
                          // ✅ Updated price chip with "/ kg"
                          _chip(
                            'UGX ${_ugx.format(price)} / kg',
                            isDark
                                ? _kGreenMid.withOpacity(0.20)
                                : _kGreenLight,
                            _kGreenMid,
                            Icons.payments_outlined,
                          ),
                        ],
                      ),
                      if (harvestText.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.eco_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                harvestText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 14, 16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: InkWell(
                    onTap: () => _confirmDelete(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.red.withOpacity(0.12)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.red.withOpacity(0.22)
                              : Colors.red.shade100,
                        ),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cropIconPlaceholder(String cropName, bool isDark) {
    return Container(
      color: isDark ? Colors.grey.shade900 : _kGreenLight,
      child: Center(
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kGreenMid.withOpacity(0.14),
            border: Border.all(color: _kGreenMid.withOpacity(0.22)),
          ),
          child: Icon(_getIconForCrop(cropName), size: 30, color: _kGreenMid),
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // SIMPLIFIED EMPTY STATE (no LayoutBuilder/SingleChildScrollView)
  // ------------------------------------------------------------------
  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _glassPanel(
              isDark: isDark,
              radius: BorderRadius.circular(28),
              padding: const EdgeInsets.all(22),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade700.withOpacity(0.14),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 34,
                  color: Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No listings yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111B15),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap Add Crop to list your first harvest and make it visible to buyers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 13.2,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF6F8F5);

    return Scaffold(
      backgroundColor: scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddCrop,
        backgroundColor: _kGreenMid,
        elevation: 0,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Add Crop',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: _kGreenMid,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeroSectionBox()),
            SliverToBoxAdapter(child: _buildSectionHeader()),
            SliverToBoxAdapter(child: _buildSubHeader()),
            if (_isLoading)
              _buildLoadingSliver()
            else if (_listings.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildListingCard(i),
                    childCount: _listings.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
