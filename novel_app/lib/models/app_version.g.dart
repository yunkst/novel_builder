// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_version.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppVersion _$AppVersionFromJson(Map<String, dynamic> json) => AppVersion(
      version: json['version'] as String,
      versionCode: (json['versionCode'] as num).toInt(),
      downloadUrl: json['downloadUrl'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      changelog: json['changelog'] as String?,
      forceUpdate: json['forceUpdate'] as bool,
      createdAt: json['createdAt'] as String,
    );

Map<String, dynamic> _$AppVersionToJson(AppVersion instance) =>
    <String, dynamic>{
      'version': instance.version,
      'versionCode': instance.versionCode,
      'downloadUrl': instance.downloadUrl,
      'fileSize': instance.fileSize,
      'changelog': instance.changelog,
      'forceUpdate': instance.forceUpdate,
      'createdAt': instance.createdAt,
    };
