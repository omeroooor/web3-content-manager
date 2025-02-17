import 'dart:convert';
import 'package:http/http.dart' as http;

class BitcoinRPCClient {
  final String host;
  final int port;
  final String username;
  final String password;
  final String _auth;
  
  BitcoinRPCClient({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  }) : _auth = base64Encode(utf8.encode('$username:$password'));

  Future<Map<String, dynamic>> command(String method, [List<dynamic>? params]) async {
    final url = Uri.http('$host:$port', '/');
    final requestBody = {
      'jsonrpc': '2.0',
      'id': DateTime.now().millisecondsSinceEpoch,
      'method': method,
      'params': params ?? [],
    };
    
    print('\nBitcoin RPC Request:');
    print('URL: $url');
    print('Method: $method');
    print('Params: $params');
    print('Request body: ${json.encode(requestBody)}');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_auth',
        },
        body: json.encode(requestBody),
      );

      print('\nBitcoin RPC Response:');
      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('RPC call failed: ${response.statusCode} ${response.body}');
      }

      final result = json.decode(response.body) as Map<String, dynamic>;
      
      if (result.containsKey('error') && result['error'] != null) {
        print('RPC error: ${result['error']}');
        throw Exception('RPC error: ${result['error']}');
      }

      print('RPC result: ${result['result']}');
      return result['result'] as Map<String, dynamic>;
    } catch (e) {
      print('RPC exception: $e');
      rethrow;
    }
  }
}
