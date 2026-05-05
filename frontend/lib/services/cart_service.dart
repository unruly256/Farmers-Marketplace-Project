class CartService {
  // Stores the items the user wants to buy
  static final List<Map<String, dynamic>> items = [];

  // Adds an item to the cart (and increases quantity if already there)
  static void addToCart(Map<String, dynamic> product) {
    int index = items.indexWhere((item) => item['id'] == product['id']);
    if (index != -1) {
      items[index]['cartQty'] += 1;
    } else {
      // Add the product with a starting cart quantity of 1
      items.add({...product, 'cartQty': 1}); 
    }
  }

  // Automatically calculates the total UGX for the checkout screen
  static double get totalAmount {
    return items.fold(0, (sum, item) => sum + (double.parse(item['price'].toString()) * item['cartQty']));
  }

  // Wipes the cart clean after a successful order
  static void clear() {
    items.clear();
  }
}