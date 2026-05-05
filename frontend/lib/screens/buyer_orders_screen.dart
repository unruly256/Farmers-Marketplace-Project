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
  bool _isLoading = true;
  String _buyerPhone = "";

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
    _buyerPhone = prefs.getString('userPhone') ?? "";

    if (_buyerPhone.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final orders = await ApiService.fetchBuyerOrders(_buyerPhone);
    if (mounted) {
      setState(() {
        _allOrders = orders;
        _isLoading = false;
      });
    }
  }

  List<dynamic> _filteredOrders(String filter) {
    switch (filter) {
      case 'Active':
        return _allOrders
            .where((o) => o['status'] == 'Pending' || o['status'] == 'Accepted')
            .toList();
      case 'Completed':
        return _allOrders.where((o) => o['status'] == 'Rejected').toList();
      default:
        return _allOrders;
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

  String _statusMessage(String status) {
    switch (status) {
      case 'Accepted': return 'Farmer confirmed your order! Arrange pickup.';
      case 'Rejected': return 'Farmer could not fulfill this order.';
      case 'Pending':  return 'Waiting for the farmer to respond...';
      default:         return '';
    }
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

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String status  = order['status'] ?? 'Pending';
    final bool isAccepted = status == 'Accepted';
    final bool isPending  = status == 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted
              ? Colors.green.shade200
              : isPending
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
          width: (isAccepted || isPending) ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade100, blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // --- HEADER ---
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
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
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _statusColor(status)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- BODY ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                      child: Icon(_getIconForCrop(order['crop_name'] ?? ''), color: Colors.green.shade700, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['crop_name'] ?? 'Unknown crop',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'UGX ${order['total_amount']}',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.orange.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Icon(Icons.agriculture_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Farmer: ${order['farmer_name']}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
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
                const SizedBox(height: 14),

                // --- STATUS BANNER ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(_statusIcon(status), size: 16, color: _statusColor(status)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage(status),
                          style: TextStyle(fontSize: 12, color: _statusColor(status), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- CHAT BUTTON (Pending + Accepted only) ---
                if (status != 'Rejected') ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              currentPhone: _buyerPhone,
                              contactPhone: order['farmer_phone'] ?? '00000',
                              contactName: order['farmer_name'] ?? 'Farmer',
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.green.shade700),
                      label: Text(
                        isAccepted ? 'Chat to arrange pickup' : 'Message the farmer',
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.green.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
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
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    final orders = _filteredOrders(filter);

    if (orders.isEmpty) {
      final msgs = {
        'All':       ('No orders yet', 'Your order history will appear here\nonce you buy from the marketplace.'),
        'Active':    ('No active orders', 'Place an order from the marketplace\nto get started!'),
        'Completed': ('No completed orders', 'Accepted and rejected orders\nwill appear here.'),
      };
      final msg = msgs[filter] ?? ('Nothing here', '');

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(msg.$1, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              Text(msg.$2, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: Colors.orange.shade700,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: orders.length,
        itemBuilder: (context, index) => _buildOrderCard(orders[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount   = _filteredOrders('Active').length;
    final acceptedCount = _allOrders.where((o) => o['status'] == 'Accepted').length;

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
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            if (acceptedCount > 0)
              Text(
                '$acceptedCount order${acceptedCount > 1 ? 's' : ''} accepted — ready for pickup!',
                style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w500),
              )
            else if (activeCount > 0)
              Text(
                '$activeCount pending — waiting on farmers',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.grey.shade700),
            onPressed: _loadOrders,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange.shade700,
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
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                      child: Text('${_allOrders.length}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Active'),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '$activeCount',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
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
                  const Text('Completed'),
                  if (acceptedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '$acceptedCount',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList('All'),
          _buildOrderList('Active'),
          _buildOrderList('Completed'),
        ],
      ),
    );
  }
}