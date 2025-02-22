import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../providers/bitcoin_provider.dart';
import '../models/content_part.dart';
import 'content_details_screen.dart';

class ContentListScreen extends StatefulWidget {
  const ContentListScreen({super.key});

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
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
    final contentProvider = context.read<ContentProvider>();
    
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

              // Schedule profile update for after the build
              if (profile != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    final content = contentProvider.contents.firstWhere(
                      (content) => content.contentHash == contentHash,
                      orElse: () => throw Exception('Content not found'),
                    );
                    contentProvider.updateContentProfile(
                      content.id,
                      profile['owner'] as String,
                      profile['rps'] as int,
                    );
                  } catch (e) {
                    print('Error updating content profile: $e');
                  }
                });
              }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ContentProvider>(
        builder: (context, provider, child) {
          final contents = provider.contents;
          
          if (contents.isEmpty) {
            return const Center(
              child: Text('No contents found'),
            );
          }

          return ListView.builder(
            itemCount: contents.length,
            itemBuilder: (context, index) {
              final content = contents[index];
              final id = content.id;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Stack(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(
                        content.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (content.description.split('\n').length > 2 ||
                              content.description.length > 100)
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ContentDetailsScreen(content: content),
                                  ),
                                );
                              },
                              child: const Text(
                                'Read more...',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ContentDetailsScreen(content: content),
                          ),
                        );
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => _showContentDetails(context, content),
                            tooltip: 'Details',
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_box_outlined),
                            onPressed: () =>
                                _showProfileDialog(context, content.contentHash),
                            tooltip: 'Profile',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteContent(context, content.id),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ),
                    if (content.rps > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
