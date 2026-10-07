import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Simple Hive-based local storage.
/// Stores data as JSON strings so no type adapters / codegen needed.
class HiveStorage {
  final Box _box;

  HiveStorage(this._box);

  /// Save a list of JSON-encodable maps under [key].
  Future<void> saveList(String key, List<Map<String, dynamic>> items) async {
    final encoded = jsonEncode(items);
    await _box.put(key, encoded);
  }

  /// Load a list previously saved under [key].
  List<Map<String, dynamic>> loadList(String key) {
    final raw = _box.get(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw as String) as List<dynamic>;
    return decoded.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Save a single JSON-encodable map under [key].
  Future<void> saveMap(String key, Map<String, dynamic> item) async {
    await _box.put(key, jsonEncode(item));
  }

  /// Load a single map previously saved under [key].
  Map<String, dynamic>? loadMap(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw as String) as Map<String, dynamic>;
  }

  Future<void> remove(String key) => _box.delete(key);

  Future<void> clear() => _box.clear();
}
