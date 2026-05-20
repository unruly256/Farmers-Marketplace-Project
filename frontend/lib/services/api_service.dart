import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cache_service.dart';

class ApiService {
  static const String baseUrl = 'http://16.171.33.254:8001';

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String _parseError(http.Response res, String fallback) {
    final body = _safeDecode(res.body);

    if (body is Map) {
      return body['detail']?.toString() ??
          body['message']?.toString() ??
          body['error']?.toString() ??
          fallback;
    }

    return fallback;
  }

  static Map<String, dynamic> _networkError(dynamic e) {
    if (e is SocketException) {
      return {
        "status": "error",
        "message": "No internet connection. Check your Wi-Fi or mobile data.",
      };
    }

    if (e is TimeoutException) {
      return {
        "status": "error",
        "message": "Request timed out. Please try again.",
      };
    }

    return {
      "status": "error",
      "message": "Unexpected error: $e",
    };
  }

  static Map<String, dynamic> _normalizeProduceItem(Map<String, dynamic> item) {
    final normalized = Map<String, dynamic>.from(item);

    final dynamic rawImages =
        normalized['imageUrls'] ?? normalized['imageurls'] ?? normalized['image_url'];

    List<dynamic> imageList = [];

    if (rawImages is List) {
      imageList = rawImages
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .toList();
    } else if (rawImages is String && rawImages.trim().isNotEmpty) {
      imageList = [rawImages.trim()];
    }

    normalized['imageUrls'] = imageList;
    normalized['imageurls'] = imageList;

    return normalized;
  }

  static List<dynamic> _normalizeProduceList(List<dynamic> items) {
    return items.map((item) {
      if (item is Map) {
        return _normalizeProduceItem(Map<String, dynamic>.from(item));
      }
      return item;
    }).toList();
  }

  static List<dynamic> _extractList(dynamic decoded) {
    List<dynamic> list = [];

    if (decoded is List) {
      list = List<dynamic>.from(decoded);
    } else if (decoded is Map) {
      if (decoded['status'] == 'success' && decoded['data'] is List) {
        list = List<dynamic>.from(decoded['data'] as List);
      } else if (decoded['data'] is List) {
        list = List<dynamic>.from(decoded['data'] as List);
      }
    }

    return _normalizeProduceList(list);
  }

  static Map<String, dynamic> _extractMap(dynamic decoded) {
    if (decoded is Map) {
      if (decoded['status'] == 'success' && decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data'] as Map);
      }
      return Map<String, dynamic>.from(decoded);
    }
    return {};
  }

  static Future<bool> testConnection() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/docs'))
          .timeout(const Duration(seconds: 8));

