import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:pointycastle/digests/ripemd160.dart';
import '../models/content_part.dart';
import '../standards/content_standard.dart';
import '../standards/w3_gamified_nft.dart';

class ContentService {
  final _uuid = const Uuid();
  final Map<String, ContentStandard> _standards = {
    'W3-Gamified-NFT': W3GamifiedNFTStandard(),
  };

  Future<String> computeHash(List<int> bytes) async {
    // Only compute SHA-256 for content parts and images
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<PortableContent> createContent({
    required String name,
    required String description,
    required String standardName,
    required String standardVersion,
    required Map<String, dynamic> standardData,
    required List<File> files,
  }) async {
    final List<ContentPart> parts = [];
    
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final hash = await computeHash(bytes);
      
      parts.add(ContentPart(
        id: _uuid.v4(),
        name: file.path.split(Platform.pathSeparator).last,
        hash: hash,
        mimeType: 'application/octet-stream', // TODO: Implement proper MIME type detection
        size: bytes.length,
      ));
    }

    // Get the standard
    final standard = _standards[standardName];
    if (standard == null) {
      throw Exception('Unknown standard: $standardName');
    }

    // Validate standard data
    await standard.validateData(standardData, files);

    // Compute content hash using the standard
    final contentHash = await standard.computeHash(standardData, parts);

    return PortableContent(
      id: _uuid.v4(),
      name: name,
      description: description,
      standardName: standardName,
      standardVersion: standardVersion,
      standardData: standardData,
      contentHash: contentHash,
      parts: parts,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<File> exportContent(PortableContent content, List<File> files) async {
    final archive = Archive();
    
    // Add metadata
    final metadataBytes = utf8.encode(json.encode(content.toJson()));
    archive.addFile(ArchiveFile(
      'metadata.json',
      metadataBytes.length,
      metadataBytes,
    ));

    // Add files
    for (var i = 0; i < content.parts.length; i++) {
      final part = content.parts[i];
      final file = files[i];
      final bytes = await file.readAsBytes();
      
      archive.addFile(ArchiveFile(
        'files/${part.id}',
        bytes.length,
        bytes,
      ));
    }

    // Create zip
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    if (zipData == null) throw Exception('Failed to create zip archive');

    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final outputFile = File('${tempDir.path}/${content.name}.pcontent');
    await outputFile.writeAsBytes(zipData);

    return outputFile;
  }

  Future<(PortableContent, List<File>)> importContent(File pcontentFile) async {
    final bytes = await pcontentFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Read metadata
    final metadataFile = archive.findFile('metadata.json');
    if (metadataFile == null) throw Exception('Invalid pcontent file: metadata.json not found');
    
    final metadataJson = utf8.decode(metadataFile.content as List<int>);
    final content = PortableContent.fromJson(json.decode(metadataJson));

    // Extract files
    final tempDir = await getTemporaryDirectory();
    final files = <File>[];

    for (final part in content.parts) {
      final archiveFile = archive.findFile('files/${part.id}');
      if (archiveFile == null) throw Exception('Invalid pcontent file: missing file ${part.id}');

      final file = File('${tempDir.path}/${part.name}');
      await file.writeAsBytes(archiveFile.content as List<int>);
      files.add(file);

      // Verify file hash
      final computedHash = await computeHash(archiveFile.content as List<int>);
      if (computedHash != part.hash) {
        throw Exception('Hash mismatch for file ${part.name}');
      }
    }

    // Get the standard
    final standard = _standards[content.standardName];
    if (standard == null) {
      throw Exception('Unknown standard: ${content.standardName}');
    }

    // Validate standard data
    await standard.validateData(content.standardData, files);

    // Verify content hash
    final computedContentHash = await standard.computeHash(content.standardData, content.parts);
    if (computedContentHash != content.contentHash) {
      throw Exception('Content hash mismatch');
    }

    return (content, files);
  }

  Future<bool> verifyContent(PortableContent content, List<File> files) async {
    if (content.parts.length != files.length) return false;

    try {
      // Get the standard
      final standard = _standards[content.standardName];
      if (standard == null) {
        throw Exception('Unknown standard: ${content.standardName}');
      }

      // Verify individual files
      for (var i = 0; i < content.parts.length; i++) {
        final part = content.parts[i];
        final file = files[i];
        final bytes = await file.readAsBytes();
        final hash = await computeHash(bytes);

        if (hash != part.hash) return false;
      }

      // Validate standard data
      await standard.validateData(content.standardData, files);

      // Verify content hash
      final computedContentHash = await standard.computeHash(content.standardData, content.parts);
      return computedContentHash == content.contentHash;
    } catch (e) {
      return false;
    }
  }
}
