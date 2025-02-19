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

class _ContentListScreenState extends State<ContentListScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isDialOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSpeedDial() {
    setState(() {
      _isDialOpen = !_isDialOpen;
      if (_isDialOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _closeSpeedDial() {
    if (_isDialOpen) {
      setState(() {
        _isDialOpen = false;
        _controller.reverse();
      });
    }
  }

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

  Widget _buildSpeedDial(BuildContext context, ContentProvider contentProvider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isDialOpen) ...[
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOut,
            )),
            child: _SpeedDialChild(
              icon: Icons.add,
              label: 'Create Content',
              onTap: () {
                _closeSpeedDial();
                contentProvider.createContent(context);
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOut,
            )),
            child: _SpeedDialChild(
              icon: Icons.file_upload,
              label: 'Import Content',
              onTap: () {
                _closeSpeedDial();
                contentProvider.importContent();
              },
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 8),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOut,
            )),
            child: _SpeedDialChild(
              icon: Icons.file_download,
              label: 'Export Content',
              onTap: () {
                _closeSpeedDial();
                contentProvider.exportContent();
              },
              backgroundColor: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOut,
            )),
            child: _SpeedDialChild(
              icon: Icons.verified,
              label: 'Verify Content',
              onTap: () async {
                _closeSpeedDial();
                try {
                  final isValid = await contentProvider.verifyContent();
                  if (context.mounted) {
                    _showMessage(
                      context,
                      isValid ? 'Content verification successful!' : 'Content verification failed',
                      isError: !isValid,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showMessage(context, 'Verification error: $e', isError: true);
                  }
                }
              },
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          onPressed: _toggleSpeedDial,
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _controller,
          ),
        ),
      ],
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
                        'Tap + to create or import content',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 80, // Add extra padding at the bottom for FAB
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
          floatingActionButton: _buildSpeedDial(context, contentProvider),
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

        // Show error as a banner if present
        if (contentProvider.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showMaterialBanner(
              MaterialBanner(
                content: Text(contentProvider.error!),
                leading: const Icon(Icons.error_outline, color: Colors.red),
                actions: [
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                      contentProvider.clearError();
                    },
                    child: const Text('DISMISS'),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                      contentProvider.refresh();
                    },
                    child: const Text('RETRY'),
                  ),
                ],
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                contentTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            );
          });
        }

        return GestureDetector(
          onTap: _closeSpeedDial,
          child: mainContent,
        );
      },
    );
  }
}

class _SpeedDialChild extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;

  const _SpeedDialChild({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                color: backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
