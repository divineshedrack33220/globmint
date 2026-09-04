// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DeviceImpl _$$DeviceImplFromJson(Map<String, dynamic> json) => _$DeviceImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  detail: json['detail'] as String,
  ip: json['ip'] as String?,
  isCurrent: json['isCurrent'] as bool? ?? false,
  lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$DeviceImplToJson(_$DeviceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'detail': instance.detail,
      'ip': instance.ip,
      'isCurrent': instance.isCurrent,
      'lastActiveAt': instance.lastActiveAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

_$SecurityEventImpl _$$SecurityEventImplFromJson(Map<String, dynamic> json) =>
    _$SecurityEventImpl(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      detail: json['detail'] as String,
      time: DateTime.parse(json['time'] as String),
    );

Map<String, dynamic> _$$SecurityEventImplToJson(_$SecurityEventImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'detail': instance.detail,
      'time': instance.time.toIso8601String(),
    };

_$AppNotificationImpl _$$AppNotificationImplFromJson(
  Map<String, dynamic> json,
) => _$AppNotificationImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  body: json['body'] as String,
  date: DateTime.parse(json['date'] as String),
  isRead: json['isRead'] as bool? ?? false,
  category: json['category'] as String? ?? 'general',
);

Map<String, dynamic> _$$AppNotificationImplToJson(
  _$AppNotificationImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'body': instance.body,
  'date': instance.date.toIso8601String(),
  'isRead': instance.isRead,
  'category': instance.category,
};
