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

  Future<void> fetchProfile(String contentHash) async {
    print('\nFetching profile in provider for hash: $contentHash');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _bitcoinService.getProfile(contentHash);
      print('Profile received in provider: $profile');
      _profiles[contentHash] = profile;
      _error = null;
    } catch (e) {
      print('Error in provider: $e');
      _error = e.toString();
      _profiles.remove(contentHash); // Clear invalid profile
    } finally {
      _isLoading = false;
      notifyListeners();
      print('Profile data updated, current profiles: $_profiles');
    }
  }
}
