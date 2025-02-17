import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../models/content_part.dart';

class ContentListScreen extends StatelessWidget {
  const ContentListScreen({super.key});

  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<Widget> _buildImagePreview(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print('Image preview error: $error');
          return const Icon(Icons.broken_image, size: 100);
        },
      );
    } catch (e) {
      print('Error reading image file: $e');
      return const Icon(Icons.broken_image, size: 100);
    }
  }

  void _showFilePreview(BuildContext context, File file, String name) async {
    print('Opening preview for: ${file.path}');
    
    Widget previewWidget;
    if (_isImageFile(name)) {
      previewWidget = await _buildImagePreview(file);
    } else {
      previewWidget = const Icon(Icons.file_present, size: 100);
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(name),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: previewWidget,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  bool _isImageFile(String path) {
    final ext = path.toLowerCase();
    return ext.contains('.png') || 
           ext.contains('.jpg') || 
           ext.contains('.jpeg') || 
           ext.contains('.gif') || 
           ext.contains('.webp');
  }

  Widget _buildFilePreview(BuildContext context, File file, String name) {
    print('Building preview for: ${file.path}');
    return Card(
      child: InkWell(
        onTap: () => _showFilePreview(context, file, name),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isImageFile(name))
                FutureBuilder<Uint8List>(
                  future: file.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      print('Thumbnail error: ${snapshot.error}');
                      return const Icon(Icons.broken_image, size: 50);
                    }
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 100,
                        width: 100,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return SizedBox(
                      height: 100,
                      width: 100,
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Thumbnail error: $error');
                          return const Icon(Icons.broken_image, size: 50);
                        },
                      ),
                    );
                  },
                )
              else
                const Icon(Icons.file_present, size: 50),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, contentProvider, child) {
        if (contentProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (contentProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: ${contentProvider.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
                _buildActionButtons(context, contentProvider),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Portable Contents'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => contentProvider.refresh(),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildActionButtons(context, contentProvider),
              const Divider(),
              Expanded(
                child: contentProvider.contents.isEmpty
                    ? const Center(
                        child: Text('No contents yet. Create or import one!'),
                      )
                    : ListView.builder(
                        itemCount: contentProvider.contents.length,
                        itemBuilder: (context, index) {
                          final content = contentProvider.contents[index];
                          final isSelected = content.id == contentProvider.currentContent?.id;

                          return ListTile(
                            title: Text(content.name),
                            subtitle: Text(content.description),
                            selected: isSelected,
                            leading: Icon(
                              Icons.description,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => contentProvider.deleteContent(content.id),
                            ),
                            onTap: () {
                              contentProvider.selectContent(content.id);
                              _showContentDetails(context, contentProvider);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showContentDetails(BuildContext context, ContentProvider contentProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => _buildContentDetails(
          context,
          contentProvider,
          scrollController,
        ),
      ),
    );
  }

  Widget _buildContentDetails(
    BuildContext context,
    ContentProvider contentProvider,
    ScrollController scrollController,
  ) {
    final content = contentProvider.currentContent!;
    final files = contentProvider.currentFiles!;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 40,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'Content Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Name: ${content.name}'),
                Text('Description: ${content.description}'),
                Text('Standard: ${content.standardName} v${content.standardVersion}'),
                Text('Created: ${content.createdAt}'),
                Text('Updated: ${content.updatedAt}'),
                Text('Content Hash: ${content.contentHash}'),
                const SizedBox(height: 16),
                Text(
                  'Files:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: content.parts.length,
                    itemBuilder: (context, index) {
                      final part = content.parts[index];
                      final file = files[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFilePreview(context, file, part.name),
                            Text(
                              '${(part.size / 1024).toStringAsFixed(1)} KB',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'Hash: ${part.hash.substring(0, 8)}...',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ContentProvider contentProvider) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          ElevatedButton.icon(
            onPressed: () => contentProvider.createContent(),
            icon: const Icon(Icons.add),
            label: const Text('Create Content'),
          ),
          ElevatedButton.icon(
            onPressed: () => contentProvider.importContent(),
            icon: const Icon(Icons.file_upload),
            label: const Text('Import Content'),
          ),
          if (contentProvider.currentContent != null) ...[
            ElevatedButton.icon(
              onPressed: () => contentProvider.exportContent(),
              icon: const Icon(Icons.file_download),
              label: const Text('Export Content'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final isValid = await contentProvider.verifyContent();
                  if (context.mounted) {
                    _showMessage(
                      context,
                      isValid 
                        ? 'Content verification successful!' 
                        : 'Content verification failed',
                      isError: !isValid,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showMessage(context, 'Verification error: $e', isError: true);
                  }
                }
              },
              icon: const Icon(Icons.verified),
              label: const Text('Verify Content'),
            ),
          ],
        ],
      ),
    );
  }
}
