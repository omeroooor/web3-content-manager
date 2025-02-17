import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NodeSettings {
  final String host;
  final int port;
  final String username;
  final String password;

  NodeSettings({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'username': username,
    'password': password,
  };

  factory NodeSettings.fromJson(Map<String, dynamic> json) => NodeSettings(
    host: json['host'] as String,
    port: json['port'] as int,
    username: json['username'] as String,
    password: json['password'] as String,
  );

  factory NodeSettings.defaults() => NodeSettings(
    host: 'localhost',
    port: 19332,
    username: 'user',
    password: 'pass',
  );
}

class SettingsProvider extends ChangeNotifier {
  static const _nodeSettingsKey = 'node_settings';
  late SharedPreferences _prefs;
  NodeSettings? _nodeSettings;
  bool _isLoading = true;
  String? _error;

  SettingsProvider() {
    _loadSettings();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  NodeSettings? get nodeSettings => _nodeSettings;

  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final settingsJson = _prefs.getString(_nodeSettingsKey);
      
      if (settingsJson != null) {
        _nodeSettings = NodeSettings.fromJson(
          jsonDecode(settingsJson) as Map<String, dynamic>
        );
      } else {
        _nodeSettings = NodeSettings.defaults();
        await saveNodeSettings(_nodeSettings!);
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveNodeSettings(NodeSettings settings) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _prefs.setString(_nodeSettingsKey, jsonEncode(settings.toJson()));
      _nodeSettings = settings;
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error saving settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadSettings() async {
    await _loadSettings();
  }
}
