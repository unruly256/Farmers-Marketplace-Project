import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static Future<void> saveJson(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
    await prefs.setInt('${key}_time', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<dynamic> readJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) return null;

    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<int?> readCacheTime(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${key}_time');
  }

  static Future<bool> hasCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove('${key}_time');
  }

  static Future<void> clearAllAppCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();

    for (final key in keys) {
      if (key.startsWith('cache_') || key.endsWith('_time')) {
        await prefs.remove(key);
      }
    }
  }
}