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

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, contentProvider, child) {
        Widget mainContent = Scaffold(
          body: contentProvider.contents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.note_add,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No content yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use + to create or ↑ to import content',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: contentProvider.contents.length,
                  itemBuilder: (context, index) {
                    final content = contentProvider.contents[index];
                    final id = content.id;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(
                          content.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(content.description),
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
                              onPressed: () => _deleteContent(context, id),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );

        // Show loading indicator as an overlay
        if (contentProvider.isLoading) {
          mainContent = Stack(
            children: [
              mainContent,
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return mainContent;
      },
    );
  }
}
