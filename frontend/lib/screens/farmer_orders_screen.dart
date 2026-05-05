import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class FarmerOrdersScreen extends StatefulWidget {
  const FarmerOrdersScreen({super.key});

  @override
  State<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends State<FarmerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _allOrders = [];
  bool _isLoading = true;
  String _farmerPhone = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _farmerPhone = prefs.getString('userPhone') ?? "";

    if (_farmerPhone.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final orders = await ApiService.fetchFarmerOrders(_farmerPhone);
    if (mounted) {
      setState(() {
        _allOrders = orders;
        _isLoading = false;
      });
    }
  }

  List<dynamic> _filteredOrders(String status) {
    if (status == 'All') return _allOrders;
    return _allOrders.where((o) => o['status'] == status).toList();
  }

  Future<void> _handleOrderAction(int orderId, String newStatus) async {
    // Optimistic UI update — swap the status immediately so it feels instant
    setState(() {
      final idx = _allOrders.indexWhere((o) => o['order_id'] == orderId);
      if (idx != -1) _allOrders[idx]['status'] = newStatus;
    });

    final response = await ApiService.updateOrderStatus(
      orderId,
      newStatus,
      _farmerPhone,
    );

    if (!mounted) return;

    if (response['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: newStatus == 'Accepted'
              ? Colors.green.shade700
              : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Rollback the optimistic update if it failed
      _loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Action failed. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Accepted': return Colors.green.shade700;
      case 'Rejected': return Colors.red.shade700;
      case 'Pending':  return Colors.orange.shade700;
      default:         return Colors.grey.shade600;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'Accepted': return Colors.green.shade50;
      case 'Rejected': return Colors.red.shade50;
      case 'Pending':  return Colors.orange.shade50;
      default:         return Colors.grey.shade100;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Accepted': return Icons.check_circle_rounded;
      case 'Rejected': return Icons.cancel_rounded;
      case 'Pending':  return Icons.hourglass_empty_rounded;
      default:         return Icons.info_rounded;
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String status = order['status'] ?? 'Pending';
    final bool isPending = status == 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? Colors.orange.shade200 : Colors.grey.shade200,
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // --- CARD HEADER ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order['order_id']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 14, color: _statusColor(status)),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- CARD BODY ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Crop + Amount
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.eco_rounded, color: Colors.green.shade700, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['crop_name'] ?? 'Unknown crop',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'UGX ${order['total_amount'].toString()}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Buyer Info
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Buyer: ${order['buyer_name']}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      order['buyer_phone'] ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      order['timestamp'] ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),

                // --- ACTION BUTTONS (only for Pending orders) ---
                if (isPending) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      // REJECT
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showConfirmationDialog(
                            order['order_id'],
                            'Rejected',
                            order['buyer_name'],
                            order['crop_name'],
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ACCEPT
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showConfirmationDialog(
                            order['order_id'],
                            'Accepted',
                            order['buyer_name'],
                            order['crop_name'],
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                          label: const Text(
                            'Accept',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(
    int orderId,
    String action,
    String buyerName,
    String cropName,
  ) {
    final bool isAccepting = action == 'Accepted';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isAccepting ? 'Accept this order?' : 'Reject this order?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isAccepting
              ? 'You are confirming the order for $cropName from $buyerName. Your available stock will be updated.'
              : 'You are rejecting the order for $cropName from $buyerName. This cannot be undone.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleOrderAction(orderId, action);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAccepting ? Colors.green.shade700 : Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              isAccepting ? 'Yes, Accept' : 'Yes, Reject',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(String filter) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    final orders = _filteredOrders(filter);

    if (orders.isEmpty) {
      final messages = {
        'All':      ('No orders yet', 'When buyers place orders for your produce,\nthey will appear here.'),
        'Pending':  ('No pending orders', 'You\'re all caught up! Check back later.'),
        'Accepted': ('No accepted orders', 'Orders you confirm will appear here.'),
      };
      final msg = messages[filter] ?? ('Nothing here', '');

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                filter == 'Pending' ? Icons.hourglass_empty_rounded : Icons.receipt_long_outlined,
                size: 60,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                msg.$1,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                msg.$2,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _filteredOrders('Pending').length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Orders',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (pendingCount > 0)
              Text(
                '$pendingCount pending — needs your action',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.grey.shade700),
            onPressed: _loadOrders,
            tooltip: 'Refresh orders',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green.shade700,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('All'),
                  if (_allOrders.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_allOrders.length}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
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
                  const Text('Pending'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList('All'),
          _buildOrderList('Pending'),
          _buildOrderList('Accepted'),
        ],
      ),
    );
  }
}