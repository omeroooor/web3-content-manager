import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../providers/electrum_provider.dart';
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
    final electrumProvider = context.read<ElectrumProvider>();
    final contentProvider = context.read<ContentProvider>();
    
    // Immediately fetch the profile data
    electrumProvider.fetchProfile(contentHash);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Consumer<ElectrumProvider>(
            builder: (context, provider, child) {
              print('Rebuilding profile dialog, loading: ${provider.isLoading}, error: ${provider.error}');
              
              if (provider.isLoading) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching profile data...'),
                  ],
                );
              }

              if (provider.error != null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Error: ${provider.error}'),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        provider.fetchProfile(contentHash);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }

              final profile = provider.getProfile(contentHash);
              print('Current profile data: $profile');

              if (profile == null) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                    SizedBox(height: 16),
                    Text('No profile data found'),
                  ],
                );
              }

              // Schedule profile update for after the build
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

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Owner: ${profile['owner']}'),
                  const SizedBox(height: 8),
                  Text('RPS: ${profile['rps']}'),
                  const SizedBox(height: 8),
                  Text('Tenant: ${profile['tenent']}'),
                  const SizedBox(height: 8),
                  if (profile['rentedAt'] != null && profile['rentedAt'] > 0)
                    Text('Rented At: ${DateTime.fromMillisecondsSinceEpoch(profile['rentedAt'] * 1000)}'),
                  const SizedBox(height: 8),
                  if (profile['duration'] != null && profile['duration'] > 0)
                    Text('Duration: ${profile['duration']} seconds'),
                  const SizedBox(height: 8),
                  Text('Owned Profiles: ${profile['ownedProfiles']}'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          provider.fetchProfile(contentHash);
                        },
                        child: const Text('Refresh'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Close'),
                      ),
                    ],
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
