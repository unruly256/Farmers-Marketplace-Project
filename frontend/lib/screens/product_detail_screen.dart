import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cart_service.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const ProductDetailScreen({super.key, required this.item});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  String _buyerPhone = "";
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadBuyerPhone();
  }

  Future<void> _loadBuyerPhone() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _buyerPhone = prefs.getString('userPhone') ?? "";
    });
  }

  IconData _getIconForCrop(String cropName) {
    switch (cropName.toLowerCase()) {
      case 'maize': return Icons.grass_rounded;
      case 'beans': return Icons.spa_rounded;
      case 'tomatoes': return Icons.eco_rounded;
      case 'matooke': return Icons.park_rounded;
      case 'cassava': return Icons.energy_savings_leaf_rounded;
      default: return Icons.local_florist_rounded;
    }
  }

  void _addToCart() {
    CartService.addToCart(widget.item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.item['name']} added to your cart!'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context); // Go back to dashboard after adding
  }

  void _sendInlineMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _buyerPhone.isEmpty) return;

    setState(() => _isSending = true);

    // Append the product context so the farmer knows what they are asking about
    final fullMessage = "Hi ${widget.item['farmer']}, regarding your ${widget.item['name']} listing: $text";

    bool success = await ApiService.sendMessage(
      _buyerPhone, 
      widget.item['farmer_phone'] ?? "00000", 
      fullMessage
    );

    setState(() => _isSending = false);

    if (success && mounted) {
      _msgController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Message sent to farmer!'), backgroundColor: Colors.green.shade700),
      );
      
      // Automatically slide them into the full chat screen to continue the conversation!
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ChatScreen(
        currentPhone: _buyerPhone,
        contactPhone: widget.item['farmer_phone'] ?? "00000",
        contactName: widget.item['farmer'],
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      
      // BOTTOM ACTION BAR
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ElevatedButton.icon(
          onPressed: _addToCart,
          icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
          label: Text('Add to Cart - UGX ${widget.item['price']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),

      body: CustomScrollView(
        slivers: [
          // PREMIUM HEADER
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.green.shade700,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade900],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Icon(_getIconForCrop(widget.item['name']), size: 120, color: Colors.white.withOpacity(0.9)),
                ),
              ),
            ),
          ),

          // PRODUCT & FARMER DETAILS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.item['name'], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                            child: Text('${widget.item['quantity']} kg Available', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                          ),
                        ],
                      ),
                      Text('UGX\n${widget.item['price']}', textAlign: TextAlign.right, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green.shade700)),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('About the Farmer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),
                  
                  // FARMER PROFILE CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 30, backgroundColor: Colors.green.shade100, child: Icon(Icons.person, size: 30, color: Colors.green.shade700)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.item['farmer'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.verified_rounded, size: 16, color: Colors.blue.shade600),
                                  const SizedBox(width: 4),
                                  Text('Verified SAMS Partner', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text('Ask the Farmer a Question', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),

                  // INLINE CHAT BOX
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Send a direct message about this ${widget.item['name']}:', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _msgController,
                                decoration: InputDecoration(
                                  hintText: 'Is this ready for pickup?',
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _isSending ? null : _sendInlineMessage,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(12)),
                                child: _isSending 
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}