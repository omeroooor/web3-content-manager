import 'package:flutter/foundation.dart';
import '../services/electrum_service.dart';
import 'settings_provider.dart';

class ElectrumProvider with ChangeNotifier {
  final _electrumService = ElectrumService();
  bool _isLoading = false;
  String? _error;
  final Map<String, Map<String, dynamic>> _profiles = {};
  SettingsProvider? _settingsProvider;
  bool _hasAttemptedConnection = false;

  bool get isLoading => _isLoading;
  String? get error => _hasAttemptedConnection ? _error : null;
  bool get isConnected => _electrumService.isConnected;

  void initialize(SettingsProvider settingsProvider) {
    _settingsProvider = settingsProvider;
    _settingsProvider!.addListener(_handleSettingsChange);
    
    // Try to connect if settings exist
    final settings = _settingsProvider!.nodeSettings;
    if (settings != null) {
      _connectWithSettings(settings);
    }
  }

  void _handleSettingsChange() {
    final settings = _settingsProvider?.nodeSettings;
    if (settings != null) {
      _connectWithSettings(settings);
    } else {
      _electrumService.dispose();
      _error = null;
      _hasAttemptedConnection = false;
      notifyListeners();
    }
  }

  Future<void> _connectWithSettings(NodeSettings settings) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _electrumService.initialize(
        host: settings.host,
        port: settings.port,
        username: settings.username,
        password: settings.password,
      );
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error connecting to Electrum server: $_error');
    } finally {
      _isLoading = false;
      _hasAttemptedConnection = true;
      notifyListeners();
    }
  }

  Map<String, dynamic>? getProfile(String contentHash) {
    return _profiles[contentHash];
  }

  Future<void> fetchProfile(String contentHash) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final profile = await _electrumService.verifyProfile(contentHash);
      _profiles[contentHash] = profile;
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error fetching profile: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void dispose() {
    _settingsProvider?.removeListener(_handleSettingsChange);
    _electrumService.dispose();
    super.dispose();
  }
}
