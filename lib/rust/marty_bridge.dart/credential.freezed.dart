// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'credential.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Credential {
  Object get field0 => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(VerifiableCredential field0) verifiableCredential,
    required TResult Function(MDocCredential field0) mDoc,
    required TResult Function(SdJwtCredential field0) sdJwt,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(VerifiableCredential field0)? verifiableCredential,
    TResult? Function(MDocCredential field0)? mDoc,
    TResult? Function(SdJwtCredential field0)? sdJwt,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(VerifiableCredential field0)? verifiableCredential,
    TResult Function(MDocCredential field0)? mDoc,
    TResult Function(SdJwtCredential field0)? sdJwt,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Credential_VerifiableCredential value)
    verifiableCredential,
    required TResult Function(Credential_MDoc value) mDoc,
    required TResult Function(Credential_SdJwt value) sdJwt,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Credential_VerifiableCredential value)?
    verifiableCredential,
    TResult? Function(Credential_MDoc value)? mDoc,
    TResult? Function(Credential_SdJwt value)? sdJwt,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Credential_VerifiableCredential value)?
    verifiableCredential,
    TResult Function(Credential_MDoc value)? mDoc,
    TResult Function(Credential_SdJwt value)? sdJwt,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CredentialCopyWith<$Res> {
  factory $CredentialCopyWith(
    Credential value,
    $Res Function(Credential) then,
  ) = _$CredentialCopyWithImpl<$Res, Credential>;
}

/// @nodoc
class _$CredentialCopyWithImpl<$Res, $Val extends Credential>
    implements $CredentialCopyWith<$Res> {
  _$CredentialCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$Credential_VerifiableCredentialImplCopyWith<$Res> {
  factory _$$Credential_VerifiableCredentialImplCopyWith(
    _$Credential_VerifiableCredentialImpl value,
    $Res Function(_$Credential_VerifiableCredentialImpl) then,
  ) = __$$Credential_VerifiableCredentialImplCopyWithImpl<$Res>;
  @useResult
  $Res call({VerifiableCredential field0});
}

/// @nodoc
class __$$Credential_VerifiableCredentialImplCopyWithImpl<$Res>
    extends
        _$CredentialCopyWithImpl<$Res, _$Credential_VerifiableCredentialImpl>
    implements _$$Credential_VerifiableCredentialImplCopyWith<$Res> {
  __$$Credential_VerifiableCredentialImplCopyWithImpl(
    _$Credential_VerifiableCredentialImpl _value,
    $Res Function(_$Credential_VerifiableCredentialImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$Credential_VerifiableCredentialImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as VerifiableCredential,
      ),
    );
  }
}

/// @nodoc

class _$Credential_VerifiableCredentialImpl
    extends Credential_VerifiableCredential {
  const _$Credential_VerifiableCredentialImpl(this.field0) : super._();

  @override
  final VerifiableCredential field0;

  @override
  String toString() {
    return 'Credential.verifiableCredential(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Credential_VerifiableCredentialImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$Credential_VerifiableCredentialImplCopyWith<
    _$Credential_VerifiableCredentialImpl
  >
  get copyWith =>
      __$$Credential_VerifiableCredentialImplCopyWithImpl<
        _$Credential_VerifiableCredentialImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(VerifiableCredential field0) verifiableCredential,
    required TResult Function(MDocCredential field0) mDoc,
    required TResult Function(SdJwtCredential field0) sdJwt,
  }) {
    return verifiableCredential(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(VerifiableCredential field0)? verifiableCredential,
    TResult? Function(MDocCredential field0)? mDoc,
    TResult? Function(SdJwtCredential field0)? sdJwt,
  }) {
    return verifiableCredential?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(VerifiableCredential field0)? verifiableCredential,
    TResult Function(MDocCredential field0)? mDoc,
    TResult Function(SdJwtCredential field0)? sdJwt,
    required TResult orElse(),
  }) {
    if (verifiableCredential != null) {
      return verifiableCredential(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Credential_VerifiableCredential value)
    verifiableCredential,
    required TResult Function(Credential_MDoc value) mDoc,
    required TResult Function(Credential_SdJwt value) sdJwt,
  }) {
    return verifiableCredential(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Credential_VerifiableCredential value)?
    verifiableCredential,
    TResult? Function(Credential_MDoc value)? mDoc,
    TResult? Function(Credential_SdJwt value)? sdJwt,
  }) {
    return verifiableCredential?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Credential_VerifiableCredential value)?
    verifiableCredential,
    TResult Function(Credential_MDoc value)? mDoc,
    TResult Function(Credential_SdJwt value)? sdJwt,
    required TResult orElse(),
  }) {
    if (verifiableCredential != null) {
      return verifiableCredential(this);
    }
    return orElse();
  }
}

abstract class Credential_VerifiableCredential extends Credential {
  const factory Credential_VerifiableCredential(
    final VerifiableCredential field0,
  ) = _$Credential_VerifiableCredentialImpl;
  const Credential_VerifiableCredential._() : super._();

  @override
  VerifiableCredential get field0;
  @JsonKey(ignore: true)
  _$$Credential_VerifiableCredentialImplCopyWith<
    _$Credential_VerifiableCredentialImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$Credential_MDocImplCopyWith<$Res> {
  factory _$$Credential_MDocImplCopyWith(
    _$Credential_MDocImpl value,
    $Res Function(_$Credential_MDocImpl) then,
  ) = __$$Credential_MDocImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MDocCredential field0});
}

/// @nodoc
class __$$Credential_MDocImplCopyWithImpl<$Res>
    extends _$CredentialCopyWithImpl<$Res, _$Credential_MDocImpl>
    implements _$$Credential_MDocImplCopyWith<$Res> {
  __$$Credential_MDocImplCopyWithImpl(
    _$Credential_MDocImpl _value,
    $Res Function(_$Credential_MDocImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$Credential_MDocImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as MDocCredential,
      ),
    );
  }
}

