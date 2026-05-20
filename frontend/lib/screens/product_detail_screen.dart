import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'chat_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map item;

  const ProductDetailScreen({super.key, required this.item});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final PageController _pageController = PageController();

  String _buyerPhone = "";
  bool _isSending = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBuyerPhone();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBuyerPhone() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _buyerPhone = prefs.getString('userPhone') ?? "";
    });
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
      case 'tomatoes':
      case 'onions':
      case 'cabbage':
      case 'dodo (amaranth)':
      case 'eggplants':
      case 'green pepper':
      case 'carrots':
        return Icons.eco_rounded;
      case 'matooke':
      case 'bananas (bogoya)':
        return Icons.park_rounded;
      case 'cassava':
      case 'sweet potatoes':
      case 'irish potatoes':
      case 'yams':
        return Icons.energy_savings_leaf_rounded;
      case 'mangoes':
      case 'pineapples':
      case 'watermelon':
      case 'avocado':
      case 'passion fruits':
        return Icons.apple_rounded;
      default:
        return Icons.local_florist_rounded;
    }
  }

  String _formatUgx(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    final whole = number.toStringAsFixed(0);
    final chars = whole.split('').reversed.toList();
    final buffer = StringBuffer();

    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(chars[i]);
    }

    return buffer.toString().split('').reversed.join();
  }

  int? _produceId() {
    final rawId = widget.item['id'] ?? widget.item['produce_id'];
    return int.tryParse((rawId ?? '').toString());
  }

  List<String> _extractImageUrls() {
    final dynamic raw =
        widget.item['imageUrls'] ??
        widget.item['imageurls'] ??
        widget.item['image_urls'] ??
        widget.item['images'];

    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      return [raw.trim()];
    }

    return [];
  }

  String _cropName() {
    return (widget.item['name'] ?? widget.item['crop_type'] ?? 'Produce')
        .toString();
  }

  String _farmerName() {
    final value = widget.item['farmer'] ?? widget.item['farmer_name'];
    if (value == null || value.toString().trim().isEmpty) {
      return "Verified SAMS Farmer";
    }
    return value.toString();
  }

  String _farmerPhone() {
    return (widget.item['farmer_phone'] ??
            widget.item['phone'] ??
            widget.item['farmerPhone'] ??
            '')
        .toString();
  }

  String _description() {
    final value = widget.item['description'] ?? widget.item['details'];
    if (value == null || value.toString().trim().isEmpty) {
      return "No additional harvest details were provided by the farmer for this listing.";
    }
    return value.toString();
  }

  String _quantityText() {
    return (widget.item['quantity'] ?? widget.item['stock'] ?? '0').toString();
  }

  void _openChat({
    required String farmerPhone,
    required String farmerName,
    required String cropName,
    bool replace = false,
  }) {
    if (_buyerPhone.isEmpty || farmerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chat is unavailable right now. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final route = MaterialPageRoute(
      builder: (_) => ChatScreen(
        currentPhone: _buyerPhone,
        contactPhone: farmerPhone,
        contactName: farmerName,
        produceId: _produceId(),
        orderId: null,
        title: cropName,
        isBuyer: true,
      ),
    );

    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }

  void _addToCart() {
    CartService.addToCart(Map<String, dynamic>.from(widget.item));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_cropName()} added to your cart'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    Navigator.pop(context);
  }

  Widget _buildFallbackHeader(bool isDark) {
    final green = Colors.green.shade700;
    final greenDeep = isDark ? const Color(0xFF0D3320) : Colors.green.shade900;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [green, greenDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _getIconForCrop(_cropName()),
          size: 110,
          color: Colors.white.withOpacity(0.92),
        ),
      ),
    );
  }

  void _viewImageFullScreen(int initialIndex, List<String> imageUrls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _sendInlineMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _buyerPhone.isEmpty || _isSending) return;

    final farmerPhone = _farmerPhone();
    if (farmerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Farmer contact is unavailable for this listing.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final farmerName = _farmerName();
    final cropName = _cropName();

    final fullMessage =
        "Hi $farmerName, regarding your $cropName listing: $text";

    setState(() => _isSending = true);

    final response = await ApiService.sendMessage(
      _buyerPhone,
      farmerPhone,
      fullMessage,
    );

    if (!mounted) return;

    setState(() => _isSending = false);

    final bool success =
        response['success'] == true || response['status'] == 'success';

    if (success) {
      _msgController.clear();
      _openChat(
        farmerPhone: farmerPhone,
        farmerName: farmerName,
        cropName: cropName,
        replace: true,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Failed to send message.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildInfoChip({
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.14) : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? color.withOpacity(0.20) : color.withOpacity(0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.30)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA);
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final softSurface =
        isDark ? const Color(0xFF171717) : const Color(0xFFF2F4F5);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);

    final green = Colors.green.shade700;
    final orange = Colors.orange.shade600;

    final cropName = _cropName();
    final farmerName = _farmerName();
    final farmerPhone = _farmerPhone();
    final description = _description();
    final quantityText = _quantityText();
    final priceText = _formatUgx(widget.item['price']);
    final List<String> imageUrls = _extractImageUrls();
    final bool hasImages = imageUrls.isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.34)
                    : Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.025),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'UGX $priceText / kg',
                        style: TextStyle(
                          color: orange,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$quantityText kg available',
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _addToCart,
                    icon: const Icon(
                      Icons.add_shopping_cart_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 360,
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  hasImages
                      ? PageView.builder(
                          controller: _pageController,
                          itemCount: imageUrls.length,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () =>
                                  _viewImageFullScreen(index, imageUrls),
                              child: Image.network(
                                imageUrls[index],
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: isDark
                                        ? Colors.grey.shade900
                                        : Colors.green.shade50,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) =>
                                    _buildFallbackHeader(isDark),
                              ),
                            );
                          },
                        )
                      : _buildFallbackHeader(isDark),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.08),
                          Colors.black.withOpacity(0.55),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 26,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.24),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildInfoChip(
                                    isDark: true,
                                    icon: Icons.eco_rounded,
                                    label: '$quantityText kg available',
                                    color: const Color(0xFFFFC978),
                                  ),
                                  _buildInfoChip(
                                    isDark: true,
                                    icon: Icons.verified_rounded,
                                    label: 'Verified listing',
                                    color: const Color(0xFF8BE0A8),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                cropName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.storefront_rounded,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.80),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      farmerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.86),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'UGX $priceText / kg',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD180),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hasImages && imageUrls.length > 1)
                    Positioned(
                      right: 18,
                      top: MediaQuery.of(context).padding.top + 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.38),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1}/${imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Listing Snapshot',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? green.withOpacity(0.10)
                                      : green.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark
                                        ? green.withOpacity(0.22)
                                        : green.withOpacity(0.14),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.payments_outlined,
                                      color: green,
                                      size: 18,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'UGX $priceText',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Price per kilogram',
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? orange.withOpacity(0.10)
                                      : orange.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark
                                        ? orange.withOpacity(0.22)
                                        : orange.withOpacity(0.14),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      color: orange,
                                      size: 18,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '$quantityText kg',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Available quantity',
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Harvest Details',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? green.withOpacity(0.08)
                                : green.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? green.withOpacity(0.18)
                                  : green.withOpacity(0.12),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: green.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.format_quote_rounded,
                                  color: green,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  description,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.green.shade100
                                        : Colors.green.shade900,
                                    fontSize: 14.2,
                                    height: 1.6,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About the Farmer',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    green.withOpacity(0.90),
                                    orange.withOpacity(0.85),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farmerName,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 16,
                                        color: Colors.blue.shade500,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'Verified SAMS Market Partner',
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (farmerPhone.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      farmerPhone,
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask the Farmer',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a direct question about freshness, pickup, delivery, or harvest timing.',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 13.2,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: softSurface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _msgController,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14.2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 3,
                                  minLines: 1,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Is this ready for pickup this week?',
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade500,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: _isSending ? null : _sendInlineMessage,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: _isSending ? green : orange,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_isSending ? green : orange)
                                              .withOpacity(0.24),
                                          blurRadius: 14,
                                          offset: const Offset(0, 7),
                                        ),
                                      ],
                                    ),
                                    child: _isSending
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (farmerPhone.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: _buyerPhone.isEmpty
                                ? null
                                : () {
                                    _openChat(
                                      farmerPhone: farmerPhone,
                                      farmerName: farmerName,
                                      cropName: cropName,
                                    );
                                  },
                            icon: Icon(
                              Icons.forum_outlined,
                              color: green,
                              size: 18,
                            ),
                            label: Text(
                              'Open full chat',
                              style: TextStyle(
                                color: green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: green.withOpacity(0.32)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hasImages && imageUrls.length > 1) ...[
                    const SizedBox(height: 16),
                    Text(
                      'More Photos',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: imageUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, index) {
                          final selected = index == _currentImageIndex;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 92,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected ? orange : borderColor,
                                  width: selected ? 2 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: orange.withOpacity(0.20),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(17),
                                child: Image.network(
                                  imageUrls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: isDark
                                        ? Colors.grey.shade900
                                        : Colors.orange.shade50,
                                    child: Icon(
                                      _getIconForCrop(cropName),
                                      color: orange,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenGallery({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.18),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_current + 1}/${widget.imageUrls.length}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() => _current = index);
        },
        itemBuilder: (_, index) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.imageUrls[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white54,
                  size: 72,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}