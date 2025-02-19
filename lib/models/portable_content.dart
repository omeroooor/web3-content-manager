import 'dart:io';

class PortableContent {
  final String id;
  final String name;
  final String description;
  final String contentHash;
  final int createdAt;
  final File imageFile;
  final String owner;
  final int rps;

  PortableContent({
    required this.id,
    required this.name,
    required this.description,
    required this.contentHash,
    required this.createdAt,
    required this.imageFile,
    this.owner = "",
    this.rps = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'contentHash': contentHash,
      'createdAt': createdAt,
      'imagePath': imageFile.path,
      'owner': owner,
      'rps': rps,
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
      owner: (json['owner'] as String?) ?? "",
      rps: (json['rps'] as int?) ?? 0,
    );
  }

  @override
  String toString() {
    return 'PortableContent(id: $id, name: $name, description: $description, contentHash: $contentHash, createdAt: $createdAt, owner: $owner, rps: $rps)';
  }
}
