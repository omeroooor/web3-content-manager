// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_part.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContentPart _$ContentPartFromJson(Map<String, dynamic> json) => ContentPart(
      id: json['id'] as String,
      name: json['name'] as String,
      hash: json['hash'] as String,
      mimeType: json['mimeType'] as String,
      size: (json['size'] as num).toInt(),
    );

Map<String, dynamic> _$ContentPartToJson(ContentPart instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'hash': instance.hash,
      'mimeType': instance.mimeType,
      'size': instance.size,
    };

PortableContent _$PortableContentFromJson(Map<String, dynamic> json) =>
    PortableContent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      standardName: json['standardName'] as String,
      standardVersion: json['standardVersion'] as String,
      standardData: json['standardData'] as Map<String, dynamic>,
      contentHash: json['contentHash'] as String,
      parts: (json['parts'] as List<dynamic>)
          .map((e) => ContentPart.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$PortableContentToJson(PortableContent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'standardName': instance.standardName,
      'standardVersion': instance.standardVersion,
      'standardData': instance.standardData,
      'contentHash': instance.contentHash,
      'parts': instance.parts,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
