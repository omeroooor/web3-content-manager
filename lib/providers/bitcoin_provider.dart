import 'package:flutter/foundation.dart';
import '../services/bitcoin_service.dart';

class BitcoinProvider extends ChangeNotifier {
  final BitcoinService _bitcoinService;
  Map<String, Map<String, dynamic>> _profiles = {};
  bool _isLoading = false;
  String? _error;

  BitcoinProvider(this._bitcoinService);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Map<String, dynamic>? getProfile(String contentHash) => _profiles[contentHash];

  void clearProfiles() {
    _profiles.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> fetchProfile(String contentHash) async {
    print('\nFetching profile for hash: $contentHash');
    _isLoading = true;
    _error = null;
    _profiles.remove(contentHash); // Clear existing profile data
    notifyListeners();

    try {
      final profile = await _bitcoinService.getProfile(contentHash);
      _profiles[contentHash] = profile;
      _error = null;
    } catch (e) {
      print('Error fetching profile: $e');
      _error = e.toString();
      _profiles.remove(contentHash); // Ensure profile is cleared on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