      _log('testConnection status: ${res.statusCode}');
      _log('testConnection body: ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      _log('testConnection error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String phone,
    String location,
    String role,
    String password,
    String confirmPassword,
  ) async {
    try {
      if (password != confirmPassword) {
        return {
          "status": "error",
          "message": "Passwords do not match.",
        };
      }

      final res = await http
          .post(
            Uri.parse('$baseUrl/api/users/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': name,
              'phone': phone,
              'location': location,
              'role': role,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      _log('register status: ${res.statusCode}');
      _log('register body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Registration failed."),
      };
    } catch (e) {
      _log('register error: $e');
      return _networkError(e);
    }
  }

  static Future<Map<String, dynamic>> login(
    String phone,
    String password,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/users/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      _log('login status: ${res.statusCode}');
      _log('login body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Invalid credentials."),
      };
    } catch (e) {
      _log('login error: $e');
      return _networkError(e);
    }
  }

  static Future<Map<String, dynamic>> fetchUserProfile(String phone) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/users/$phone'))
          .timeout(const Duration(seconds: 10));

      _log('fetchUserProfile status: ${res.statusCode}');
      _log('fetchUserProfile body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          final mapped = Map<String, dynamic>.from(decoded);
          await cacheProfile(phone, mapped);
          return mapped;
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Failed to load profile."),
      };
    } catch (e) {
      _log('fetchUserProfile error: $e');
      return _networkError(e);
    }
  }

  static Future<Map<String, dynamic>> updateUserProfile(
    String phone,
    String newName,
    String newLocation,
  ) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/api/users/$phone'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': newName,
              'location': newLocation,
            }),
          )
          .timeout(const Duration(seconds: 10));

      _log('updateUserProfile status: ${res.statusCode}');
      _log('updateUserProfile body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          final mapped = Map<String, dynamic>.from(decoded);
          await cacheProfile(phone, mapped);
          return mapped;
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Failed to update profile."),
      };
    } catch (e) {
      _log('updateUserProfile error: $e');
      return _networkError(e);
    }
  }

  static Future<Map<String, dynamic>> updateUserName(
    String phone,
    String newName,
  ) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/api/users/$phone/name'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'full_name': newName}),
          )
          .timeout(const Duration(seconds: 10));

      _log('updateUserName status: ${res.statusCode}');
      _log('updateUserName body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          final mapped = Map<String, dynamic>.from(decoded);
          await cacheProfile(phone, mapped);
          return mapped;
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Failed to update name."),
      };
    } catch (e) {
      _log('updateUserName error: $e');
      return _networkError(e);
    }
  }

  static Future<Map<String, dynamic>> uploadProfilePicture(
    String phone,
    File imageFile,
  ) async {
    try {
      if (!await imageFile.exists()) {
        return {
          "status": "error",
          "message": "Selected image file was not found.",
        };
      }

      final candidateUrls = [
        '$baseUrl/api/users/$phone/profile-picture',
        '$baseUrl/api/users/$phone/profile-picture/',
      ];

      http.Response? lastResponse;

      for (final url in candidateUrls) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse(url),
        );

        request.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );

        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 20),
        );

        final res = await http.Response.fromStream(streamedResponse);

        _log('uploadProfilePicture url: $url');
        _log('uploadProfilePicture status: ${res.statusCode}');
        _log('uploadProfilePicture body: ${res.body}');

        lastResponse = res;

        if (res.statusCode == 200) {
          final decoded = _safeDecode(res.body);
          if (decoded is Map) {
            final mapped = Map<String, dynamic>.from(decoded);
            await cacheProfile(phone, mapped);
            return mapped;
          }

          return {
            "status": "error",
            "message": "Upload succeeded but server response was invalid.",
          };
        }

        if (res.statusCode != 404 && res.statusCode != 307) {
          return {
            "status": "error",
            "message": _parseError(res, "Failed to upload image."),
          };
        }
      }

      return {
        "status": "error",
        "message": lastResponse != null
            ? _parseError(
                lastResponse,
                "Upload endpoint was not found on the server.",
              )
            : "Upload endpoint was not found on the server.",
      };
    } catch (e) {
      _log('uploadProfilePicture error: $e');
      return _networkError(e);
    }
  }

  static Future<List<dynamic>> fetchProduce() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/produce'))
          .timeout(const Duration(seconds: 10));

      _log('fetchProduce status: ${res.statusCode}');
      _log('fetchProduce body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        final list = _extractList(decoded);
        await cacheProduce(list);
        return list;
      }

      return [];
    } catch (e) {
      _log('fetchProduce error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> fetchFarmerProduce(String farmerPhone) async {
    try {
      final candidateUrls = [
        '$baseUrl/api/produce/farmer/$farmerPhone',
        '$baseUrl/api/farmer/$farmerPhone/produce',
      ];

      for (final url in candidateUrls) {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));

        _log('fetchFarmerProduce url: $url');
        _log('fetchFarmerProduce status: ${res.statusCode}');
        _log('fetchFarmerProduce body: ${res.body}');

        if (res.statusCode == 200) {
          final decoded = _safeDecode(res.body);
          return _extractList(decoded);
        }
      }

      return [];
    } catch (e) {
      _log('fetchFarmerProduce error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> fetchFarmerStats(
    String farmerPhone,
  ) async {
    try {
      final candidateUrls = [
        '$baseUrl/api/farmer/$farmerPhone/stats',
        '$baseUrl/api/farmers/$farmerPhone/stats',
      ];

      for (final url in candidateUrls) {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));

        _log('fetchFarmerStats url: $url');
        _log('fetchFarmerStats status: ${res.statusCode}');
        _log('fetchFarmerStats body: ${res.body}');

        if (res.statusCode == 200) {
          final decoded = _safeDecode(res.body);
          return _extractMap(decoded);
        }
      }

      return {};
    } catch (e) {
      _log('fetchFarmerStats error: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> addProduce(
    String farmerPhone,
    String cropName,
    String qty,
    String price,
    String description, {
    List<File>? imageFiles,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/produce/add'),
      );

      request.fields['farmer_phone'] = farmerPhone.trim();
      request.fields['name'] = cropName.trim();
      request.fields['quantity'] = qty.trim();
      request.fields['price'] = price.trim();
      request.fields['description'] = description.trim();

      if (imageFiles != null && imageFiles.isNotEmpty) {
        for (final file in imageFiles) {
          if (await file.exists()) {
            request.files.add(
              await http.MultipartFile.fromPath('images', file.path),
            );
          }
        }
      }

      _log('addProduce url: ${request.url}');
      _log('addProduce fields: ${request.fields}');
      _log('addProduce files count: ${request.files.length}');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final res = await http.Response.fromStream(streamedResponse);

      _log('addProduce status: ${res.statusCode}');
      _log('addProduce body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map && decoded['status'] == 'success') {
          return Map<String, dynamic>.from(decoded);
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Failed to list produce."),
      };
    } catch (e) {
      _log('addProduce error: $e');
      return _networkError(e);
    }
  }

  static Future<Map<String, dynamic>> deleteProduce(
    int produceId,
    String farmerPhone,
  ) async {
    try {
      final res = await http
          .delete(
            Uri.parse(
              '$baseUrl/api/produce/$produceId?farmer_phone=$farmerPhone',
            ),
          )
          .timeout(const Duration(seconds: 10));

      _log('deleteProduce status: ${res.statusCode}');
      _log('deleteProduce body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Failed to delete produce."),
      };
    } catch (e) {
      _log('deleteProduce error: $e');
      return _networkError(e);
    }
  }

  static Future<Map<String, dynamic>> placeOrder(
    String buyerPhone,
    List<dynamic> cartItems,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/api/orders/create');
      final payload = {
        'buyer_phone': buyerPhone,
        'items': cartItems
            .map(
              (item) => {
                'produce_id': item['id'],
                'total_amount': double.parse(item['price'].toString()) *
                    (item['cartQty'] as num),
              },
            )
            .toList(),
      };

      _log('placeOrder url: $url');
      _log('placeOrder payload: ${jsonEncode(payload)}');

      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      _log('placeOrder status: ${res.statusCode}');
      _log('placeOrder body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Failed to place order."),
      };
    } catch (e) {
      _log('placeOrder error: $e');
      return _networkError(e);
    }
  }

  static Future<List<dynamic>> fetchFarmerOrders(String farmerPhone) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/orders/farmer/$farmerPhone'))
          .timeout(const Duration(seconds: 10));

      _log('fetchFarmerOrders status: ${res.statusCode}');
      _log('fetchFarmerOrders body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        final list = _extractList(decoded);
        await cacheFarmerOrders(farmerPhone, list);
        return list;
      }

      return [];
    } catch (e) {
      _log('fetchFarmerOrders error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> fetchBuyerOrders(String buyerPhone) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/orders/buyer/$buyerPhone'))
          .timeout(const Duration(seconds: 10));

      _log('fetchBuyerOrders status: ${res.statusCode}');
      _log('fetchBuyerOrders body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        return _extractList(decoded);
      }

      return [];
    } catch (e) {
      _log('fetchBuyerOrders error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> updateOrderStatus(
    int orderId,
    String newStatus,
    String farmerPhone,
  ) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/api/orders/$orderId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'status': newStatus,
              'farmer_phone': farmerPhone,
            }),
          )
          .timeout(const Duration(seconds: 10));

      _log('updateOrderStatus status: ${res.statusCode}');
      _log('updateOrderStatus body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Failed to update order status."),
      };
    } catch (e) {
      _log('updateOrderStatus error: $e');
      return _networkError(e);
    }
  }

  static Future<Map<String, dynamic>> cancelOrder(
    int orderId,
    String buyerPhone,
  ) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$baseUrl/api/orders/$orderId/cancel'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'buyer_phone': buyerPhone,
            }),
          )
          .timeout(const Duration(seconds: 10));

      _log('cancelOrder status: ${res.statusCode}');
      _log('cancelOrder body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Failed to cancel order."),
      };
    } catch (e) {
      _log('cancelOrder error: $e');
      return _networkError(e);
    }
  }

  static Future<Map<String, int>> fetchUnreadCounts(String phone) async {
    try {
      final urls = [
        '$baseUrl/api/messages/unread-counts/$phone',
        '$baseUrl/api/messages/unread/$phone',
      ];

      for (final url in urls) {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));

        _log('fetchUnreadCounts url: $url');
        _log('fetchUnreadCounts status: ${res.statusCode}');
        _log('fetchUnreadCounts body: ${res.body}');

        if (res.statusCode == 200) {
          final decoded = _safeDecode(res.body);
          if (decoded is Map &&
              decoded['status'] == 'success' &&
              decoded['data'] is List) {
            final List data = decoded['data'] as List;
            final result = <String, int>{};

            for (final row in data) {
              result[row['contact_phone'].toString()] =
                  int.tryParse(row['unread_count'].toString()) ?? 0;
            }

            await cacheUnreadCounts(phone, result);
            return result;
          }
        }

        if (res.statusCode != 404) {
          break;
        }
      }

      return <String, int>{};
    } catch (e) {
      _log('fetchUnreadCounts error: $e');
      return <String, int>{};
    }
  }

  static Future<Map<String, dynamic>> markChatAsRead(
    String currentPhone,
    String contactPhone,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/messages/mark-read'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'current_phone': currentPhone,
              'contact_phone': contactPhone,
            }),
          )
          .timeout(const Duration(seconds: 10));

      _log('markChatAsRead status: ${res.statusCode}');
      _log('markChatAsRead body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Failed to mark messages as read."),
      };
    } catch (e) {
      _log('markChatAsRead error: $e');
      return _networkError(e);
    }
  }

  static Future<List<dynamic>> fetchMessages(
    String user1,
    String user2,
  ) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/messages/$user1/$user2'))
          .timeout(const Duration(seconds: 10));

      _log('fetchMessages status: ${res.statusCode}');
      _log('fetchMessages body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        return _extractList(decoded);
      }

      return [];
    } catch (e) {
      _log('fetchMessages error: $e');
      return [];
    }
  }

  // ------------------------------------------------------------------
  // FIXED sendMessage: changed 'message' key to 'content'
  // ------------------------------------------------------------------
  static Future<Map<String, dynamic>> sendMessage(
    String senderPhone,
    String receiverPhone,
    String message,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/messages/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sender_phone': senderPhone,
              'receiver_phone': receiverPhone,
              'content': message, // ✅ Changed 'message' → 'content'
            }),
          )
          .timeout(const Duration(seconds: 10));

      _log('sendMessage status: ${res.statusCode}');
      _log('sendMessage body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = _safeDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      return {
        "status": "error",
        "message": _parseError(res, "Failed to send message."),
      };
    } catch (e) {
      _log('sendMessage error: $e');
      return _networkError(e);
    }
  }

  // ── CACHING LOGIC ───────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getCachedProfile(String phone) async {
    final cached = await CacheService.readJson('cache_profile_$phone');
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }

  static Future<void> cacheProfile(
    String phone,
    Map<String, dynamic> data,
  ) async {
    await CacheService.saveJson('cache_profile_$phone', data);
  }

  static Future<List<dynamic>> getCachedProduce() async {
    final cached = await CacheService.readJson('cache_produce');
    if (cached is List) return _normalizeProduceList(List<dynamic>.from(cached));
    if (cached is Map && cached['data'] is List) {
      return _normalizeProduceList(List<dynamic>.from(cached['data'] as List));
    }
    return [];
  }

  static Future<void> cacheProduce(dynamic data) async {
    await CacheService.saveJson('cache_produce', data);
  }

  static Future<List<dynamic>> getCachedFarmerOrders(String phone) async {
    final cached = await CacheService.readJson('cache_farmer_orders_$phone');
    if (cached is List) return List<dynamic>.from(cached);
    if (cached is Map && cached['data'] is List) {
      return List<dynamic>.from(cached['data'] as List);
    }
    return [];
  }

  static Future<void> cacheFarmerOrders(String phone, dynamic data) async {
    await CacheService.saveJson('cache_farmer_orders_$phone', data);
  }

  static Future<List<dynamic>> getCachedBuyerOrders(String phone) async {
    final cached = await CacheService.readJson('cache_buyer_orders_$phone');
    if (cached is List) return List<dynamic>.from(cached);
    if (cached is Map && cached['data'] is List) {
      return List<dynamic>.from(cached['data'] as List);
    }
    return [];
  }

  static Future<void> cacheBuyerOrders(String phone, dynamic data) async {
    await CacheService.saveJson('cache_buyer_orders_$phone', data);
  }

  static Future<Map<String, int>> getCachedUnreadCounts(String phone) async {
    final cached = await CacheService.readJson('cache_unread_$phone');
    if (cached is Map) {
      return {
        for (final entry in cached.entries)
          entry.key.toString(): int.tryParse(entry.value.toString()) ?? 0,
      };
    }
    return {};
  }

  static Future<void> cacheUnreadCounts(
    String phone,
    Map<String, int> data,
  ) async {
    await CacheService.saveJson('cache_unread_$phone', data);
  }
}