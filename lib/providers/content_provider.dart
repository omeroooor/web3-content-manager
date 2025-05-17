import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/content_part.dart';
import '../services/content_service.dart';
import '../widgets/standard_content_form_dialog.dart';
import 'package:permission_handler/permission_handler.dart';

class ContentProvider with ChangeNotifier {
  final _service = ContentService();
  List<PortableContent> _contents = [];
  PortableContent? _currentContent;
  List<File>? _currentFiles;
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _selectedStandard;
  bool _showRegisteredOnly = false;

  ContentProvider() {
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

  List<PortableContent> get contents {
    var filteredContents = _contents;
    
    // Apply standard filter if selected
    if (_selectedStandard != null) {
      filteredContents = filteredContents.where(
        (content) => content.standardName == _selectedStandard
      ).toList();
    }

    // Apply search query if not empty
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredContents = filteredContents.where((content) {
        return content.name.toLowerCase().contains(query) ||
            content.contentHash.toLowerCase().contains(query) ||
            content.standardName.toLowerCase().contains(query) ||
            content.description.toLowerCase().contains(query);
      }).toList();
    }

    // Apply registered filter if enabled
    if (_showRegisteredOnly) {
      filteredContents = filteredContents.where((content) => content.rps > 0).toList();
    }

    return filteredContents;
  }

  // Get unique list of standards from content
  List<String> get availableStandards {
    return _contents
        .map((content) => content.standardName)
        .toSet()
        .toList()
      ..sort();
  }

  PortableContent? get currentContent => _currentContent;
  List<File>? get currentFiles => _currentFiles;
  String? get selectedStandard => _selectedStandard;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  bool get showRegisteredOnly => _showRegisteredOnly;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void setSelectedStandard(String? standard) {
    _selectedStandard = standard;
    notifyListeners();
  }

  void setShowRegisteredOnly(bool value) {
    _showRegisteredOnly = value;
    notifyListeners();
  }

  void clearFilters() {
    _selectedStandard = null;
    _searchQuery = '';
    _showRegisteredOnly = false;
    notifyListeners();
  }

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

  Future<void> createContent(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const StandardContentFormDialog(),
    );

    if (result != null) {
      try {
        _isLoading = true;
        notifyListeners();

        final standardName = result['standard'] as String;
        final files = <File>[];
        if (result.containsKey('mediaFile')) {
          final mediaPath = result['mediaFile'] as String;
          if (mediaPath.isNotEmpty) {
            files.add(File(mediaPath));
          }
        }

        final standardData = Map<String, dynamic>.from(result)
          ..remove('standard')
          ..remove('mediaFile');

        print('Initial standardData: $standardData');

        // Create the content
        final content = await _service.createContent(
          name: standardData['name'],
          description: standardData['description'],
          standardName: standardName,
          standardVersion: '1.0.0',
          standardData: standardData,
          files: files,
        );

        _contents.add(content);
        notifyListeners();
      } catch (e) {
        _error = e.toString();
        notifyListeners();
        rethrow;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
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

  Future<File> exportContent(String? contentId, {File? targetFile}) async {
    try {
      final content = contentId != null 
          ? contents.firstWhere((c) => c.id == contentId)
          : _currentContent!;
          
      if (content == null) {
        throw Exception('No content selected for export');
      }

      final file = targetFile ?? await _createExportFile(content);
      await _service.exportContent(content, file);
      return file;
    } catch (e) {
      rethrow;
    }
  }

  Future<File> _createExportFile(PortableContent content) async {
    final exportDir = await _getExportDirectory();
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final fileName = '${content.name.replaceAll(' ', '_')}.pcontent';
    return File(p.join(exportDir.path, fileName));
  }

  Future<Directory> _getExportDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Request storage permissions on Android
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission is required to export content');
        }
        
        // Get the Downloads directory using getExternalStorageDirectory
        final baseDir = await getExternalStorageDirectory();
        if (baseDir == null) {
          throw Exception('Could not access external storage');
        }
        
        // Navigate up to find the root external storage
        String? downloadsPath;
        List<String> paths = baseDir.path.split('/');
        int index = paths.indexOf('Android');
        if (index > 0) {
          downloadsPath = paths.sublist(0, index).join('/') + '/Download';
        } else {
          // Fallback if we can't find the Android directory
          downloadsPath = baseDir.path + '/Download';
        }
        
        final downloadsDir = Directory(downloadsPath);
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      } else {
        // Use the platform-specific documents directory for other platforms
        final directory = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${directory.path}/Downloads');
        return downloadsDir;
      }
    } catch (e) {
      // Fallback to app documents directory if we can't get the downloads directory
      final directory = await getApplicationDocumentsDirectory();
      return directory;
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

  void updateContentProfile(String contentId, String owner, int rps) {
    final index = _contents.indexWhere((content) => content.id == contentId);
    if (index != -1) {
      final content = _contents[index];
      _contents[index] = PortableContent(
        id: content.id,
        name: content.name,
        description: content.description,
        standardName: content.standardName,
        standardVersion: content.standardVersion,
        standardData: content.standardData,
        contentHash: content.contentHash,
        parts: content.parts,
        createdAt: content.createdAt,
        updatedAt: content.updatedAt,
        owner: owner,
        rps: rps,
      );
      if (_currentContent?.id == contentId) {
        _currentContent = _contents[index];
      }

      // Persist the changes
      _service.updateContent(_contents[index]);
      
      notifyListeners();
    }
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
