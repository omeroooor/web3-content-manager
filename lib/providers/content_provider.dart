import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/content_part.dart';
import '../services/content_service.dart';

class ContentProvider with ChangeNotifier {
  final ContentService _service;
  List<PortableContent> _contents = [];
  PortableContent? _currentContent;
  List<File>? _currentFiles;
  bool _isLoading = false;
  String? _error;

  ContentProvider(this._service) {
    initialize();
  }

  Future<void> initialize() async {
    print('\nInitializing ContentProvider...');
    _setLoading(true);

    try {
      await _service.initialize();
      _contents = _service.getAllContents();
      print('Loaded ${_contents.length} contents');
      notifyListeners();
    } catch (e) {
      print('Error initializing ContentProvider: $e');
      _setError('Failed to load contents: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    print('\nRefreshing contents...');
    await initialize();
  }

  List<PortableContent> get contents => _contents;
  PortableContent? get currentContent => _currentContent;
  List<File>? get currentFiles => _currentFiles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void selectContent(String id) {
    print('\nSelecting content: $id');
    final contentData = _service.getContent(id);
    if (contentData != null) {
      _currentContent = contentData.$1;
      _currentFiles = contentData.$2;
      print('Selected content: ${_currentContent!.name}');
      print('Number of files: ${_currentFiles!.length}');
      notifyListeners();
    } else {
      print('Content not found: $id');
    }
  }

  Future<void> createContent() async {
    _error = null;
    _setLoading(true);

    try {
      // Show file picker for image
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Ensure we get the file data on all platforms
      );

      if (result == null || result.files.isEmpty) {
        throw Exception('No image selected');
      }

      final file = File(result.files.first.path!);
      final files = [file];
      
      // Create new content with the selected image
      final content = await _service.createContent(
        name: 'New Content',
        description: 'Description',
        standardName: 'W3-Gamified-NFT',
        standardVersion: '1.0.0',
        standardData: {
          'code': 'CODE123',
          'owner': '1234567890abcdef',
          'nonce': 1,
          'image': file.path,
        },
        files: files,
      );

      _currentContent = content;
      _currentFiles = files;
      _contents = _service.getAllContents();
      notifyListeners();
    } catch (e) {
      _setError('Failed to create content: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> importContent() async {
    _error = null;
    _setLoading(true);

    try {
      // Show file picker for .pcontent file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Use any type to avoid extension filtering issues
        withData: true, // Ensure we get the file data on all platforms
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        throw Exception('No file selected');
      }

      final filePath = result.files.first.path!;
      if (!filePath.toLowerCase().endsWith('.pcontent')) {
        throw Exception('Please select a .pcontent file');
      }

      final file = File(filePath);
      final importResult = await _service.importContent(file);
      _currentContent = importResult.$1;
      _currentFiles = importResult.$2;
      _contents = _service.getAllContents();
      notifyListeners();
    } catch (e) {
      _setError('Failed to import content: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<File?> exportContent({bool returnFile = false, File? targetFile}) async {
    if (_currentContent == null) {
      return null;
    }

    try {
      final content = _currentContent!;
      
      // If no target file is provided, create one
      File file;
      if (targetFile != null) {
        file = targetFile;
      } else {
        final fileName = '${content.name.replaceAll(' ', '_')}_${content.id.substring(0, 8)}.pcontent';
        if (returnFile) {
          // Create in temp directory if returning the file
          final tempDir = await getTemporaryDirectory();
          final filePath = p.join(tempDir.path, fileName);
          file = File(filePath);
        } else {
          // Create in downloads directory if not returning
          final downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir == null) {
            throw Exception('Could not access Downloads directory');
          }
          final targetPath = p.join(downloadsDir.path, fileName);
          file = File(targetPath);
        }
      }

      // Create the export file
      await _service.exportContent(content, file);

      if (returnFile) {
        return file;
      }

      notifyListeners();
      return null;
    } catch (e) {
      print('Error exporting content: $e');
      rethrow;
    }
  }

  Future<bool> verifyContent() async {
    print('\nStarting content verification...');
    if (_currentContent == null || _currentFiles == null) {
      print('No content to verify');
      _setError('No content to verify');
      return false;
    }

    _error = null;
    _setLoading(true);

    try {
      print('Verifying content: ${_currentContent!.name} (${_currentContent!.id})');
      print('Number of files: ${_currentFiles!.length}');
      final isValid = await _service.verifyContent(_currentContent!, _currentFiles!);
      if (!isValid) {
        print('Content verification failed');
        _setError('Content verification failed');
      } else {
        print('Content verification successful');
      }
      return isValid;
    } catch (e) {
      print('Error during verification: $e');
      _setError('Content verification failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteContent(String id) async {
    _error = null;
    _setLoading(true);

    try {
      await _service.deleteContent(id);
      if (_currentContent?.id == id) {
        _currentContent = null;
        _currentFiles = null;
      }
      _contents = _service.getAllContents();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete content: $e');
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
