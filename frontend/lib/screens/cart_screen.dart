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

  // --- QUANTITY STEPPER ---
  // Increments cartQty but hard-blocks it at the farmer's actual stock.
  void _incrementQty(int index) {
    final item = CartService.items[index];
    final int maxQty = (item['quantity'] as num).toInt(); // farmer's listed stock
    final int currentQty = item['cartQty'] as int;

    if (currentQty >= maxQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only $maxQty kg of ${item['name']} available. '
            'You\'ve already reached the maximum.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return; // Hard block — don't allow the increment
    }

    setState(() => CartService.items[index]['cartQty'] += 1);
  }

  // Decrements cartQty but removes the item if it hits 0.
  void _decrementQty(int index) {
    setState(() {
      if (CartService.items[index]['cartQty'] > 1) {
        CartService.items[index]['cartQty'] -= 1;
      } else {
        _removeItem(index);
      }
    });
  }

  void _removeItem(int index) {
    final String name = CartService.items[index]['name'];
    setState(() => CartService.items.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name removed from cart.'),
        backgroundColor: Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- PLACE ORDER ---
  // The backend will also validate stock as a second safety net.
  void _placeOrder() async {
    if (CartService.items.isEmpty) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    String phone = prefs.getString('userPhone') ?? "";

    final response = await ApiService.placeOrder(phone, CartService.items);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (response['status'] == 'success') {
      CartService.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      // The backend's stock guard error message is shown directly to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Order failed. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Cart',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CartService.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            "Your cart is empty",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Browse the marketplace to add produce.",
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: CartService.items.length,
                      itemBuilder: (context, index) {
                        final item = CartService.items[index];
                        final double pricePerUnit =
                            double.parse(item['price'].toString());
                        final int cartQty = item['cartQty'] as int;
                        final int maxQty = (item['quantity'] as num).toInt();
                        final double itemTotal = pricePerUnit * cartQty;
                        final bool atMaxStock = cartQty >= maxQty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              // Turns orange when buyer is at the stock ceiling
                              color: atMaxStock
                                  ? Colors.orange.shade300
                                  : Colors.grey.shade200,
                              width: atMaxStock ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.eco_rounded,
                                        color: Colors.green.shade700),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'From ${item['farmer']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // Stock ceiling warning label
                                        if (atMaxStock)
                                          Text(
                                            'Max stock reached ($maxQty kg)',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Remove button
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded,
                                        color: Colors.red.shade400, size: 20),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // --- QUANTITY STEPPER ---
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        // Decrement
                                        GestureDetector(
                                          onTap: () => _decrementQty(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(Icons.remove_rounded,
                                                size: 18,
                                                color: Colors.grey.shade700),
                                          ),
                                        ),
                                        // Quantity display
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            border: Border.symmetric(
                                              vertical: BorderSide(
                                                  color: Colors.grey.shade200),
                                            ),
                                          ),
                                          child: Text(
                                            '$cartQty kg',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        // Increment — greyed out at stock ceiling
                                        GestureDetector(
                                          onTap: () => _incrementQty(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.add_rounded,
                                              size: 18,
                                              color: atMaxStock
                                                  ? Colors.grey.shade300
                                                  : Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Line total
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'UGX ${itemTotal.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'UGX $pricePerUnit / kg',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // --- CHECKOUT BAR ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'UGX ${CartService.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || CartService.items.isEmpty
                          ? null
                          : _placeOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'Place Order',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
}