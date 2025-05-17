import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/content_service.dart';

class StandardContentFormDialog extends StatefulWidget {
  const StandardContentFormDialog({super.key});

  @override
  State<StandardContentFormDialog> createState() => _StandardContentFormDialogState();
}

class _StandardContentFormDialogState extends State<StandardContentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _textController = TextEditingController();
  final _codeController = TextEditingController();
  final _ownerController = TextEditingController();
  final _nonceController = TextEditingController(text: '1');
  
  String _selectedStandard = 'W3-Gamified-NFT';
  File? _mediaFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _textController.dispose();
    _codeController.dispose();
    _ownerController.dispose();
    _nonceController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      setState(() => _isLoading = true);
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov'],
      );

      if (result != null) {
        setState(() {
          _mediaFile = File(result.files.single.path!);
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildGamifiedNFTFields() {
    return Column(
      children: [
        TextFormField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: 'Code',
            hintText: 'Enter content code',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a code';
            }
            return null;
          },
        ),
        TextFormField(
          controller: _ownerController,
          decoration: const InputDecoration(
            labelText: 'Owner',
            hintText: 'Enter owner address (hex)',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an owner address';
            }
            if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
              return 'Owner must be a hex string';
            }
            return null;
          },
        ),
        TextFormField(
          controller: _nonceController,
          decoration: const InputDecoration(
            labelText: 'Nonce',
            hintText: 'Enter nonce value',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a nonce';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                _mediaFile != null
                    ? 'Selected: ${_mediaFile!.path.split('/').last}'
                    : 'No media selected',
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickMedia,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Image'),
            ),
          ],
        ),
        if (_mediaFile != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _mediaFile = null),
            icon: const Icon(Icons.clear),
            label: const Text('Remove Image'),
          ),
        ],
      ],
    );
  }

  Widget _buildSimplePostFields() {
    return Column(
      children: [
        TextFormField(
          controller: _textController,
          decoration: const InputDecoration(
            labelText: 'Post Text',
            hintText: 'Enter your post text',
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter post text';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                _mediaFile != null
                    ? 'Selected: ${_mediaFile!.path.split('/').last}'
                    : 'No media selected',
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickMedia,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Media'),
            ),
          ],
        ),
        if (_mediaFile != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _mediaFile = null),
            icon: const Icon(Icons.clear),
            label: const Text('Remove Media'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Content'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedStandard,
                decoration: const InputDecoration(
                  labelText: 'Content Standard',
                ),
                items: [
                  'W3-Gamified-NFT',
                  'W3-S-POST-NFT',
                ].map((standard) {
                  return DropdownMenuItem(
                    value: standard,
                    child: Text(standard),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStandard = value;
                      _mediaFile = null; // Clear media file when switching standards
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter content name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter content description',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              if (_selectedStandard == 'W3-Gamified-NFT')
                _buildGamifiedNFTFields()
              else
                _buildSimplePostFields(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_formKey.currentState!.validate()) {
                    final result = {
                      'standard': _selectedStandard,
                      'name': _nameController.text,
                      'description': _descriptionController.text,
                    };

                    if (_selectedStandard == 'W3-Gamified-NFT') {
                      if (_mediaFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select an image file'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      result.addAll({
                        'code': _codeController.text,
                        'owner': _ownerController.text,
                        'nonce': _nonceController.text,
                        'mediaFile': _mediaFile!.path,
                      });
                    } else {
                      result.addAll({
                        'text': _textController.text,
                        if (_mediaFile != null) 'mediaFile': _mediaFile!.path,
                      });
                    }

                    Navigator.of(context).pop(result);
                  }
                },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
