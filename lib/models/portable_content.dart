import 'dart:io';

class PortableContent {
  final String id;
  final String name;
  final String description;
  final String contentHash;
  final int createdAt;
  final File imageFile;

  PortableContent({
    required this.id,
    required this.name,
    required this.description,
    required this.contentHash,
    required this.createdAt,
    required this.imageFile,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'contentHash': contentHash,
      'createdAt': createdAt,
      'imagePath': imageFile.path,
    };
  }

  factory PortableContent.fromJson(Map<String, dynamic> json) {
    return PortableContent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      contentHash: json['contentHash'] as String,
      createdAt: json['createdAt'] as int,
      imageFile: File(json['imagePath'] as String),
    );
  }

  @override
  String toString() {
    return 'PortableContent(id: $id, name: $name, description: $description, contentHash: $contentHash, createdAt: $createdAt)';
  }
}
