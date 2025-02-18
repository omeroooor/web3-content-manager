import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<void> exportContent() async {
    print('\nStarting content export...');
    if (_currentContent == null || _currentFiles == null) {
      print('No content to export: currentContent=${_currentContent != null}, currentFiles=${_currentFiles != null}');
      _setError('No content to export');
      return;
    }

    print('Exporting content: ${_currentContent!.name} (${_currentContent!.id})');
    print('Number of files: ${_currentFiles!.length}');

    _error = null;
    _setLoading(true);

    try {
      print('Creating temporary export file...');
      // Export to temporary file first
      final tempFile = await _service.exportContent(_currentContent!, _currentFiles!);
      print('Temporary file created at: ${tempFile.path}');
      print('Temporary file exists: ${await tempFile.exists()}');
      print('Temporary file size: ${await tempFile.length()} bytes');

      // Get the downloads directory
      final downloadsDir = await getExternalStorageDirectory();
      if (downloadsDir == null) {
        throw Exception('Could not access downloads directory');
      }
      
      print('Downloads directory: ${downloadsDir.path}');
      final fileName = '${_currentContent!.name}.pcontent';
      final targetPath = '${downloadsDir.path}/$fileName';
      print('Target path: $targetPath');

      // Copy the file to downloads
      print('Copying file to downloads...');
      final targetFile = await tempFile.copy(targetPath);
      print('File copied successfully to: ${targetFile.path}');
      
      // Clean up the temp file
      print('Cleaning up temporary file...');
      await tempFile.delete();
      print('Temporary file deleted');
      
      print('Export completed successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      print('Export error: $e');
      print('Stack trace: $stackTrace');
      _setError('Failed to export content: $e');
    } finally {
      _setLoading(false);
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
