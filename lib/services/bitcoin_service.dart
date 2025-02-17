import 'bitcoin_rpc_client.dart';

class BitcoinService {
  late BitcoinRPCClient _client;
  bool _isInitialized = false;

  Future<void> initialize({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    if (_isInitialized) return;

    print('\nInitializing Bitcoin Service:');
    print('Host: $host');
    print('Port: $port');
    print('Username: $username');
    
    _client = BitcoinRPCClient(
      host: host,
      port: port,
      username: username,
      password: password,
    );
    
    _isInitialized = true;
    print('Bitcoin Service initialized');
  }

  Future<Map<String, dynamic>> getProfile(String contentHash) async {
    if (!_isInitialized) {
      throw Exception('BitcoinService not initialized');
    }

    print('\nFetching profile for content hash: $contentHash');
    
    try {
      final response = await _client.command('getprofile', [contentHash]);
      
      final profile = {
        'rps': response['rps'] as int? ?? 0,
        'owner': response['owner'] as String? ?? '',
        'isRented': response['tenant'] != null,
        'tenant': response['tenant'] as String?,
      };

      print('Processed profile data:');
      print('RPS: ${profile['rps']}');
      print('Owner: ${profile['owner']}');
      print('Is Rented: ${profile['isRented']}');
      print('Tenant: ${profile['tenant']}');
      
      return profile;
    } catch (e) {
      print('Error fetching profile: $e');
      rethrow;
    }
  }
}
