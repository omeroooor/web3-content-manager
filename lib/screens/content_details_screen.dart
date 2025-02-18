import 'package:flutter/material.dart';
import '../models/content_part.dart';
import '../providers/content_provider.dart';
import 'package:provider/provider.dart';

class ContentDetailsScreen extends StatelessWidget {
  final PortableContent content;

  const ContentDetailsScreen({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(content.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement sharing
            },
            tooltip: 'Share',
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
                      await contentProvider.verifyContent();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_download),
                    title: const Text('Export Content'),
                    onTap: () {
                      final contentProvider = context.read<ContentProvider>();
                      contentProvider.exportContent();
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
        ],
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
