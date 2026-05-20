import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cart_service.dart';
import '../services/api_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = false;

  void _incrementQty(int index) {
    final item = CartService.items[index];
    final int maxQty = (item['quantity'] as num).toInt();
    final int currentQty = item['cartQty'] as int;

    if (currentQty >= maxQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only $maxQty kg of ${item['name']} available.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => CartService.items[index]['cartQty'] += 1);
  }

  void _decrementQty(int index) {
    setState(() {
      if (CartService.items[index]['cartQty'] > 1) {
        CartService.items[index]['cartQty'] -= 1;
      }
    });
  }

  void _removeItem(int index) {
    final removed = CartService.items[index];
    setState(() => CartService.items.removeAt(index));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed['name']} removed from cart.'),
        backgroundColor: Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  double _calculateTotal() {
    double total = 0;
    for (var item in CartService.items) {
      final double price = double.tryParse(item['price'].toString()) ?? 0;
      final int qty = item['cartQty'] as int;
      total += price * qty;
    }
    return total;
  }

  int _totalItems() {
    int count = 0;
    for (var item in CartService.items) {
      count += (item['cartQty'] as int);
    }
    return count;
  }

  String _formatUgx(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    return number.toStringAsFixed(0);
  }

  Future<void> _placeOrder() async {
    if (CartService.items.isEmpty) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final buyerPhone = prefs.getString('userPhone') ?? '';

    if (buyerPhone.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error: Buyer not logged in'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final res = await ApiService.placeOrder(buyerPhone, CartService.items);

    setState(() => _isLoading = false);

    if (res['status'] == 'success') {
      setState(() => CartService.clear());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Order placed successfully!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to place order.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _pageBg(bool isDark) {
    return isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA);
  }

  Color _surfaceColor(bool isDark) {
    return isDark ? const Color(0xFF1E1E1E) : Colors.white;
  }

  String? _extractFirstImage(dynamic item) {
    if (item is! Map) return null;

    final dynamic rawImages = item['imageUrls'] ??
        item['imageurls'] ??
        item['image_urls'] ??
        item['images'] ??
        item['image_url'];

    if (rawImages is List && rawImages.isNotEmpty) {
      final first = rawImages.first.toString().trim();
      if (first.isNotEmpty && first.toLowerCase() != 'null') {
        if (first.startsWith('http')) return first;
        if (first.startsWith('/')) return '${ApiService.baseUrl}$first';
        return '${ApiService.baseUrl}/$first';
      }
    }

    if (rawImages is String && rawImages.trim().isNotEmpty) {
      final url = rawImages.trim();
      if (url.toLowerCase() != 'null') {
        if (url.startsWith('http')) return url;
        if (url.startsWith('/')) return '${ApiService.baseUrl}$url';
        return '${ApiService.baseUrl}/$url';
      }
    }

    return null;
  }

  Widget _glassCard({
    required bool isDark,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.24 : 0.06),
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.orange.shade700.withOpacity(0.12)
                    : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your cart is empty',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Browse the market and add fresh produce to start your order.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(dynamic item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final image = _extractFirstImage(item);
    final qty = item['cartQty'] ?? 1;
    final price = double.tryParse(item['price'].toString()) ?? 0;
    final total = price * qty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surfaceColor(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isDark ? Colors.grey.shade900 : Colors.orange.shade50,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: image != null
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.eco_rounded,
                          color: Colors.orange.shade700,
                          size: 34,
                        ),
                      )
                    : Icon(
                        Icons.eco_rounded,
                        color: Colors.orange.shade700,
                        size: 34,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              // ✅ FIXED: Completely eliminated the SizedBox(height: 88) here!
              // Now the column can stretch vertically as much as it needs to.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, 
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeItem(index),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 4),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade400,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'UGX ${_formatUgx(item['price'])} / kg',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => _decrementQty(index),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 18,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '$qty',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _incrementQty(index),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'UGX ${_formatUgx(total)}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final bottomPadding = MediaQuery.of(context).padding.bottom + 120;

    return SafeArea(
      bottom: false, 
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 32, 20, 0), 
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1A1A1A), const Color(0xFF101010)]
                        : [Colors.white, const Color(0xFFF8FBF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.04),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade600,
                            Colors.green.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.shopping_cart_checkout_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Cart',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_totalItems()} items ready for checkout',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, bottomPadding),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) => _buildCartItem(CartService.items[index], index),
                childCount: CartService.items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: _glassCard(
          isDark: isDark,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Amount',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    'UGX ${_formatUgx(_calculateTotal())}',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isLoading || CartService.items.isEmpty ? null : _placeOrder,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                        ),
                  label: Text(
                    _isLoading ? 'Placing Order...' : 'Place Order Securely',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    disabledBackgroundColor: Colors.orange.shade300,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _pageBg(isDark),
      body: CartService.items.isEmpty ? _buildEmptyState(isDark) : _buildCartContent(),
      bottomNavigationBar:
          CartService.items.isEmpty ? null : _buildCheckoutBar(),
    );
  }
}