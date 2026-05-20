import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _allOrders = [];
  Map<String, int> _unreadCounts = {};
  bool _isLoading = true;
  bool _isCancelling = false;
  String _buyerPhone = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _safeText(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _normalizedStatus(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  String _displayStatus(dynamic value) {
    switch (_normalizedStatus(value)) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'delivered':
        return 'Delivered';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  // ✅ UPDATED: Caching logic implemented here
  Future<void> _loadOrders({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _buyerPhone = prefs.getString('userPhone') ?? "";

    if (_buyerPhone.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allOrders = [];
          _unreadCounts = {};
        });
      }
      return;
    }

    if (!forceRefresh) {
      final cached = await ApiService.getCachedBuyerOrders(_buyerPhone);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _allOrders = cached;
          _isLoading = false;
        });
      }
    }

    final orders = await ApiService.fetchBuyerOrders(_buyerPhone);
    final unread = await ApiService.fetchUnreadCounts(_buyerPhone);

    if (!mounted) return;

    setState(() {
      if (orders.isNotEmpty) _allOrders = orders;
      _unreadCounts = unread;
      _isLoading = false;
    });

    await ApiService.cacheBuyerOrders(_buyerPhone, _allOrders);
  }

  List<dynamic> _activeOrders() {
    return _allOrders.where((o) {
      final status = _normalizedStatus(o['status']);
      return status == 'pending' || status == 'accepted';
    }).toList();
  }

  List<dynamic> _historyOrders() {
    return _allOrders.where((o) {
      final status = _normalizedStatus(o['status']);
      return ['completed', 'rejected', 'delivered', 'cancelled']
          .contains(status);
    }).toList();
  }

  Future<void> _cancelOrder(int orderId) async {
    if (_isCancelling) return;

    final oldOrders = List<Map<String, dynamic>>.from(
      _allOrders.map((e) => Map<String, dynamic>.from(e as Map)),
    );

    setState(() {
      _isCancelling = true;
      final idx = _allOrders.indexWhere((o) => o['order_id'] == orderId);
      if (idx != -1) {
        _allOrders[idx]['status'] = 'Cancelled';
      }
    });

    final response = await ApiService.cancelOrder(orderId, _buyerPhone);

    if (!mounted) return;

    if (response['status'] == 'success') {
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ?? 'Order cancelled successfully.',
          ),
          backgroundColor: Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // ✅ Force refresh on successful cancel
      await _loadOrders(forceRefresh: true);
    } else {
      setState(() {
        _allOrders = oldOrders;
        _isCancelling = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Failed to cancel order.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCancelDialog(int orderId, String cropName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Cancel Order?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            'Are you sure you want to cancel your order for $cropName? This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Keep Order',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _cancelOrder(orderId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Cancel Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openChatForOrder(Map<String, dynamic> order) async {
    final int orderId = int.tryParse((order['order_id'] ?? '0').toString()) ?? 0;
    final String farmerName =
        _safeText(order['farmer_name'], fallback: 'Farmer');
    final String farmerPhone =
        _safeText(order['farmer_phone'], fallback: '');
    final String cropName =
        _safeText(order['crop_name'], fallback: 'Unknown crop');
    final int? produceId =
        int.tryParse((order['produce_id'] ?? '').toString());

    if (_buyerPhone.isEmpty || farmerPhone.isEmpty || farmerPhone == '—') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chat is unavailable for this order right now.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentPhone: _buyerPhone,
          contactPhone: farmerPhone,
          contactName: farmerName,
          orderId: orderId,
          produceId: produceId,
          title: cropName,
          isBuyer: true,
        ),
      ),
    );

    // ✅ Force refresh when coming back from chat to update unread counts
    await _loadOrders(forceRefresh: true);
  }

  Color _pageBg(bool isDark) {
    return isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA);
  }

  Color _surfaceColor(bool isDark) {
    return isDark ? const Color(0xFF1E1E1E) : Colors.white;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green.shade700;
      case 'rejected':
      case 'cancelled':
        return Colors.red.shade700;
      case 'pending':
        return Colors.orange.shade700;
      case 'completed':
      case 'delivered':
        return Colors.green.shade800;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _statusBg(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return isDark
            ? Colors.green.shade900.withOpacity(0.22)
            : Colors.green.shade50;
      case 'rejected':
      case 'cancelled':
        return isDark
            ? Colors.red.shade900.withOpacity(0.22)
            : Colors.red.shade50;
      case 'pending':
        return isDark
            ? Colors.orange.shade900.withOpacity(0.22)
            : Colors.orange.shade50;
      case 'completed':
      case 'delivered':
        return isDark
            ? Colors.green.shade900.withOpacity(0.18)
            : Colors.green.shade50;
      default:
        return isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle_rounded;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'pending':
        return Icons.hourglass_bottom_rounded;
      case 'completed':
      case 'delivered':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Widget _statusPill(String status, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusBg(status, isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _statusColor(status).withOpacity(0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(status),
            size: 13,
            color: _statusColor(status),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              color: _statusColor(status),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.20 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard(int i) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.75),
      duration: Duration(milliseconds: 700 + (i * 80)),
      builder: (_, op, __) {
        return Opacity(
          opacity: op,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            height: 168,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String rawStatus = _displayStatus(order['status']);
    final int orderId = int.tryParse((order['order_id'] ?? '0').toString()) ?? 0;
    final String farmerName =
        _safeText(order['farmer_name'], fallback: 'Farmer');
    final String farmerPhone =
        _safeText(order['farmer_phone'], fallback: '');
    final String cropName =
        _safeText(order['crop_name'], fallback: 'Unknown crop');
    final String timestamp =
        _safeText(order['timestamp'], fallback: 'Recent order');
    final dynamic amount = order['total_amount'] ?? 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isPending = rawStatus == 'Pending';
    final bool isAccepted = rawStatus == 'Accepted';
    final bool isHistory =
        ['Completed', 'Rejected', 'Delivered', 'Cancelled'].contains(rawStatus);
    final bool canChat =
        ['Accepted', 'Completed', 'Delivered'].contains(rawStatus) &&
            farmerPhone.isNotEmpty &&
            farmerPhone != '—' &&
            _buyerPhone.isNotEmpty;

    final int unreadCount = _unreadCounts[farmerPhone] ?? 0;

    final Color glowColor = isPending
        ? Colors.orange.shade600.withOpacity(isDark ? 0.28 : 0.16)
        : isAccepted
            ? Colors.green.shade600.withOpacity(isDark ? 0.24 : 0.12)
            : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E1E)
            : (isHistory ? Colors.grey.shade50 : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 22,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPending
                        ? [Colors.orange.shade600, Colors.orange.shade400]
                        : isAccepted
                            ? [Colors.green.shade700, Colors.green.shade400]
                            : [Colors.grey.shade500, Colors.grey.shade400],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #$orderId',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          _statusPill(rawStatus, isDark),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.orange.shade700.withOpacity(0.18)
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.shopping_basket_rounded,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cropName,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF111827),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'UGX ${amount.toString()}',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isDark
                                ? Colors.green.shade700.withOpacity(0.18)
                                : Colors.green.shade50,
                            child: Text(
                              farmerName.isNotEmpty
                                  ? farmerName[0].toUpperCase()
                                  : 'F',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  farmerName,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF111827),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  farmerPhone.isEmpty || farmerPhone == '—'
                                      ? 'No phone available'
                                      : farmerPhone,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canChat)
                            GestureDetector(
                              onTap: () => _openChatForOrder(order),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade700,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.shade700
                                              .withOpacity(0.28),
                                          blurRadius: 14,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      right: -6,
                                      top: -6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.shade600
                                                  .withOpacity(0.28),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '$unreadCount',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              timestamp,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade500,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isPending) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isCancelling
                                ? null
                                : () => _showCancelDialog(orderId, cropName),
                            icon: Icon(
                              Icons.cancel_outlined,
                              size: 16,
                              color: Colors.red.shade400,
                            ),
                            label: Text(
                              'Cancel Order',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.red.withOpacity(0.30)
                                    : Colors.red.shade100,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildEmptyState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.orange.shade700.withOpacity(0.14)
                  : Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Colors.orange.shade700),
          ),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            fontSize: 13,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<dynamic> orders, {required bool activeTab}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: 5,
        itemBuilder: (_, i) => _buildShimmerCard(i),
      );
    }

    if (orders.isEmpty) {
      return RefreshIndicator(
        // ✅ FIXED: Force true network refresh on pull
        onRefresh: () => _loadOrders(forceRefresh: true),
        color: Colors.orange.shade700,
        child: _buildEmptyState(
          isDark: isDark,
          icon: activeTab
              ? Icons.hourglass_empty_rounded
              : Icons.receipt_long_outlined,
          title: activeTab ? 'No active orders' : 'No order history yet',
          message: activeTab
              ? 'Orders that are pending or accepted will appear here.'
              : 'Completed, rejected, delivered, and cancelled orders will appear here.',
        ),
      );
    }

    return RefreshIndicator(
      // ✅ FIXED: Force true network refresh on pull
      onRefresh: () => _loadOrders(forceRefresh: true),
      color: Colors.orange.shade700,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: orders.length,
        itemBuilder: (_, i) =>
            _buildOrderCard(Map<String, dynamic>.from(orders[i] as Map)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _activeOrders().length;
    final historyCount = _historyOrders().length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _pageBg(isDark),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surfaceColor(isDark),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
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
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buyer Orders',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Track actions, chat with farmers, and manage purchases.',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _headerStat(
                        isDark: isDark,
                        icon: Icons.pending_actions_rounded,
                        label: 'Active',
                        value: '$activeCount',
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 12),
                      _headerStat(
                        isDark: isDark,
                        icon: Icons.history_rounded,
                        label: 'History',
                        value: '$historyCount',
                        color: Colors.green.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF141414)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.30 : 0.05,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: isDark
                          ? Colors.orangeAccent.shade200
                          : Colors.orange.shade700,
                      unselectedLabelColor: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Active'),
                              if (activeCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.orange.shade700
                                            .withOpacity(0.20)
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$activeCount',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('History'),
                              if (historyCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.green.shade700
                                            .withOpacity(0.20)
                                        : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$historyCount',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrderList(_activeOrders(), activeTab: true),
                  _buildOrderList(_historyOrders(), activeTab: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}