/// @nodoc

class _$Credential_MDocImpl extends Credential_MDoc {
  const _$Credential_MDocImpl(this.field0) : super._();

  @override
  final MDocCredential field0;

  @override
  String toString() {
    return 'Credential.mDoc(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Credential_MDocImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$Credential_MDocImplCopyWith<_$Credential_MDocImpl> get copyWith =>
      __$$Credential_MDocImplCopyWithImpl<_$Credential_MDocImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(VerifiableCredential field0) verifiableCredential,
    required TResult Function(MDocCredential field0) mDoc,
    required TResult Function(SdJwtCredential field0) sdJwt,
  }) {
    return mDoc(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(VerifiableCredential field0)? verifiableCredential,
    TResult? Function(MDocCredential field0)? mDoc,
    TResult? Function(SdJwtCredential field0)? sdJwt,
  }) {
    return mDoc?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(VerifiableCredential field0)? verifiableCredential,
    TResult Function(MDocCredential field0)? mDoc,
    TResult Function(SdJwtCredential field0)? sdJwt,
    required TResult orElse(),
  }) {
    if (mDoc != null) {
      return mDoc(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Credential_VerifiableCredential value)
    verifiableCredential,
    required TResult Function(Credential_MDoc value) mDoc,
    required TResult Function(Credential_SdJwt value) sdJwt,
  }) {
    return mDoc(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Credential_VerifiableCredential value)?
    verifiableCredential,
    TResult? Function(Credential_MDoc value)? mDoc,
    TResult? Function(Credential_SdJwt value)? sdJwt,
  }) {
    return mDoc?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Credential_VerifiableCredential value)?
    verifiableCredential,
    TResult Function(Credential_MDoc value)? mDoc,
    TResult Function(Credential_SdJwt value)? sdJwt,
    required TResult orElse(),
  }) {
    if (mDoc != null) {
      return mDoc(this);
    }
    return orElse();
  }
}

abstract class Credential_MDoc extends Credential {
  const factory Credential_MDoc(final MDocCredential field0) =
      _$Credential_MDocImpl;
  const Credential_MDoc._() : super._();

  @override
  MDocCredential get field0;
  @JsonKey(ignore: true)
  _$$Credential_MDocImplCopyWith<_$Credential_MDocImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$Credential_SdJwtImplCopyWith<$Res> {
  factory _$$Credential_SdJwtImplCopyWith(
    _$Credential_SdJwtImpl value,
    $Res Function(_$Credential_SdJwtImpl) then,
  ) = __$$Credential_SdJwtImplCopyWithImpl<$Res>;
  @useResult
  $Res call({SdJwtCredential field0});
}

/// @nodoc
class __$$Credential_SdJwtImplCopyWithImpl<$Res>
    extends _$CredentialCopyWithImpl<$Res, _$Credential_SdJwtImpl>
    implements _$$Credential_SdJwtImplCopyWith<$Res> {
  __$$Credential_SdJwtImplCopyWithImpl(
    _$Credential_SdJwtImpl _value,
    $Res Function(_$Credential_SdJwtImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$Credential_SdJwtImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as SdJwtCredential,
      ),
    );
  }
}

/// @nodoc

class _$Credential_SdJwtImpl extends Credential_SdJwt {
  const _$Credential_SdJwtImpl(this.field0) : super._();

  @override
  final SdJwtCredential field0;

  @override
  String toString() {
    return 'Credential.sdJwt(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Credential_SdJwtImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$Credential_SdJwtImplCopyWith<_$Credential_SdJwtImpl> get copyWith =>
      __$$Credential_SdJwtImplCopyWithImpl<_$Credential_SdJwtImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(VerifiableCredential field0) verifiableCredential,
    required TResult Function(MDocCredential field0) mDoc,
    required TResult Function(SdJwtCredential field0) sdJwt,
  }) {
    return sdJwt(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(VerifiableCredential field0)? verifiableCredential,
    TResult? Function(MDocCredential field0)? mDoc,
    TResult? Function(SdJwtCredential field0)? sdJwt,
  }) {
    return sdJwt?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(VerifiableCredential field0)? verifiableCredential,
    TResult Function(MDocCredential field0)? mDoc,
    TResult Function(SdJwtCredential field0)? sdJwt,
    required TResult orElse(),
  }) {
    if (sdJwt != null) {
      return sdJwt(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Credential_VerifiableCredential value)
    verifiableCredential,
    required TResult Function(Credential_MDoc value) mDoc,
    required TResult Function(Credential_SdJwt value) sdJwt,
  }) {
    return sdJwt(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Credential_VerifiableCredential value)?
    verifiableCredential,
    TResult? Function(Credential_MDoc value)? mDoc,
    TResult? Function(Credential_SdJwt value)? sdJwt,
  }) {
    return sdJwt?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Credential_VerifiableCredential value)?
    verifiableCredential,
    TResult Function(Credential_MDoc value)? mDoc,
    TResult Function(Credential_SdJwt value)? sdJwt,
    required TResult orElse(),
  }) {
    if (sdJwt != null) {
      return sdJwt(this);
    }
    return orElse();
  }
}

abstract class Credential_SdJwt extends Credential {
  const factory Credential_SdJwt(final SdJwtCredential field0) =
      _$Credential_SdJwtImpl;
  const Credential_SdJwt._() : super._();

  @override
  SdJwtCredential get field0;
  @JsonKey(ignore: true)
  _$$Credential_SdJwtImplCopyWith<_$Credential_SdJwtImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
