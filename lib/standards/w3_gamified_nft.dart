import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/digests/ripemd160.dart';
import '../models/content_part.dart';
import 'content_standard.dart';

class W3GamifiedNFTStandard implements ContentStandard {
  static final _ripemd160 = RIPEMD160Digest();

  @override
  String get name => 'W3-Gamified-NFT';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> getRequiredFields() {
    return {
      'code': 'string',
      'owner': 'hex_string',
      'nonce': 'number',
      'imageChecksum': 'string',
      'image': 'file',
    };
  }

  @override
  Future<String> computeHash(Map<String, dynamic> standardData, List<ContentPart> parts) async {
    final code = standardData['code'] as String;
    final owner = standardData['owner'] as String;
    final nonce = standardData['nonce'] as int;
    final imageChecksum = standardData['imageChecksum'] as String;

    // Concatenate in specified order
    final hashInput = code + owner + imageChecksum + nonce.toString();
    
    // First compute SHA-256
    final sha256Digest = sha256.convert(utf8.encode(hashInput));
    
    // Then compute RIPEMD160 of the SHA256 result
    final ripemd160Bytes = _ripemd160.process(sha256Digest.bytes as Uint8List);
    
    // Return as hex
    return hex.encode(ripemd160Bytes);
  }

  @override
  Future<Map<String, dynamic>> validateData(Map<String, dynamic> standardData, List<File> files) async {
    final errors = <String>[];

    // Validate required fields
    if (!standardData.containsKey('code') || standardData['code'].isEmpty) {
      errors.add('Code is required');
    }

    if (!standardData.containsKey('owner') || !_isValidHexString(standardData['owner'])) {
      errors.add('Owner must be a valid hex string');
    }

    if (!standardData.containsKey('nonce') || !(standardData['nonce'] is int)) {
      errors.add('Nonce must be a valid number');
    }

    if (!standardData.containsKey('imageChecksum') || standardData['imageChecksum'].isEmpty) {
      errors.add('Image checksum is required');
    }

    // Find image file
    final imagePart = files.firstWhere(
      (file) => file.path.toLowerCase().endsWith('.png') || 
                file.path.toLowerCase().endsWith('.jpg') ||
                file.path.toLowerCase().endsWith('.jpeg'),
      orElse: () => throw Exception('Image file is required'),
    );

    // Compute image checksum using only SHA-256
    final imageBytes = await imagePart.readAsBytes();
    final computedChecksum = sha256.convert(imageBytes).toString();
    
    if (computedChecksum != standardData['imageChecksum']) {
      errors.add('Image checksum does not match');
    }

    if (errors.isNotEmpty) {
      throw Exception('Validation errors: ${errors.join(', ')}');
    }

    return standardData;
  }

  bool _isValidHexString(String value) {
    if (value.isEmpty) return false;
    if (value.length % 2 != 0) return false;
    return RegExp(r'^[0-9A-Fa-f]+$').hasMatch(value);
  }
}
