// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'security.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Device _$DeviceFromJson(Map<String, dynamic> json) {
  return _Device.fromJson(json);
}

/// @nodoc
mixin _$Device {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get detail => throw _privateConstructorUsedError;
  String? get ip => throw _privateConstructorUsedError;
  bool get isCurrent => throw _privateConstructorUsedError;
  DateTime get lastActiveAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Device to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceCopyWith<Device> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceCopyWith<$Res> {
  factory $DeviceCopyWith(Device value, $Res Function(Device) then) =
      _$DeviceCopyWithImpl<$Res, Device>;
  @useResult
  $Res call({
    String id,
    String name,
    String detail,
    String? ip,
    bool isCurrent,
    DateTime lastActiveAt,
    DateTime createdAt,
  });
}

/// @nodoc
class _$DeviceCopyWithImpl<$Res, $Val extends Device>
    implements $DeviceCopyWith<$Res> {
  _$DeviceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? detail = null,
    Object? ip = freezed,
    Object? isCurrent = null,
    Object? lastActiveAt = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            detail: null == detail
                ? _value.detail
                : detail // ignore: cast_nullable_to_non_nullable
                      as String,
            ip: freezed == ip
                ? _value.ip
                : ip // ignore: cast_nullable_to_non_nullable
                      as String?,
            isCurrent: null == isCurrent
                ? _value.isCurrent
                : isCurrent // ignore: cast_nullable_to_non_nullable
                      as bool,
            lastActiveAt: null == lastActiveAt
                ? _value.lastActiveAt
                : lastActiveAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeviceImplCopyWith<$Res> implements $DeviceCopyWith<$Res> {
  factory _$$DeviceImplCopyWith(
    _$DeviceImpl value,
    $Res Function(_$DeviceImpl) then,
  ) = __$$DeviceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String detail,
    String? ip,
    bool isCurrent,
    DateTime lastActiveAt,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$DeviceImplCopyWithImpl<$Res>
    extends _$DeviceCopyWithImpl<$Res, _$DeviceImpl>
    implements _$$DeviceImplCopyWith<$Res> {
  __$$DeviceImplCopyWithImpl(
    _$DeviceImpl _value,
    $Res Function(_$DeviceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? detail = null,
    Object? ip = freezed,
    Object? isCurrent = null,
    Object? lastActiveAt = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$DeviceImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        detail: null == detail
            ? _value.detail
            : detail // ignore: cast_nullable_to_non_nullable
                  as String,
        ip: freezed == ip
            ? _value.ip
            : ip // ignore: cast_nullable_to_non_nullable
                  as String?,
        isCurrent: null == isCurrent
            ? _value.isCurrent
            : isCurrent // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastActiveAt: null == lastActiveAt
            ? _value.lastActiveAt
            : lastActiveAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DeviceImpl implements _Device {
  const _$DeviceImpl({
    required this.id,
    required this.name,
    required this.detail,
    this.ip,
    this.isCurrent = false,
    required this.lastActiveAt,
    required this.createdAt,
  });

  factory _$DeviceImpl.fromJson(Map<String, dynamic> json) =>
      _$$DeviceImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String detail;
  @override
  final String? ip;
  @override
  @JsonKey()
  final bool isCurrent;
  @override
  final DateTime lastActiveAt;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Device(id: $id, name: $name, detail: $detail, ip: $ip, isCurrent: $isCurrent, lastActiveAt: $lastActiveAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.detail, detail) || other.detail == detail) &&
            (identical(other.ip, ip) || other.ip == ip) &&
            (identical(other.isCurrent, isCurrent) ||
                other.isCurrent == isCurrent) &&
            (identical(other.lastActiveAt, lastActiveAt) ||
                other.lastActiveAt == lastActiveAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    detail,
    ip,
    isCurrent,
    lastActiveAt,
    createdAt,
  );

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceImplCopyWith<_$DeviceImpl> get copyWith =>
      __$$DeviceImplCopyWithImpl<_$DeviceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DeviceImplToJson(this);
  }
}

abstract class _Device implements Device {
  const factory _Device({
    required final String id,
    required final String name,
    required final String detail,
    final String? ip,
    final bool isCurrent,
    required final DateTime lastActiveAt,
    required final DateTime createdAt,
  }) = _$DeviceImpl;

  factory _Device.fromJson(Map<String, dynamic> json) = _$DeviceImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get detail;
  @override
  String? get ip;
  @override
  bool get isCurrent;
  @override
  DateTime get lastActiveAt;
  @override
  DateTime get createdAt;

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceImplCopyWith<_$DeviceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SecurityEvent _$SecurityEventFromJson(Map<String, dynamic> json) {
  return _SecurityEvent.fromJson(json);
}

/// @nodoc
mixin _$SecurityEvent {
  String get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get detail => throw _privateConstructorUsedError;
  String get severity => throw _privateConstructorUsedError;
  String? get ip => throw _privateConstructorUsedError;
  String? get userAgent => throw _privateConstructorUsedError;
  String? get device => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;
  DateTime get time => throw _privateConstructorUsedError;

  /// Serializes this SecurityEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SecurityEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SecurityEventCopyWith<SecurityEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SecurityEventCopyWith<$Res> {
  factory $SecurityEventCopyWith(
    SecurityEvent value,
    $Res Function(SecurityEvent) then,
  ) = _$SecurityEventCopyWithImpl<$Res, SecurityEvent>;
  @useResult
  $Res call({
    String id,
    String type,
    String title,
    String detail,
    String severity,
    String? ip,
    String? userAgent,
    String? device,
    Map<String, dynamic>? metadata,
    DateTime time,
  });
}

/// @nodoc
class _$SecurityEventCopyWithImpl<$Res, $Val extends SecurityEvent>
    implements $SecurityEventCopyWith<$Res> {
  _$SecurityEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SecurityEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? detail = null,
    Object? severity = null,
    Object? ip = freezed,
    Object? userAgent = freezed,
    Object? device = freezed,
    Object? metadata = freezed,
    Object? time = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            detail: null == detail
                ? _value.detail
                : detail // ignore: cast_nullable_to_non_nullable
                      as String,
            severity: null == severity
                ? _value.severity
                : severity // ignore: cast_nullable_to_non_nullable
                      as String,
            ip: freezed == ip
                ? _value.ip
                : ip // ignore: cast_nullable_to_non_nullable
                      as String?,
            userAgent: freezed == userAgent
                ? _value.userAgent
                : userAgent // ignore: cast_nullable_to_non_nullable
                      as String?,
            device: freezed == device
                ? _value.device
                : device // ignore: cast_nullable_to_non_nullable
                      as String?,
            metadata: freezed == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            time: null == time
                ? _value.time
                : time // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SecurityEventImplCopyWith<$Res>
    implements $SecurityEventCopyWith<$Res> {
  factory _$$SecurityEventImplCopyWith(
    _$SecurityEventImpl value,
    $Res Function(_$SecurityEventImpl) then,
  ) = __$$SecurityEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String type,
    String title,
    String detail,
    String severity,
    String? ip,
    String? userAgent,
    String? device,
    Map<String, dynamic>? metadata,
    DateTime time,
  });
}

/// @nodoc
class __$$SecurityEventImplCopyWithImpl<$Res>
    extends _$SecurityEventCopyWithImpl<$Res, _$SecurityEventImpl>
    implements _$$SecurityEventImplCopyWith<$Res> {
  __$$SecurityEventImplCopyWithImpl(
    _$SecurityEventImpl _value,
    $Res Function(_$SecurityEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SecurityEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? detail = null,
    Object? severity = null,
    Object? ip = freezed,
    Object? userAgent = freezed,
    Object? device = freezed,
    Object? metadata = freezed,
    Object? time = null,
  }) {
    return _then(
      _$SecurityEventImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        detail: null == detail
            ? _value.detail
            : detail // ignore: cast_nullable_to_non_nullable
                  as String,
        severity: null == severity
            ? _value.severity
            : severity // ignore: cast_nullable_to_non_nullable
                  as String,
        ip: freezed == ip
            ? _value.ip
            : ip // ignore: cast_nullable_to_non_nullable
                  as String?,
        userAgent: freezed == userAgent
            ? _value.userAgent
            : userAgent // ignore: cast_nullable_to_non_nullable
                  as String?,
        device: freezed == device
            ? _value.device
            : device // ignore: cast_nullable_to_non_nullable
                  as String?,
        metadata: freezed == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        time: null == time
            ? _value.time
            : time // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SecurityEventImpl implements _SecurityEvent {
  const _$SecurityEventImpl({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    this.severity = 'info',
    this.ip,
    this.userAgent,
    this.device,
    final Map<String, dynamic>? metadata,
    required this.time,
  }) : _metadata = metadata;

  factory _$SecurityEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$SecurityEventImplFromJson(json);

  @override
  final String id;
  @override
  final String type;
  @override
  final String title;
  @override
  final String detail;
  @override
  @JsonKey()
  final String severity;
  @override
  final String? ip;
  @override
  final String? userAgent;
  @override
  final String? device;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime time;

  @override
  String toString() {
    return 'SecurityEvent(id: $id, type: $type, title: $title, detail: $detail, severity: $severity, ip: $ip, userAgent: $userAgent, device: $device, metadata: $metadata, time: $time)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SecurityEventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.detail, detail) || other.detail == detail) &&
            (identical(other.severity, severity) ||
                other.severity == severity) &&
            (identical(other.ip, ip) || other.ip == ip) &&
            (identical(other.userAgent, userAgent) ||
                other.userAgent == userAgent) &&
            (identical(other.device, device) || other.device == device) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.time, time) || other.time == time));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    title,
    detail,
    severity,
    ip,
    userAgent,
    device,
    const DeepCollectionEquality().hash(_metadata),
    time,
  );

  /// Create a copy of SecurityEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SecurityEventImplCopyWith<_$SecurityEventImpl> get copyWith =>
      __$$SecurityEventImplCopyWithImpl<_$SecurityEventImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SecurityEventImplToJson(this);
  }
}

abstract class _SecurityEvent implements SecurityEvent {
  const factory _SecurityEvent({
    required final String id,
    required final String type,
    required final String title,
    required final String detail,
    final String severity,
    final String? ip,
    final String? userAgent,
    final String? device,
    final Map<String, dynamic>? metadata,
    required final DateTime time,
  }) = _$SecurityEventImpl;

  factory _SecurityEvent.fromJson(Map<String, dynamic> json) =
      _$SecurityEventImpl.fromJson;

  @override
  String get id;
  @override
  String get type;
  @override
  String get title;
  @override
  String get detail;
  @override
  String get severity;
  @override
  String? get ip;
  @override
  String? get userAgent;
  @override
  String? get device;
  @override
  Map<String, dynamic>? get metadata;
  @override
  DateTime get time;

  /// Create a copy of SecurityEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SecurityEventImplCopyWith<_$SecurityEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SecurityPrefs _$SecurityPrefsFromJson(Map<String, dynamic> json) {
  return _SecurityPrefs.fromJson(json);
}

/// @nodoc
mixin _$SecurityPrefs {
  bool get notifyNewSignin => throw _privateConstructorUsedError;
  bool get notifyFailedLogin => throw _privateConstructorUsedError;

  /// Serializes this SecurityPrefs to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SecurityPrefs
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SecurityPrefsCopyWith<SecurityPrefs> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SecurityPrefsCopyWith<$Res> {
  factory $SecurityPrefsCopyWith(
    SecurityPrefs value,
    $Res Function(SecurityPrefs) then,
  ) = _$SecurityPrefsCopyWithImpl<$Res, SecurityPrefs>;
  @useResult
  $Res call({bool notifyNewSignin, bool notifyFailedLogin});
}

/// @nodoc
class _$SecurityPrefsCopyWithImpl<$Res, $Val extends SecurityPrefs>
    implements $SecurityPrefsCopyWith<$Res> {
  _$SecurityPrefsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SecurityPrefs
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? notifyNewSignin = null,
    Object? notifyFailedLogin = null,
  }) {
    return _then(
      _value.copyWith(
            notifyNewSignin: null == notifyNewSignin
                ? _value.notifyNewSignin
                : notifyNewSignin // ignore: cast_nullable_to_non_nullable
                      as bool,
            notifyFailedLogin: null == notifyFailedLogin
                ? _value.notifyFailedLogin
                : notifyFailedLogin // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SecurityPrefsImplCopyWith<$Res>
    implements $SecurityPrefsCopyWith<$Res> {
  factory _$$SecurityPrefsImplCopyWith(
    _$SecurityPrefsImpl value,
    $Res Function(_$SecurityPrefsImpl) then,
  ) = __$$SecurityPrefsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool notifyNewSignin, bool notifyFailedLogin});
}

/// @nodoc
class __$$SecurityPrefsImplCopyWithImpl<$Res>
    extends _$SecurityPrefsCopyWithImpl<$Res, _$SecurityPrefsImpl>
    implements _$$SecurityPrefsImplCopyWith<$Res> {
  __$$SecurityPrefsImplCopyWithImpl(
    _$SecurityPrefsImpl _value,
    $Res Function(_$SecurityPrefsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SecurityPrefs
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? notifyNewSignin = null,
    Object? notifyFailedLogin = null,
  }) {
    return _then(
      _$SecurityPrefsImpl(
        notifyNewSignin: null == notifyNewSignin
            ? _value.notifyNewSignin
            : notifyNewSignin // ignore: cast_nullable_to_non_nullable
                  as bool,
        notifyFailedLogin: null == notifyFailedLogin
            ? _value.notifyFailedLogin
            : notifyFailedLogin // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SecurityPrefsImpl implements _SecurityPrefs {
  const _$SecurityPrefsImpl({
    this.notifyNewSignin = true,
    this.notifyFailedLogin = true,
  });

  factory _$SecurityPrefsImpl.fromJson(Map<String, dynamic> json) =>
      _$$SecurityPrefsImplFromJson(json);

  @override
  @JsonKey()
  final bool notifyNewSignin;
  @override
  @JsonKey()
  final bool notifyFailedLogin;

  @override
  String toString() {
    return 'SecurityPrefs(notifyNewSignin: $notifyNewSignin, notifyFailedLogin: $notifyFailedLogin)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SecurityPrefsImpl &&
            (identical(other.notifyNewSignin, notifyNewSignin) ||
                other.notifyNewSignin == notifyNewSignin) &&
            (identical(other.notifyFailedLogin, notifyFailedLogin) ||
                other.notifyFailedLogin == notifyFailedLogin));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, notifyNewSignin, notifyFailedLogin);

  /// Create a copy of SecurityPrefs
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SecurityPrefsImplCopyWith<_$SecurityPrefsImpl> get copyWith =>
      __$$SecurityPrefsImplCopyWithImpl<_$SecurityPrefsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SecurityPrefsImplToJson(this);
  }
}

abstract class _SecurityPrefs implements SecurityPrefs {
  const factory _SecurityPrefs({
    final bool notifyNewSignin,
    final bool notifyFailedLogin,
  }) = _$SecurityPrefsImpl;

  factory _SecurityPrefs.fromJson(Map<String, dynamic> json) =
      _$SecurityPrefsImpl.fromJson;

  @override
  bool get notifyNewSignin;
  @override
  bool get notifyFailedLogin;

  /// Create a copy of SecurityPrefs
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SecurityPrefsImplCopyWith<_$SecurityPrefsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) {
  return _AppNotification.fromJson(json);
}

/// @nodoc
mixin _$AppNotification {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get body => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  bool get isRead => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;

  /// Serializes this AppNotification to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppNotificationCopyWith<AppNotification> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppNotificationCopyWith<$Res> {
  factory $AppNotificationCopyWith(
    AppNotification value,
    $Res Function(AppNotification) then,
  ) = _$AppNotificationCopyWithImpl<$Res, AppNotification>;
  @useResult
  $Res call({
    String id,
    String title,
    String body,
    DateTime date,
    bool isRead,
    String category,
  });
}

/// @nodoc
class _$AppNotificationCopyWithImpl<$Res, $Val extends AppNotification>
    implements $AppNotificationCopyWith<$Res> {
  _$AppNotificationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? body = null,
    Object? date = null,
    Object? isRead = null,
    Object? category = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            body: null == body
                ? _value.body
                : body // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            isRead: null == isRead
                ? _value.isRead
                : isRead // ignore: cast_nullable_to_non_nullable
                      as bool,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppNotificationImplCopyWith<$Res>
    implements $AppNotificationCopyWith<$Res> {
  factory _$$AppNotificationImplCopyWith(
    _$AppNotificationImpl value,
    $Res Function(_$AppNotificationImpl) then,
  ) = __$$AppNotificationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String body,
    DateTime date,
    bool isRead,
    String category,
  });
}

/// @nodoc
class __$$AppNotificationImplCopyWithImpl<$Res>
    extends _$AppNotificationCopyWithImpl<$Res, _$AppNotificationImpl>
    implements _$$AppNotificationImplCopyWith<$Res> {
  __$$AppNotificationImplCopyWithImpl(
    _$AppNotificationImpl _value,
    $Res Function(_$AppNotificationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? body = null,
    Object? date = null,
    Object? isRead = null,
    Object? category = null,
  }) {
    return _then(
      _$AppNotificationImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        body: null == body
            ? _value.body
            : body // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        isRead: null == isRead
            ? _value.isRead
            : isRead // ignore: cast_nullable_to_non_nullable
                  as bool,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AppNotificationImpl implements _AppNotification {
  const _$AppNotificationImpl({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.isRead = false,
    this.category = 'general',
  });

  factory _$AppNotificationImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppNotificationImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String body;
  @override
  final DateTime date;
  @override
  @JsonKey()
  final bool isRead;
  @override
  @JsonKey()
  final String category;

  @override
  String toString() {
    return 'AppNotification(id: $id, title: $title, body: $body, date: $date, isRead: $isRead, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppNotificationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.category, category) ||
                other.category == category));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, body, date, isRead, category);

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppNotificationImplCopyWith<_$AppNotificationImpl> get copyWith =>
      __$$AppNotificationImplCopyWithImpl<_$AppNotificationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AppNotificationImplToJson(this);
  }
}

abstract class _AppNotification implements AppNotification {
  const factory _AppNotification({
    required final String id,
    required final String title,
    required final String body,
    required final DateTime date,
    final bool isRead,
    final String category,
  }) = _$AppNotificationImpl;

  factory _AppNotification.fromJson(Map<String, dynamic> json) =
      _$AppNotificationImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get body;
  @override
  DateTime get date;
  @override
  bool get isRead;
  @override
  String get category;

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppNotificationImplCopyWith<_$AppNotificationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
