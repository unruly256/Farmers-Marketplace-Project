import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://<YOUR_AWS_PUBLIC_IP>:8000';

  static Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/test_db'));
      if (response.statusCode == 200) return true;
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> login(
    String phone,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/users/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          return {
            "status": "error",
            "message": jsonDecode(response.body)['detail'],
          };
        } catch (e) {
          return {
            "status": "error",
            "message": "Server crashed! Status: ${response.statusCode}",
          };
        }
      }
    } catch (e) {
      return {
        "status": "error",
        "message": "Connection timed out. Check your Wi-Fi and server.",
      };
    }
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String phone,
    String nationalId,
    String password,
    String role,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': name,
          'email': email,
          'phone': phone,
          'national_id': nationalId,
          'password': password,
          'role': role,
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {
        "status": "error",
        "message": jsonDecode(response.body)['detail'],
      };
    } catch (e) {
      return {
        "status": "error",
        "message": "Cannot reach the server. Check Wi-Fi.",
      };
    }
  }

  static Future<Map<String, dynamic>> addProduce(
    String farmerPhone,
    String cropType,
    String quantity,
    String price,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/produce/add'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'farmer_phone': farmerPhone,
              'crop_type': cropType,
              'quantity': double.tryParse(quantity) ?? 0.0,
              'price': double.tryParse(price) ?? 0.0,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          return {
            "status": "error",
            "message": jsonDecode(response.body)['detail'],
          };
        } catch (e) {
          return {
            "status": "error",
            "message": "Server crashed! Status: ${response.statusCode}",
          };
        }
      }
    } catch (e) {
      return {"status": "error", "message": "Connection timed out."};
    }
  }

  static Future<List<dynamic>> fetchProduce() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/produce'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success') {
          return decoded['data'];
        }
      }
      return [];
    } catch (e) {
      print("Error fetching produce: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>> placeOrder(
    String buyerPhone,
    List<Map<String, dynamic>> cartItems,
  ) async {
    try {
      final List<Map<String, dynamic>> orderItems = cartItems
          .map(
            (item) => {
              "produce_id": item['id'],
              "total_amount":
                  double.parse(item['price'].toString()) * item['cartQty'],
            },
          )
          .toList();

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/orders/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'buyer_phone': buyerPhone, 'items': orderItems}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "status": "error",
          "message": "Failed to place order. ${response.statusCode}",
        };
      }
    } catch (e) {
      return {"status": "error", "message": "Connection timed out."};
    }
  }

  static Future<bool> sendMessage(
    String senderPhone,
    String receiverPhone,
    String content,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender_phone': senderPhone,
          'receiver_phone': receiverPhone,
          'content': content,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> fetchMessages(String user1, String user2) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/$user1/$user2'),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success') return decoded['data'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- NEW: FETCH ALL ORDERS FOR A FARMER ---
  // Returns every order placed on this farmer's produce listings,
  // including buyer name, phone, crop, amount, status, and timestamp.
  static Future<List<dynamic>> fetchFarmerOrders(String farmerPhone) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/orders/farmer/$farmerPhone'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success') return decoded['data'];
      }
      return [];
    } catch (e) {
      print("Error fetching farmer orders: $e");
      return [];
    }
  }

  // --- FETCH BUYER ORDERS ---
  // Returns all orders placed by the buyer.
  static Future<List<dynamic>> fetchBuyerOrders(String phone) async {
    try {
      // Assuming your endpoint uses the phone number to filter orders
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/buyer/$phone'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle both direct lists or nested JSON maps
        return data is List ? data : (data['orders'] ?? data['data'] ?? []);
      } else {
        print('Failed to load buyer orders: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching buyer orders: $e');
      return [];
    }
  }

  // --- NEW: ACCEPT OR REJECT AN ORDER ---
  // newStatus must be either "Accepted" or "Rejected".
  // Accepting automatically deducts the ordered quantity from the produce listing.
  static Future<Map<String, dynamic>> updateOrderStatus(
    int orderId,
    String newStatus,
    String farmerPhone,
  ) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/api/orders/$orderId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'status': newStatus,
              'farmer_phone': farmerPhone,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          return {
            "status": "error",
            "message": jsonDecode(response.body)['detail'],
          };
        } catch (e) {
          return {
            "status": "error",
            "message": "Server error. Status: ${response.statusCode}",
          };
        }
      }
    } catch (e) {
      return {"status": "error", "message": "Connection timed out."};
    }
  }
}
