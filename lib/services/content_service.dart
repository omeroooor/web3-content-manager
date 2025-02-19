import 'dart:async';
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
import '../standards/w3_simple_post_nft.dart';
import 'package:path/path.dart' as p;

class ContentService {
  final _uuid = const Uuid();
  final Map<String, ContentStandard> _standards = {
    'W3-Gamified-NFT': W3GamifiedNFTStandard(),
    'W3-S-POST-NFT': W3SimplePostNFTStandard(),
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

  Future<void> exportContent(PortableContent content, File targetFile) async {
    try {
      print('\n=== Starting Content Export ===');
      
      // First verify the content files
      print('\nVerifying content files before export...');
      if (!await _verifyContentFiles(content)) {
        throw Exception('Content verification failed - some files are missing or corrupted');
      }
      print('Content verification successful');

      print('\nCreating archive...');
      final archive = Archive();

      // Track total expected size
      int expectedSize = 0;

      // Add metadata
      final metadataJson = json.encode(content.toJson());
      final metadataBytes = utf8.encode(metadataJson);
      archive.addFile(ArchiveFile(
        'metadata.json',
        metadataBytes.length,
        metadataBytes,
      ));
      print('Added metadata.json to archive (${metadataBytes.length} bytes)');
      expectedSize += metadataBytes.length;

      // Get the content directory
      final storageDir = await _getStorageDir();
      final contentDir = Directory('$storageDir/files/${content.id}');
      
      print('\nProcessing content parts:');
      for (final part in content.parts) {
        print('\nProcessing part: ${part.name} (${part.id})');
        final partFile = File('${contentDir.path}/${part.id}');
        print('Reading file: ${partFile.path}');
        
        final bytes = await partFile.readAsBytes();
        print('Read ${bytes.length} bytes');
        expectedSize += bytes.length;
        
        final computedHash = await computeHash(bytes);
        print('Computed hash: $computedHash');
        print('Expected hash: ${part.hash}');
        
        if (computedHash != part.hash) {
          throw Exception('Hash mismatch for file ${part.name}');
        }

        // Store file with part ID as name
        final archivePath = 'files/${part.id}';
        final archiveFile = ArchiveFile(
          archivePath,
          bytes.length,
          bytes,
        );
        archive.addFile(archiveFile);
        print('Added to archive as: $archivePath (${bytes.length} bytes)');
      }

      print('\nFinal archive contents:');
      int actualSize = 0;
      for (final file in archive.files) {
        print('- ${file.name} (${file.size} bytes)');
        print('  isFile: ${file.isFile}');
        if (file.content != null) {
          final contentSize = (file.content as List<int>).length;
          print('  Content size: $contentSize bytes');
          actualSize += contentSize;
        } else {
          print('  Content: null');
          throw Exception('File ${file.name} has null content');
        }
      }

      if (actualSize != expectedSize) {
        print('\nERROR: Size mismatch');
        print('Expected total size: $expectedSize bytes');
        print('Actual total size: $actualSize bytes');
        throw Exception('Archive size mismatch - some content may be missing');
      }
      print('\nSize verification successful');

      print('\nEncoding archive...');
      final encodedArchive = ZipEncoder().encode(archive);
      if (encodedArchive == null) {
        throw Exception('Failed to encode archive');
      }

      print('Writing archive to: ${targetFile.path}');
      await targetFile.writeAsBytes(encodedArchive);
      final finalSize = await targetFile.length();
      print('Archive written successfully ($finalSize bytes)');
      
      // Verify the written file
      print('\nVerifying written archive...');
      final verificationBytes = await targetFile.readAsBytes();
      final verificationArchive = ZipDecoder().decodeBytes(verificationBytes);
      if (verificationArchive == null) {
        throw Exception('Failed to decode written archive');
      }
      
      print('Verifying archive contents:');
      for (final file in verificationArchive.files) {
        print('- ${file.name} (${file.size} bytes)');
        if (file.content == null) {
          throw Exception('File ${file.name} has null content in written archive');
        }
      }
      print('Archive verification successful');
      
      print('=== Export Complete ===\n');
    } catch (e) {
      print('ERROR in exportContent: $e');
      rethrow;
    }
  }

  Future<bool> _verifyContentFiles(PortableContent content) async {
    print('\n=== Verifying Content Files ===');
    print('Content ID: ${content.id}');
    print('Content Name: ${content.name}');
    print('Number of parts: ${content.parts.length}');

    final storageDir = await _getStorageDir();
    final contentDir = Directory('$storageDir/files/${content.id}');
    
    print('\nStorage paths:');
    print('Storage directory: $storageDir');
    print('Content directory: ${contentDir.path}');
    print('Content directory exists: ${await contentDir.exists()}');

    if (!await contentDir.exists()) {
      print('ERROR: Content directory not found');
      return false;
    }

    print('\nContent directory structure:');
    await _printDirectoryStructure(contentDir);

    print('\nVerifying each content part:');
    for (final part in content.parts) {
      print('\nChecking part: ${part.name}');
      print('Part ID: ${part.id}');
      print('Expected hash: ${part.hash}');
      
      final partFile = File('${contentDir.path}/${part.id}');
      print('File path: ${partFile.path}');
      print('File exists: ${await partFile.exists()}');
      
      if (!await partFile.exists()) {
        print('ERROR: File not found');
        return false;
      }

      final fileSize = await partFile.length();
      print('File size: $fileSize bytes');
      
      if (fileSize == 0) {
        print('ERROR: File is empty');
        return false;
      }

      final bytes = await partFile.readAsBytes();
      final computedHash = await computeHash(bytes);
      print('Computed hash: $computedHash');
      
      if (computedHash != part.hash) {
        print('ERROR: Hash mismatch');
        return false;
      }
      
      print('Part verification: SUCCESS');
    }

    print('\n=== Content Verification Complete ===');
    return true;
  }

  Future<void> _printDirectoryStructure(Directory dir, [String indent = '']) async {
    await for (final entity in dir.list()) {
      if (entity is File) {
        final size = await entity.length();
        final hash = await computeHash(await entity.readAsBytes());
        print('$indent- ${p.basename(entity.path)} (File, $size bytes)');
        print('$indent  Hash: $hash');
      } else if (entity is Directory) {
        print('$indent+ ${p.basename(entity.path)} (Directory)');
        await _printDirectoryStructure(entity, '$indent  ');
      }
    }
  }

  Future<(PortableContent, List<File>)> importContent(File pcontentFile) async {
    final result = await _importContent(pcontentFile);
    await _saveContent(result.$1, result.$2);
    return result;
  }

  Future<(PortableContent, List<File>)> _importContent(File pcontentFile) async {
    try {
      print('\n=== Starting Content Import ===');
      print('Import file path: ${pcontentFile.path}');
      print('File exists: ${await pcontentFile.exists()}');
      print('File size: ${await pcontentFile.length()} bytes');

      final bytes = await pcontentFile.readAsBytes();
      print('Read ${bytes.length} bytes from file');

      print('\nDecoding archive...');
      final archive = ZipDecoder().decodeBytes(bytes);
      if (archive == null) {
        print('ERROR: Failed to decode archive');
        throw Exception('Failed to decode archive');
      }
      print('Archive decoded successfully');
      
      print('\nArchive details:');
      print('Number of files: ${archive.files.length}');
      print('Archive files:');
      for (final file in archive.files) {
        print('\nFile: ${file.name}');
        print('  Size: ${file.size} bytes');
        print('  isFile: ${file.isFile}');
        if (file.content != null) {
          print('  Content size: ${(file.content as List<int>).length} bytes');
        } else {
          print('  Content: null');
        }
      }

      // Read metadata
      print('\nLooking for metadata.json...');
      final metadataFile = archive.findFile('metadata.json');
      if (metadataFile == null) {
        print('ERROR: metadata.json not found in archive');
        throw Exception('Invalid pcontent file: metadata.json not found');
      }
      
      print('Decoding metadata...');
      final metadataJson = utf8.decode(metadataFile.content as List<int>);
      print('Metadata content: $metadataJson');
      
      final content = PortableContent.fromJson(json.decode(metadataJson));
      print('Content decoded: ${content.name} (${content.id})');
      print('Number of parts: ${content.parts.length}');

      // Extract files
      final tempDir = await getTemporaryDirectory();
      final files = <File>[];

      print('\nProcessing content parts:');
      for (final part in content.parts) {
        print('\nProcessing part: ${part.name} (${part.id})');
        
        final archivePath = 'files/${part.id}';
        print('Looking for file at path: $archivePath');
        
        final archiveFile = archive.findFile(archivePath);
        if (archiveFile == null) {
          print('ERROR: File not found at path: $archivePath');
          print('\nDumping all archive paths:');
          for (final file in archive.files) {
            print('- ${file.name}');
            // Try to read the file content to verify it's accessible
            if (file.content != null) {
              print('  Content size: ${(file.content as List<int>).length} bytes');
            } else {
              print('  Content: null');
            }
          }
          throw Exception('Invalid pcontent file: missing file ${part.id}');
        }

        print('Found file in archive (${archiveFile.size} bytes)');
        final tempFile = File(p.join(tempDir.path, part.name));
        print('Writing to temporary file: ${tempFile.path}');
        
        final fileBytes = archiveFile.content as List<int>;
        print('Content size: ${fileBytes.length} bytes');
        await tempFile.writeAsBytes(fileBytes);
        files.add(tempFile);
        print('File written successfully');

        final computedHash = await computeHash(fileBytes);
        print('Computed hash: $computedHash');
        print('Expected hash: ${part.hash}');
        
        if (computedHash != part.hash) {
          print('ERROR: Hash mismatch');
          print('  Computed: $computedHash');
          print('  Expected: ${part.hash}');
          throw Exception('Hash mismatch for file ${part.name}');
        }
        print('Hash verified successfully');
      }

      print('\nValidating standard...');
      final standard = _standards[content.standardName];
      if (standard == null) {
        print('ERROR: Standard not found: ${content.standardName}');
        throw Exception('Unknown standard: ${content.standardName}');
      }

      print('Validating standard data...');
      // Create a copy of the standard data and update it with the validated data
      final validatedData = await standard.validateData(content.standardData, files);

      // Compute content hash with validated data
      print('Computing content hash...');
      final newContentHash = await standard.computeHash(validatedData, content.parts);
      print('New content hash: $newContentHash');

      // Create a new content instance with the validated data and new hash
      final validatedContent = PortableContent(
        id: content.id,
        name: content.name,
        description: content.description,
        standardName: content.standardName,
        standardVersion: content.standardVersion,
        standardData: validatedData,
        contentHash: newContentHash,
        parts: content.parts,
        createdAt: content.createdAt,
        updatedAt: content.updatedAt,
      );

      print('\n=== Import Complete ===');
      return (validatedContent, files);
    } catch (e) {
      print('ERROR in _importContent: $e');
      rethrow;
    }
  }

  Future<bool> verifyContent(PortableContent content, List<File> files) async {
    print('Starting content verification...');
    print('Content ID: ${content.id}');
    print('Standard: ${content.standardName}');
    print('Number of parts: ${content.parts.length}');
    print('Number of files: ${files.length}');

    try {
      // Get the standard
      final standard = _standards[content.standardName];
      if (standard == null) {
        print('Verification failed: Unknown standard: ${content.standardName}');
        throw Exception('Unknown standard: ${content.standardName}');
      }
      print('Using standard: ${content.standardName} v${content.standardVersion}');

      // For W3-S-POST-NFT, we only verify files if they exist
      final shouldVerifyFiles = content.standardName == 'W3-S-POST-NFT' 
          ? content.standardData.containsKey('mediaPath')
          : true;

      if (shouldVerifyFiles) {
        if (content.parts.length != files.length) {
          print('Verification failed: Number of parts (${content.parts.length}) does not match number of files (${files.length})');
          return false;
        }

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
      }

      // Validate standard data
      print('Validating standard data...');
      try {
        final validatedData = await standard.validateData(content.standardData, files);
        print('Standard data validation successful');

        // Verify content hash using validated data
        print('Verifying content hash...');
        final computedContentHash = await standard.computeHash(validatedData, content.parts);
        print('Computed content hash: $computedContentHash');
        print('Expected content hash: ${content.contentHash}');
        
        final isValid = computedContentHash == content.contentHash;
        print(isValid ? 'Content verification successful' : 'Content hash verification failed');
        return isValid;
      } catch (e) {
        print('Standard data validation failed: $e');
        return false;
      }
    } catch (e) {
      print('Verification error: $e');
      return false;
    }
  }
}
