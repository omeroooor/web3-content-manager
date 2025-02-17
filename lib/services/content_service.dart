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
  
  Map<String, (PortableContent, List<File>)> _contents = {};

  Future<void> initialize() async {
    await _loadContents();
  }

  Future<String> _getStorageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final storageDir = Directory('${appDir.path}/pcontent');
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    return storageDir.path;
  }

  Future<void> _loadContents() async {
    try {
      print('Loading contents from disk...');
      final storageDir = await _getStorageDir();
      final contentDir = Directory('$storageDir/contents');
      print('Content directory: ${contentDir.path}');

      if (!await contentDir.exists()) {
        print('Content directory does not exist, creating...');
        await contentDir.create(recursive: true);
        return;
      }

      // Load all content metadata files
      await for (final entry in contentDir.list()) {
        if (entry is! File || !entry.path.endsWith('.json')) continue;
        print('\nLoading content from ${entry.path}');
        
        try {
          final metadataJson = await entry.readAsString();
          final content = PortableContent.fromJson(json.decode(metadataJson));
          print('Loaded content: ${content.name} (${content.id})');
          
          // Load associated files
          final files = <File>[];
          final filesDir = Directory('$storageDir/files/${content.id}');
          print('Loading files from: ${filesDir.path}');

          if (await filesDir.exists()) {
            for (final part in content.parts) {
              final file = File('${filesDir.path}/${part.id}');
              print('Checking file: ${file.path}');
              if (await file.exists()) {
                print('File exists, size: ${await file.length()} bytes');
                files.add(file);
              } else {
                print('Warning: File does not exist: ${file.path}');
              }
            }
          } else {
            print('Warning: Files directory does not exist: ${filesDir.path}');
          }

          if (files.length == content.parts.length) {
            print('Successfully loaded content with ${files.length} files');
            _contents[content.id] = (content, files);
          } else {
            print('Warning: Not all files were found (${files.length}/${content.parts.length})');
          }
        } catch (e) {
          print('Error loading content from ${entry.path}: $e');
        }
      }

      print('\nFinished loading contents');
      print('Total contents loaded: ${_contents.length}');
    } catch (e) {
      print('Error loading contents: $e');
    }
  }

  Future<void> _saveContent(PortableContent content, List<File> files) async {
    print('\nSaving content: ${content.name} (${content.id})');
    final storageDir = await _getStorageDir();
    
    // Save metadata
    final contentFile = File('$storageDir/contents/${content.id}.json');
    print('Saving metadata to: ${contentFile.path}');
    await contentFile.writeAsString(json.encode(content.toJson()));

    // Save files
    final filesDir = Directory('$storageDir/files/${content.id}');
    print('Saving files to: ${filesDir.path}');
    await filesDir.create(recursive: true);

    for (var i = 0; i < content.parts.length; i++) {
      final part = content.parts[i];
      final sourceFile = files[i];
      final targetFile = File('${filesDir.path}/${part.id}');
      print('Copying file: ${sourceFile.path} -> ${targetFile.path}');
      await sourceFile.copy(targetFile.path);
      print('File copied, size: ${await targetFile.length()} bytes');
    }

    // Update in-memory cache
    print('Updating in-memory cache');
    _contents[content.id] = (content, files.map((f) => File(f.path)).toList());
    print('Content saved successfully');
  }

  List<PortableContent> getAllContents() {
    return _contents.values.map((tuple) => tuple.$1).toList();
  }

  (PortableContent, List<File>)? getContent(String id) {
    return _contents[id];
  }

  Future<void> deleteContent(String id) async {
    if (!_contents.containsKey(id)) return;

    final storageDir = await _getStorageDir();
    
    // Delete metadata
    final contentFile = File('$storageDir/contents/$id.json');
    if (await contentFile.exists()) {
      await contentFile.delete();
    }

    // Delete files
    final filesDir = Directory('$storageDir/files/$id');
    if (await filesDir.exists()) {
      await filesDir.delete(recursive: true);
    }

    _contents.remove(id);
  }

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
    final content = await _createContent(
      name: name,
      description: description,
      standardName: standardName,
      standardVersion: standardVersion,
      standardData: standardData,
      files: files,
    );

    // Save the content
    await _saveContent(content, files);
    return content;
  }

  Future<PortableContent> _createContent({
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
    final result = await _importContent(pcontentFile);
    await _saveContent(result.$1, result.$2);
    return result;
  }

  Future<(PortableContent, List<File>)> _importContent(File pcontentFile) async {
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

      // Update standardData with new file checksum if it's an image
      if (part.name.toLowerCase().endsWith('.png') || 
          part.name.toLowerCase().endsWith('.jpg') || 
          part.name.toLowerCase().endsWith('.jpeg')) {
        content.standardData['imageChecksum'] = computedHash;
      }
    }

    // Get the standard
    final standard = _standards[content.standardName];
    if (standard == null) {
      throw Exception('Unknown standard: ${content.standardName}');
    }

    // Validate standard data
    await standard.validateData(content.standardData, files);

    // Update content hash after updating standardData
    final newContentHash = await standard.computeHash(content.standardData, content.parts);
    content.contentHash = newContentHash;

    return (content, files);
  }

  Future<bool> verifyContent(PortableContent content, List<File> files) async {
    print('Starting content verification...');
    print('Content ID: ${content.id}');
    print('Number of parts: ${content.parts.length}');
    print('Number of files: ${files.length}');

    if (content.parts.length != files.length) {
      print('Verification failed: Number of parts (${content.parts.length}) does not match number of files (${files.length})');
      return false;
    }

    try {
      // Get the standard
      final standard = _standards[content.standardName];
      if (standard == null) {
        print('Verification failed: Unknown standard: ${content.standardName}');
        throw Exception('Unknown standard: ${content.standardName}');
      }
      print('Using standard: ${content.standardName} v${content.standardVersion}');

      // Verify individual files
      for (var i = 0; i < content.parts.length; i++) {
        final part = content.parts[i];
        final file = files[i];
        print('Verifying file ${i + 1}/${files.length}: ${part.name}');
        print('File path: ${file.path}');
        
        if (!await file.exists()) {
          print('Verification failed: File does not exist: ${file.path}');
          return false;
        }

        final bytes = await file.readAsBytes();
        print('File size: ${bytes.length} bytes');
        final hash = await computeHash(bytes);
        print('Computed hash: $hash');
        print('Expected hash: ${part.hash}');

        if (hash != part.hash) {
          print('Verification failed: Hash mismatch for file ${part.name}');
          print('Expected: ${part.hash}');
          print('Got: $hash');
          return false;
        }
      }

      // Validate standard data
      print('Validating standard data...');
      try {
        await standard.validateData(content.standardData, files);
        print('Standard data validation successful');
      } catch (e) {
        print('Standard data validation failed: $e');
        return false;
      }

      // Verify content hash
      print('Verifying content hash...');
      final computedContentHash = await standard.computeHash(content.standardData, content.parts);
      print('Computed content hash: $computedContentHash');
      print('Expected content hash: ${content.contentHash}');
      
      final isValid = computedContentHash == content.contentHash;
      print(isValid ? 'Content verification successful' : 'Content hash verification failed');
      return isValid;
    } catch (e) {
      print('Verification error: $e');
      return false;
    }
  }
}
