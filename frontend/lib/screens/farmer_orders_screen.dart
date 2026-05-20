import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _PinnedTabBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFF6F8F5),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

class FarmerOrdersScreen extends StatefulWidget {
  const FarmerOrdersScreen({super.key});

  @override
  State<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends State<FarmerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();

  List<dynamic> _allOrders = [];
  bool _isLoading = true;
  bool _isActionLoading = false;
  String _farmerPhone = "";

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

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final prefs = await SharedPreferences.getInstance();
    _farmerPhone = prefs.getString('userPhone') ?? "";

    if (_farmerPhone.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final orders = await ApiService.fetchFarmerOrders(_farmerPhone);

    if (!mounted) return;

    setState(() {
      _allOrders = orders;
      _isLoading = false;
    });
  }

  List<dynamic> get _pendingOrders => _allOrders.where((o) {
        final status = (o['status'] ?? '').toString().trim().toLowerCase();
        return status == 'pending';
      }).toList();

  List<dynamic> get _historyOrders => _allOrders.where((o) {
        final status = (o['status'] ?? '').toString().trim().toLowerCase();
        return [
          'accepted',
          'rejected',
          'completed',
          'cancelled',
          'delivered',
        ].contains(status);
      }).toList();

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'completed':
      case 'delivered':
        return Colors.green.shade700;
      case 'rejected':
      case 'cancelled':
        return Colors.red.shade600;
      case 'pending':
      default:
        return Colors.orange.shade600;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'completed':
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'pending':
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  String _formatAmount(dynamic value) {
    final parsed = double.tryParse(value.toString()) ?? 0;
    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }
    return parsed.toStringAsFixed(0);
  }

  String _safeText(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<void> _handleOrderAction(int orderId, String newStatus) async {
    if (_isActionLoading) return;

    final oldOrders = List<Map<String, dynamic>>.from(
      _allOrders.map((e) => Map<String, dynamic>.from(e)),
    );

    setState(() {
      _isActionLoading = true;
      final index = _allOrders.indexWhere((o) => o['order_id'] == orderId);
      if (index != -1) {
        _allOrders[index]['status'] = newStatus;
      }
    });

    final response = await ApiService.updateOrderStatus(
      orderId,
      newStatus,
      _farmerPhone,
    );

    if (!mounted) return;

    if (response['status'] == 'success') {
      setState(() => _isActionLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ??
                (newStatus == 'Accepted'
                    ? 'Order accepted successfully.'
                    : 'Order rejected successfully.'),
          ),
          backgroundColor: newStatus == 'Accepted'
              ? Colors.green.shade700
              : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

      await _loadOrders();
    } else {
      setState(() {
        _allOrders = oldOrders;
        _isActionLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ?? 'Unable to update order status.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  void _showConfirmationDialog({
    required int orderId,
    required String action,
    required String buyerName,
    required String cropName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAccept = action == 'Accepted';
    final actionColor = isAccept ? Colors.green.shade700 : Colors.red.shade600;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                  color: actionColor.withOpacity(0.14),
                ),
                child: Icon(
                  isAccept
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: actionColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isAccept ? 'Accept order?' : 'Reject order?',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111B15),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            isAccept
                ? 'Confirm acceptance for $cropName ordered by $buyerName. The order will move out of pending status immediately.'
                : 'Reject the $cropName order from $buyerName. This action updates the order status and cannot be treated as pending again unless re-created.',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              fontSize: 13.5,
              height: 1.55,
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
              onPressed: () {
                Navigator.pop(ctx);
                _handleOrderAction(orderId, action);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isAccept ? 'Yes, Accept' : 'Yes, Reject',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openChatForOrder(Map<String, dynamic> order) {
    final int orderId = int.tryParse((order['order_id'] ?? '').toString()) ?? 0;
    final int? produceId =
        int.tryParse((order['produce_id'] ?? '').toString());
    final String buyerName = _safeText(order['buyer_name'], fallback: 'Buyer');
    final String buyerPhone = _safeText(order['buyer_phone'], fallback: '');
    final String cropName = _safeText(order['crop_name'], fallback: 'Produce');

    if (_farmerPhone.isEmpty || buyerPhone.isEmpty || buyerPhone == '—') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chat is unavailable for this order right now.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentPhone: _farmerPhone,
          contactPhone: buyerPhone,
          contactName: buyerName,
          orderId: orderId,
          produceId: produceId,
          title: cropName,
          isBuyer: false,
        ),
      ),
    );
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
    final pendingCount = _pendingOrders.length;
    final historyCount = _historyOrders.length;
    final totalSales = _allOrders.fold(0.0, (sum, order) {
      final status = (order['status'] ?? '').toString().toLowerCase();
      final valid = ['accepted', 'completed', 'delivered'].contains(status);
      final amount = double.tryParse(order['total_amount'].toString()) ?? 0;
      return valid ? sum + amount : sum;
    });

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
                      const Color(0xFFE8F5E9),
                      const Color(0xFFFFF3E0),
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
                            Icons.receipt_long_rounded,
                            color: Colors.orange.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Order Command Center',
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
                      'Farmer Orders',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF111B15),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount pending request${pendingCount == 1 ? '' : 's'} need your attention right now.'
                          : 'You are caught up. Review order history and completed transactions from one premium workspace.',
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
                            label: 'Pending',
                            value: '$pendingCount',
                            accent: Colors.orange.shade600,
                            icon: Icons.notifications_active_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _heroMetric(
                            isDark: isDark,
                            label: 'History',
                            value: '$historyCount',
                            accent: Colors.green.shade700,
                            icon: Icons.inventory_2_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _heroMetric(
                      isDark: isDark,
                      label: 'Confirmed Sales',
                      value: 'UGX ${_formatAmount(totalSales)}',
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

  Widget _buildSegmentedTabsBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingCount = _pendingOrders.length;
    final historyCount = _historyOrders.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(5),
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
                  ? Colors.black.withOpacity(0.20)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.green.shade700, Colors.green.shade800]
                  : [Colors.green.shade600, Colors.green.shade700],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade700.withOpacity(isDark ? 0.28 : 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor:
              isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Flexible(
                    child: Text(
                      'Pending',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Flexible(
                    child: Text(
                      'History',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (historyCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.12)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '$historyCount',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF111B15),
                          fontSize: 10,
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
    );
  }

  Widget _buildStatusPill(String status, bool isDark) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.12),
          ),
          child: Icon(icon, color: accent, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111B15),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingOrderCard(Map order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int orderId = int.tryParse(order['order_id'].toString()) ?? 0;
    final String buyerName =
        _safeText(order['buyer_name'], fallback: 'Unknown');
    final String buyerPhone = _safeText(order['buyer_phone']);
    final String cropName = _safeText(order['crop_name'], fallback: 'Produce');
    final String amount = _formatAmount(order['total_amount']);
    final String timestamp = _safeText(order['timestamp'], fallback: 'No time');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.orange.shade900.withOpacity(0.35),
                  const Color(0xFF1E1E1E),
                ]
              : [Colors.orange.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.shade600.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade600.withOpacity(isDark ? 0.18 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusPill('Pending', isDark),
                const Spacer(),
                Text(
                  'Order #$orderId',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              cropName,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111B15),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'UGX $amount',
              style: TextStyle(
                color: Colors.orange.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.05),
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.person_rounded,
              label: 'Buyer',
              value: buyerName,
              accent: Colors.blue.shade400,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.call_rounded,
              label: 'Phone',
              value: buyerPhone,
              accent: Colors.green.shade700,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.schedule_rounded,
              label: 'Placed',
              value: timestamp,
              accent: Colors.orange.shade600,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _showConfirmationDialog(
                              orderId: orderId,
                              action: 'Rejected',
                              buyerName: buyerName,
                              cropName: cropName,
                            ),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.red.shade400,
                    ),
                    label: Text(
                      'Reject',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: Colors.red.shade400.withOpacity(0.35),
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _showConfirmationDialog(
                              orderId: orderId,
                              action: 'Accepted',
                              buyerName: buyerName,
                              cropName: cropName,
                            ),
                    icon: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Accept Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      disabledBackgroundColor:
                          Colors.green.shade700.withOpacity(0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadowColor: Colors.green.shade700.withOpacity(0.3),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryOrderCard(Map order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String status = _safeText(order['status'], fallback: 'Completed');
    final int orderId = int.tryParse(order['order_id'].toString()) ?? 0;
    final String buyerName =
        _safeText(order['buyer_name'], fallback: 'Unknown');
    final String buyerPhone = _safeText(order['buyer_phone']);
    final String cropName = _safeText(order['crop_name'], fallback: 'Produce');
    final String amount = _formatAmount(order['total_amount']);
    final String timestamp = _safeText(order['timestamp'], fallback: 'No time');

    final bool canChat =
        ['accepted', 'completed', 'delivered'].contains(status.toLowerCase()) &&
            buyerPhone != '—' &&
            buyerPhone.isNotEmpty &&
            _farmerPhone.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
                ? Colors.black.withOpacity(0.18)
                : Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusPill(status, isDark),
                const Spacer(),
                Text(
                  'Order #$orderId',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              cropName,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111B15),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'UGX $amount',
              style: TextStyle(
                color: _statusColor(status),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.person_outline_rounded,
              label: 'Buyer',
              value: buyerName,
              accent: Colors.blue.shade400,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: buyerPhone,
              accent: Colors.green.shade700,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.history_toggle_off_rounded,
              label: 'Updated',
              value: timestamp,
              accent: Colors.orange.shade600,
            ),
            if (canChat) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _openChatForOrder(Map<String, dynamic>.from(order)),
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Open Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
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
    );
  }

  Widget _buildEmptyState({required bool isDark, required bool pendingTab}) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                          color: (pendingTab
                                  ? Colors.orange.shade600
                                  : Colors.green.shade700)
                              .withOpacity(0.14),
                        ),
                        child: Icon(
                          pendingTab
                              ? Icons.inbox_rounded
                              : Icons.checklist_rounded,
                          size: 34,
                          color: pendingTab
                              ? Colors.orange.shade600
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      pendingTab
                          ? 'No pending orders right now'
                          : 'No completed or cancelled orders yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF111B15),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pendingTab
                          ? 'Fresh buyer requests will appear here the moment they are placed, so you can accept or reject them quickly.'
                          : 'Once you process buyer requests, accepted, rejected, completed, and cancelled orders will appear in this history view.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 13.2,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingSliver() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((_, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            height: 176,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.04),
              ),
            ),
            child: const SizedBox.expand(),
          );
        }, childCount: 4),
      ),
    );
  }

  Widget _buildPendingTabContent() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return CustomScrollView(
          key: const PageStorageKey('farmer-pending-orders'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            if (_isLoading)
              _buildLoadingSliver()
            else if (_pendingOrders.isEmpty)
              _buildEmptyState(isDark: isDark, pendingTab: true)
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, index) => _buildPendingOrderCard(_pendingOrders[index]),
                    childCount: _pendingOrders.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryTabContent() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return CustomScrollView(
          key: const PageStorageKey('farmer-history-orders'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            if (_isLoading)
              _buildLoadingSliver()
            else if (_historyOrders.isEmpty)
              _buildEmptyState(isDark: isDark, pendingTab: false)
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, index) => _buildHistoryOrderCard(_historyOrders[index]),
                    childCount: _historyOrders.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF121212) : const Color(0xFFF6F8F5);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(child: _buildHeroSectionBox()),
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedTabBarDelegate(
                  height: 74,
                  child: _buildSegmentedTabsBox(),
                ),
              ),
            ),
          ];
        },
        body: PageStorage(
          bucket: _pageStorageBucket,
          child: TabBarView(
            controller: _tabController,
            children: [
              RefreshIndicator(
                onRefresh: _loadOrders,
                color: Colors.green.shade700,
                child: _buildPendingTabContent(),
              ),
              RefreshIndicator(
                onRefresh: _loadOrders,
                color: Colors.green.shade700,
                child: _buildHistoryTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}