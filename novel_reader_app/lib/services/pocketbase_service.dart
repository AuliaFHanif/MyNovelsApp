import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  PocketBaseService._internal();

  late PocketBase pb;

  void initialize() {
    // For local development on Windows
    pb = PocketBase('http://127.0.0.1:8090');

    // TODO: For mobile (Phase 6), use Tailscale IP:
    // pb = PocketBase('http://100.94.48.126:8090');
  }

  // Test connection
  Future<bool> testConnection() async {
    try {
      await pb.health.check();
      return true;
    } catch (e) {
      debugPrint('PocketBase connection failed: $e');
      return false;
    }
  }
}
