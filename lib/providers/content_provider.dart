import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/content_part.dart';
import '../services/content_service.dart';
import '../standards/w3_gamified_nft.dart';
import '../standards/content_standard.dart';

class ContentProvider with ChangeNotifier {
  final ContentService _service = ContentService();
  final Map<String, ContentStandard> _standards = {
    'W3-Gamified-NFT': W3GamifiedNFTStandard(),
  };

  PortableContent? _currentContent;
  List<File>? _currentFiles;
  bool _isLoading = false;
  String? _error;

  PortableContent? get currentContent => _currentContent;
  List<File>? get currentFiles => _currentFiles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<void> createNewContent({
    required String name,
    required String description,
    required String standardName,
    required Map<String, dynamic> standardData,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Get the standard
      final standard = _standards[standardName];
      if (standard == null) {
        throw Exception('Unknown standard: $standardName');
      }

      // Pick files
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        _setError('No files selected');
        return;
      }

      final files = result.files
          .map((file) => File(file.path!))
          .toList();

      // For W3-Gamified-NFT, we need to compute the image checksum
      if (standardName == 'W3-Gamified-NFT') {
        final imageFile = files.firstWhere(
          (file) => file.path.toLowerCase().endsWith('.png') || 
                    file.path.toLowerCase().endsWith('.jpg') ||
                    file.path.toLowerCase().endsWith('.jpeg'),
          orElse: () => throw Exception('Please include an image file'),
        );

        final imageBytes = await imageFile.readAsBytes();
        final imageChecksum = await _service.computeHash(imageBytes);
        standardData['imageChecksum'] = imageChecksum;
      }

      // Create content with standard
      _currentContent = await _service.createContent(
        name: name,
        description: description,
        standardName: standardName,
        standardVersion: standard.version,
        standardData: standardData,
        files: files,
      );
      
      _currentFiles = files;
      notifyListeners();
    } catch (e) {
      _setError('Failed to create content: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> exportContent() async {
    if (_currentContent == null || _currentFiles == null) {
      _setError('No content to export');
      return;
    }

    try {
      _setLoading(true);
      _setError(null);

      // Create temporary export file
      final exportedFile = await _service.exportContent(_currentContent!, _currentFiles!);
      
      // Show save file dialog
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Portable Content',
        fileName: '${_currentContent!.name}.pcontent',
        allowedExtensions: ['pcontent'],
        type: FileType.custom,
      );

      if (outputPath == null) {
        _setError('Export cancelled');
        return;
      }

      // Ensure the file has .pcontent extension
      if (!outputPath.toLowerCase().endsWith('.pcontent')) {
        outputPath = '$outputPath.pcontent';
      }

      // Copy the temporary file to the selected location
      await exportedFile.copy(outputPath);
      
      // Delete the temporary file
      await exportedFile.delete();

    } catch (e) {
      _setError('Failed to export content: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> importContent() async {
    try {
      _setLoading(true);
      _setError(null);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pcontent'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        _setError('No file selected');
        return;
      }

      final file = File(result.files.first.path!);
      final (content, files) = await _service.importContent(file);
      
      // Validate against standard
      final standard = _standards[content.standardName];
      if (standard == null) {
        throw Exception('Unknown standard: ${content.standardName}');
      }

      await standard.validateData(content.standardData, files);
      
      _currentContent = content;
      _currentFiles = files;
      notifyListeners();
    } catch (e) {
      _setError('Failed to import content: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyContent() async {
    if (_currentContent == null || _currentFiles == null) {
      _setError('No content to verify');
      return false;
    }

    try {
      _setLoading(true);
      _setError(null);

      // Get the standard
      final standard = _standards[_currentContent!.standardName];
      if (standard == null) {
        throw Exception('Unknown standard: ${_currentContent!.standardName}');
      }

      // Verify content against standard
      await standard.validateData(_currentContent!.standardData, _currentFiles!);

      // Verify file hashes
      final isValid = await _service.verifyContent(_currentContent!, _currentFiles!);
      return isValid;
    } catch (e) {
      _setError('Failed to verify content: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearContent() {
    _currentContent = null;
    _currentFiles = null;
    _error = null;
    notifyListeners();
  }
}
