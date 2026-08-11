// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'credential.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Credential {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Credential&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'Credential(field0: $field0)';
}


}

/// @nodoc
class $CredentialCopyWith<$Res>  {
$CredentialCopyWith(Credential _, $Res Function(Credential) __);
}


/// Adds pattern-matching-related methods to [Credential].
extension CredentialPatterns on Credential {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Credential_VerifiableCredential value)?  verifiableCredential,TResult Function( Credential_MDoc value)?  mDoc,TResult Function( Credential_SdJwt value)?  sdJwt,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Credential_VerifiableCredential() when verifiableCredential != null:
return verifiableCredential(_that);case Credential_MDoc() when mDoc != null:
return mDoc(_that);case Credential_SdJwt() when sdJwt != null:
return sdJwt(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Credential_VerifiableCredential value)  verifiableCredential,required TResult Function( Credential_MDoc value)  mDoc,required TResult Function( Credential_SdJwt value)  sdJwt,}){
final _that = this;
switch (_that) {
case Credential_VerifiableCredential():
return verifiableCredential(_that);case Credential_MDoc():
return mDoc(_that);case Credential_SdJwt():
return sdJwt(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Credential_VerifiableCredential value)?  verifiableCredential,TResult? Function( Credential_MDoc value)?  mDoc,TResult? Function( Credential_SdJwt value)?  sdJwt,}){
final _that = this;
switch (_that) {
case Credential_VerifiableCredential() when verifiableCredential != null:
return verifiableCredential(_that);case Credential_MDoc() when mDoc != null:
return mDoc(_that);case Credential_SdJwt() when sdJwt != null:
return sdJwt(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( VerifiableCredential field0)?  verifiableCredential,TResult Function( MDocCredential field0)?  mDoc,TResult Function( SdJwtCredential field0)?  sdJwt,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Credential_VerifiableCredential() when verifiableCredential != null:
return verifiableCredential(_that.field0);case Credential_MDoc() when mDoc != null:
return mDoc(_that.field0);case Credential_SdJwt() when sdJwt != null:
return sdJwt(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( VerifiableCredential field0)  verifiableCredential,required TResult Function( MDocCredential field0)  mDoc,required TResult Function( SdJwtCredential field0)  sdJwt,}) {final _that = this;
switch (_that) {
case Credential_VerifiableCredential():
return verifiableCredential(_that.field0);case Credential_MDoc():
return mDoc(_that.field0);case Credential_SdJwt():
return sdJwt(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( VerifiableCredential field0)?  verifiableCredential,TResult? Function( MDocCredential field0)?  mDoc,TResult? Function( SdJwtCredential field0)?  sdJwt,}) {final _that = this;
switch (_that) {
case Credential_VerifiableCredential() when verifiableCredential != null:
return verifiableCredential(_that.field0);case Credential_MDoc() when mDoc != null:
return mDoc(_that.field0);case Credential_SdJwt() when sdJwt != null:
return sdJwt(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class Credential_VerifiableCredential extends Credential {
  const Credential_VerifiableCredential(this.field0): super._();
  

@override final  VerifiableCredential field0;

/// Create a copy of Credential
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Credential_VerifiableCredentialCopyWith<Credential_VerifiableCredential> get copyWith => _$Credential_VerifiableCredentialCopyWithImpl<Credential_VerifiableCredential>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Credential_VerifiableCredential&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Credential.verifiableCredential(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Credential_VerifiableCredentialCopyWith<$Res> implements $CredentialCopyWith<$Res> {
  factory $Credential_VerifiableCredentialCopyWith(Credential_VerifiableCredential value, $Res Function(Credential_VerifiableCredential) _then) = _$Credential_VerifiableCredentialCopyWithImpl;
@useResult
$Res call({
 VerifiableCredential field0
});




}
/// @nodoc
class _$Credential_VerifiableCredentialCopyWithImpl<$Res>
    implements $Credential_VerifiableCredentialCopyWith<$Res> {
  _$Credential_VerifiableCredentialCopyWithImpl(this._self, this._then);

  final Credential_VerifiableCredential _self;
  final $Res Function(Credential_VerifiableCredential) _then;

/// Create a copy of Credential
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Credential_VerifiableCredential(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as VerifiableCredential,
  ));
}


}

/// @nodoc


class Credential_MDoc extends Credential {
  const Credential_MDoc(this.field0): super._();
  

@override final  MDocCredential field0;

/// Create a copy of Credential
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Credential_MDocCopyWith<Credential_MDoc> get copyWith => _$Credential_MDocCopyWithImpl<Credential_MDoc>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Credential_MDoc&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Credential.mDoc(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Credential_MDocCopyWith<$Res> implements $CredentialCopyWith<$Res> {
  factory $Credential_MDocCopyWith(Credential_MDoc value, $Res Function(Credential_MDoc) _then) = _$Credential_MDocCopyWithImpl;
@useResult
$Res call({
 MDocCredential field0
});




}
/// @nodoc
class _$Credential_MDocCopyWithImpl<$Res>
    implements $Credential_MDocCopyWith<$Res> {
  _$Credential_MDocCopyWithImpl(this._self, this._then);

  final Credential_MDoc _self;
  final $Res Function(Credential_MDoc) _then;

/// Create a copy of Credential
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Credential_MDoc(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as MDocCredential,
  ));
}


}

/// @nodoc


class Credential_SdJwt extends Credential {
  const Credential_SdJwt(this.field0): super._();
  

@override final  SdJwtCredential field0;

/// Create a copy of Credential
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Credential_SdJwtCopyWith<Credential_SdJwt> get copyWith => _$Credential_SdJwtCopyWithImpl<Credential_SdJwt>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Credential_SdJwt&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Credential.sdJwt(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Credential_SdJwtCopyWith<$Res> implements $CredentialCopyWith<$Res> {
  factory $Credential_SdJwtCopyWith(Credential_SdJwt value, $Res Function(Credential_SdJwt) _then) = _$Credential_SdJwtCopyWithImpl;
@useResult
$Res call({
 SdJwtCredential field0
});




}
/// @nodoc
class _$Credential_SdJwtCopyWithImpl<$Res>
    implements $Credential_SdJwtCopyWith<$Res> {
  _$Credential_SdJwtCopyWithImpl(this._self, this._then);

  final Credential_SdJwt _self;
  final $Res Function(Credential_SdJwt) _then;

/// Create a copy of Credential
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Credential_SdJwt(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as SdJwtCredential,
  ));
}


}

// dart format on
