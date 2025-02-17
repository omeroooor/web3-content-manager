import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../providers/bitcoin_provider.dart';
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

  void _showContentDetails(BuildContext context, PortableContent content) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Description: ${content.description}'),
              const SizedBox(height: 8),
              Text('Standard: ${content.standardName} v${content.standardVersion}'),
              const SizedBox(height: 8),
              Text('Content Hash: ${content.contentHash}'),
              const SizedBox(height: 16),
              const Text('Files:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...content.parts.map((part) => Text(
                    '${part.name} (${part.size} bytes)',
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteContent(BuildContext context, String contentId) {
    final contentProvider = context.read<ContentProvider>();
    contentProvider.deleteContent(contentId);
    _showMessage(context, 'Content deleted');
  }

  void _showProfileDialog(BuildContext context, String contentHash) {
    print('\nShowing profile dialog for hash: $contentHash');
    final bitcoinProvider = context.read<BitcoinProvider>();
    
    // Immediately fetch the profile data
    bitcoinProvider.fetchProfile(contentHash);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Consumer<BitcoinProvider>(
            builder: (context, provider, child) {
              print('Rebuilding profile dialog, loading: ${provider.isLoading}, error: ${provider.error}');
              final profile = provider.getProfile(contentHash);
              print('Current profile data: $profile');

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Content Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (provider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (provider.error != null)
                    Text(
                      'Error: ${provider.error}',
                      style: const TextStyle(color: Colors.red),
                    )
                  else if (profile != null) ...[
                    Text('RPS: ${profile['rps']}'),
                    const SizedBox(height: 8),
                    Text('Owner: ${profile['owner']}'),
                    const SizedBox(height: 8),
                    Text(
                      profile['isRented']
                          ? 'Currently rented by: ${profile['tenant']}'
                          : 'Not currently rented',
                    ),
                  ] else
                    const Text('No profile data available'),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => provider.fetchProfile(contentHash),
                      child: const Text('Refresh Profile'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContentActions(BuildContext context, String contentId, PortableContent content) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showContentDetails(context, content),
          tooltip: 'View Details',
        ),
        IconButton(
          icon: const Icon(Icons.account_box_outlined),
          onPressed: () => _showProfileDialog(context, content.contentHash),
          tooltip: 'View Profile',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteContent(context, contentId),
          tooltip: 'Delete',
        ),
      ],
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
                ElevatedButton(
                  onPressed: () => contentProvider.refresh(),
                  child: const Text('Retry'),
                ),
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
              Padding(
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
              ),
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
                              color: isSelected ? Theme.of(context).colorScheme.primary : null,
                            ),
                            trailing: _buildContentActions(context, content.id, content),
                            onTap: () {
                              contentProvider.selectContent(content.id);
                              _showContentDetails(context, content);
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
}
