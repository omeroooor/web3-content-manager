import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NodeSettings {
  final String host;
  final int port;
  final String username;
  final String password;

  NodeSettings({
    required this.host,
    required this.port,
    this.username = '',
    this.password = '',
  });

  factory NodeSettings.defaults() {
    return NodeSettings(
      host: '1.tcp.ap.ngrok.io',
      port: 21920,
      username: '',
      password: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }

  factory NodeSettings.fromJson(Map<String, dynamic> json) {
    return NodeSettings(
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String,
      password: json['password'] as String,
    );
  }
}

class SettingsProvider with ChangeNotifier {
  static const String _settingsKey = 'node_settings';
  final SharedPreferences _prefs;
  NodeSettings? _nodeSettings;
  String? _error;
  bool _isLoading = false;

  SettingsProvider(this._prefs) {
    _loadSettings();
  }

  NodeSettings? get nodeSettings => _nodeSettings;
  String? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final settingsJson = _prefs.getString(_settingsKey);
      if (settingsJson != null) {
        final Map<String, dynamic> json = Map<String, dynamic>.from(
          jsonDecode(settingsJson) as Map,
        );
        _nodeSettings = NodeSettings.fromJson(json);
      } else {
        _nodeSettings = NodeSettings.defaults();
        await saveNodeSettings(_nodeSettings!);
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to load settings: $e';
      print('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveNodeSettings(NodeSettings settings) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
      _nodeSettings = settings;
      _error = null;
    } catch (e) {
      _error = 'Failed to save settings: $e';
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
