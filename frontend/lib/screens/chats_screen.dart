import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String _currentPhone = '';
  bool _isLoading = true;

  List<dynamic> _buyerOrders = [];
  Map<String, int> _unreadCounts = {};
  Map<String, String> _contactNames = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? '';

    if (phone.isEmpty) {
      if (!mounted) return;
      setState(() {
        _currentPhone = '';
        _buyerOrders = [];
        _unreadCounts = {};
        _contactNames = {};
        _isLoading = false;
      });
      return;
    }

    final orders = await ApiService.fetchBuyerOrders(phone);
    final unread = await ApiService.fetchUnreadCounts(phone);

    final Map<String, String> names = {};
    for (final order in orders) {
      final farmerPhone = (order['farmer_phone'] ?? '').toString();
      final farmerName = (order['farmer_name'] ?? 'Farmer').toString();

      if (farmerPhone.isNotEmpty) {
        names[farmerPhone] = farmerName;
      }
    }

    if (!mounted) return;
    setState(() {
      _currentPhone = phone;
      _buyerOrders = orders;
      _unreadCounts = unread;
      _contactNames = names;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _chatContacts {
    final Map<String, Map<String, dynamic>> uniqueContacts = {};

    for (final order in _buyerOrders) {
      final farmerPhone = (order['farmer_phone'] ?? '').toString();
      if (farmerPhone.isEmpty) continue;

      uniqueContacts[farmerPhone] = {
        'phone': farmerPhone,
        'name': _contactNames[farmerPhone] ?? 'Farmer',
        'orderId': order['id'],
        'produceId': order['produce_id'],
        'title': order['produce_name']?.toString() ?? 'Order Chat',
        'unreadCount': _unreadCounts[farmerPhone] ?? 0,
      };
    }

    final contacts = uniqueContacts.values.toList();

    contacts.sort((a, b) {
      final unreadA = (a['unreadCount'] ?? 0) as int;
      final unreadB = (b['unreadCount'] ?? 0) as int;
      return unreadB.compareTo(unreadA);
    });

    return contacts;
  }

  Future<void> _openChat(Map<String, dynamic> contact) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentPhone: _currentPhone,
          contactPhone: contact['phone'].toString(),
          contactName: contact['name'].toString(),
          orderId: contact['orderId'] as int?,
          produceId: contact['produceId'] as int?,
          title: contact['title']?.toString(),
          isBuyer: true,
        ),
      ),
    );

    await _loadChats();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Chats'),
        centerTitle: true,
        elevation: 0.6,
      ),
      body: RefreshIndicator(
        onRefresh: _loadChats,
        child: _isLoading
            ? ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                itemBuilder: (_, __) => Container(
                  height: 78,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              )
            : _chatContacts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: isDark
                            ? Colors.green.shade700.withOpacity(0.16)
                            : Colors.green.shade50,
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 30,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No chats yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your conversations with farmers will appear here after you place an order or open a chat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _chatContacts[index];
                      final unread = (contact['unreadCount'] ?? 0) as int;

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openChat(contact),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.18 : 0.04,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: isDark
                                    ? Colors.green.shade700.withOpacity(0.18)
                                    : Colors.green.shade50,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact['name'].toString(),
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
                                      contact['title']?.toString() ?? 'Chat',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (unread > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade600,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    unread > 99 ? '99+' : '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: subTextColor,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}