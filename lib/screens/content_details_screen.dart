import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/content_part.dart';
import '../providers/content_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:archive/archive.dart';

class ContentDetailsScreen extends StatelessWidget {
  final PortableContent content;

  const ContentDetailsScreen({
    super.key,
    required this.content,
  });

  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<String> _createShareText(PortableContent content) async {
    return '''
Content Details:
Name: ${content.name}
Description: ${content.description}
ID: ${content.id}
Standard: ${content.standardName} v${content.standardVersion}
Created: ${content.createdAt}

Note: The content file is attached to this share.
''';
  }

  Future<void> _shareContent(BuildContext context) async {
    try {
      final provider = context.read<ContentProvider>();
      final tempDir = await getTemporaryDirectory();
      final exportFile = File('${tempDir.path}/share_content.pcontent');
      
      // Export the content to a temporary file
      await provider.exportContent(null, targetFile: exportFile);
      
      // Create share text
      final shareText = await _createShareText(content);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(exportFile.path)],
        text: shareText,
      );

      // Clean up the temporary file
      if (await exportFile.exists()) {
        await exportFile.delete();
      }
    } catch (e) {
      _showMessage(context, 'Failed to share content: $e', isError: true);
    }
  }

  Future<void> _sendReputation() async {
    final uri = Uri.parse('bluewallet:send?addresses=${content.contentHash}-0.001-reputation');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch BlueWallet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(content.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareContent(context),
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.monetization_on_outlined),
            onPressed: _sendReputation,
            tooltip: 'Send Reputation',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Content Info Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'ID',
                    value: content.id,
                  ),
                  _InfoRow(
                    label: 'Name',
                    value: content.name,
                  ),
                  _InfoRow(
                    label: 'Description',
                    value: content.description,
                  ),
                  _InfoRow(
                    label: 'Content Hash',
                    value: content.contentHash,
                  ),
                  _InfoRow(
                    label: 'Created',
                    value: content.createdAt.toString(),
                  ),
                  _InfoRow(
                    label: 'Owner',
                    value: content.owner.isEmpty ? 'Not Set' : content.owner,
                  ),
                  _InfoRow(
                    label: 'Reputation Score',
                    value: content.rps.toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Actions Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.verified),
                    title: const Text('Verify Content'),
                    onTap: () async {
                      final contentProvider = context.read<ContentProvider>();
                      contentProvider.selectContent(content.id);
                      
                      // Show loading indicator
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text('Verifying content...'),
                              ],
                            ),
                            duration: Duration(seconds: 30), // Long duration as default
                            behavior: SnackBarBehavior.floating,
                            margin: EdgeInsets.all(8),
                          ),
                        );
                      }

                      try {
                        final isValid = await contentProvider.verifyContent();
                        // Hide the loading indicator
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        
                        if (context.mounted) {
                          if (isValid) {
                            _showMessage(
                              context,
                              'Content verification successful! All files are valid.',
                            );
                          } else {
                            _showMessage(
                              context,
                              'Content verification failed. Files may be corrupted or missing.',
                              isError: true,
                            );
                          }
                        }
                      } catch (e) {
                        // Hide the loading indicator
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        
                        if (context.mounted) {
                          _showMessage(
                            context,
                            'Verification error: $e',
                            isError: true,
                          );
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.save),
                    title: const Text('Export Content'),
                    onTap: () async {
                      try {
                        final contentProvider = context.read<ContentProvider>();
                        await contentProvider.exportContent(content.id);
                        _showMessage(context, 'Content exported successfully');
                      } catch (e) {
                        _showMessage(
                          context,
                          'Failed to export content: $e',
                          isError: true,
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Delete Content'),
                    textColor: Theme.of(context).colorScheme.error,
                    iconColor: Theme.of(context).colorScheme.error,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Content'),
                          content: const Text(
                            'Are you sure you want to delete this content? This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () {
                                final contentProvider = context.read<ContentProvider>();
                                contentProvider.deleteContent(content.id);
                                Navigator.of(context).pop(); // Close dialog
                                Navigator.of(context).pop(); // Go back to list
                              },
                              child: Text(
                                'DELETE',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (content.standardName == 'W3-S-POST-NFT') ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post Content',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(content.standardData['text'] as String),
                    if (content.standardData.containsKey('mediaPath')) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Media Path',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(content.standardData['mediaPath']?.toString() ?? 'No media path available'),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendReputation,
        icon: const Icon(Icons.monetization_on_outlined),
        label: const Text('Send Reputation'),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
