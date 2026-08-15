// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FrbStatusDecision {

 String get purpose; BigInt get index; bool get asserted; BigInt get listSize;
/// Create a copy of FrbStatusDecision
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrbStatusDecisionCopyWith<FrbStatusDecision> get copyWith => _$FrbStatusDecisionCopyWithImpl<FrbStatusDecision>(this as FrbStatusDecision, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrbStatusDecision&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.index, index) || other.index == index)&&(identical(other.asserted, asserted) || other.asserted == asserted)&&(identical(other.listSize, listSize) || other.listSize == listSize));
}


@override
int get hashCode => Object.hash(runtimeType,purpose,index,asserted,listSize);

@override
String toString() {
  return 'FrbStatusDecision(purpose: $purpose, index: $index, asserted: $asserted, listSize: $listSize)';
}


}

/// @nodoc
abstract mixin class $FrbStatusDecisionCopyWith<$Res>  {
  factory $FrbStatusDecisionCopyWith(FrbStatusDecision value, $Res Function(FrbStatusDecision) _then) = _$FrbStatusDecisionCopyWithImpl;
@useResult
$Res call({
 String purpose, BigInt index, bool asserted, BigInt listSize
});




}
/// @nodoc
class _$FrbStatusDecisionCopyWithImpl<$Res>
    implements $FrbStatusDecisionCopyWith<$Res> {
  _$FrbStatusDecisionCopyWithImpl(this._self, this._then);

  final FrbStatusDecision _self;
  final $Res Function(FrbStatusDecision) _then;

/// Create a copy of FrbStatusDecision
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? purpose = null,Object? index = null,Object? asserted = null,Object? listSize = null,}) {
  return _then(_self.copyWith(
purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as BigInt,asserted: null == asserted ? _self.asserted : asserted // ignore: cast_nullable_to_non_nullable
as bool,listSize: null == listSize ? _self.listSize : listSize // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}

}


/// Adds pattern-matching-related methods to [FrbStatusDecision].
extension FrbStatusDecisionPatterns on FrbStatusDecision {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrbStatusDecision value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrbStatusDecision() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrbStatusDecision value)  $default,){
final _that = this;
switch (_that) {
case _FrbStatusDecision():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrbStatusDecision value)?  $default,){
final _that = this;
switch (_that) {
case _FrbStatusDecision() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String purpose,  BigInt index,  bool asserted,  BigInt listSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrbStatusDecision() when $default != null:
return $default(_that.purpose,_that.index,_that.asserted,_that.listSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String purpose,  BigInt index,  bool asserted,  BigInt listSize)  $default,) {final _that = this;
switch (_that) {
case _FrbStatusDecision():
return $default(_that.purpose,_that.index,_that.asserted,_that.listSize);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String purpose,  BigInt index,  bool asserted,  BigInt listSize)?  $default,) {final _that = this;
switch (_that) {
case _FrbStatusDecision() when $default != null:
return $default(_that.purpose,_that.index,_that.asserted,_that.listSize);case _:
  return null;

}
}

}

/// @nodoc


class _FrbStatusDecision implements FrbStatusDecision {
  const _FrbStatusDecision({required this.purpose, required this.index, required this.asserted, required this.listSize});
  

@override final  String purpose;
@override final  BigInt index;
@override final  bool asserted;
@override final  BigInt listSize;

/// Create a copy of FrbStatusDecision
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrbStatusDecisionCopyWith<_FrbStatusDecision> get copyWith => __$FrbStatusDecisionCopyWithImpl<_FrbStatusDecision>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrbStatusDecision&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.index, index) || other.index == index)&&(identical(other.asserted, asserted) || other.asserted == asserted)&&(identical(other.listSize, listSize) || other.listSize == listSize));
}


@override
int get hashCode => Object.hash(runtimeType,purpose,index,asserted,listSize);

@override
String toString() {
  return 'FrbStatusDecision(purpose: $purpose, index: $index, asserted: $asserted, listSize: $listSize)';
}


}

/// @nodoc
abstract mixin class _$FrbStatusDecisionCopyWith<$Res> implements $FrbStatusDecisionCopyWith<$Res> {
  factory _$FrbStatusDecisionCopyWith(_FrbStatusDecision value, $Res Function(_FrbStatusDecision) _then) = __$FrbStatusDecisionCopyWithImpl;
@override @useResult
$Res call({
 String purpose, BigInt index, bool asserted, BigInt listSize
});




}
/// @nodoc
class __$FrbStatusDecisionCopyWithImpl<$Res>
    implements _$FrbStatusDecisionCopyWith<$Res> {
  __$FrbStatusDecisionCopyWithImpl(this._self, this._then);

  final _FrbStatusDecision _self;
  final $Res Function(_FrbStatusDecision) _then;

/// Create a copy of FrbStatusDecision
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? purpose = null,Object? index = null,Object? asserted = null,Object? listSize = null,}) {
  return _then(_FrbStatusDecision(
purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as BigInt,asserted: null == asserted ? _self.asserted : asserted // ignore: cast_nullable_to_non_nullable
as bool,listSize: null == listSize ? _self.listSize : listSize // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc
mixin _$FrbStatusEntry {

 String get id; String get purpose; BigInt get index; String get listUrl; String get entryJson;
/// Create a copy of FrbStatusEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrbStatusEntryCopyWith<FrbStatusEntry> get copyWith => _$FrbStatusEntryCopyWithImpl<FrbStatusEntry>(this as FrbStatusEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrbStatusEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.index, index) || other.index == index)&&(identical(other.listUrl, listUrl) || other.listUrl == listUrl)&&(identical(other.entryJson, entryJson) || other.entryJson == entryJson));
}


@override
int get hashCode => Object.hash(runtimeType,id,purpose,index,listUrl,entryJson);

@override
String toString() {
  return 'FrbStatusEntry(id: $id, purpose: $purpose, index: $index, listUrl: $listUrl, entryJson: $entryJson)';
}


}

/// @nodoc
abstract mixin class $FrbStatusEntryCopyWith<$Res>  {
  factory $FrbStatusEntryCopyWith(FrbStatusEntry value, $Res Function(FrbStatusEntry) _then) = _$FrbStatusEntryCopyWithImpl;
@useResult
$Res call({
 String id, String purpose, BigInt index, String listUrl, String entryJson
});




}
/// @nodoc
class _$FrbStatusEntryCopyWithImpl<$Res>
    implements $FrbStatusEntryCopyWith<$Res> {
  _$FrbStatusEntryCopyWithImpl(this._self, this._then);

  final FrbStatusEntry _self;
  final $Res Function(FrbStatusEntry) _then;

/// Create a copy of FrbStatusEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? purpose = null,Object? index = null,Object? listUrl = null,Object? entryJson = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as BigInt,listUrl: null == listUrl ? _self.listUrl : listUrl // ignore: cast_nullable_to_non_nullable
as String,entryJson: null == entryJson ? _self.entryJson : entryJson // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FrbStatusEntry].
extension FrbStatusEntryPatterns on FrbStatusEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrbStatusEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrbStatusEntry() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrbStatusEntry value)  $default,){
final _that = this;
switch (_that) {
case _FrbStatusEntry():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrbStatusEntry value)?  $default,){
final _that = this;
switch (_that) {
case _FrbStatusEntry() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String purpose,  BigInt index,  String listUrl,  String entryJson)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrbStatusEntry() when $default != null:
return $default(_that.id,_that.purpose,_that.index,_that.listUrl,_that.entryJson);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String purpose,  BigInt index,  String listUrl,  String entryJson)  $default,) {final _that = this;
switch (_that) {
case _FrbStatusEntry():
return $default(_that.id,_that.purpose,_that.index,_that.listUrl,_that.entryJson);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String purpose,  BigInt index,  String listUrl,  String entryJson)?  $default,) {final _that = this;
switch (_that) {
case _FrbStatusEntry() when $default != null:
return $default(_that.id,_that.purpose,_that.index,_that.listUrl,_that.entryJson);case _:
  return null;

}
}

}

/// @nodoc


class _FrbStatusEntry implements FrbStatusEntry {
  const _FrbStatusEntry({required this.id, required this.purpose, required this.index, required this.listUrl, required this.entryJson});
  

@override final  String id;
@override final  String purpose;
@override final  BigInt index;
@override final  String listUrl;
@override final  String entryJson;

/// Create a copy of FrbStatusEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrbStatusEntryCopyWith<_FrbStatusEntry> get copyWith => __$FrbStatusEntryCopyWithImpl<_FrbStatusEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrbStatusEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.index, index) || other.index == index)&&(identical(other.listUrl, listUrl) || other.listUrl == listUrl)&&(identical(other.entryJson, entryJson) || other.entryJson == entryJson));
}


@override
int get hashCode => Object.hash(runtimeType,id,purpose,index,listUrl,entryJson);

@override
String toString() {
  return 'FrbStatusEntry(id: $id, purpose: $purpose, index: $index, listUrl: $listUrl, entryJson: $entryJson)';
}


}

/// @nodoc
abstract mixin class _$FrbStatusEntryCopyWith<$Res> implements $FrbStatusEntryCopyWith<$Res> {
  factory _$FrbStatusEntryCopyWith(_FrbStatusEntry value, $Res Function(_FrbStatusEntry) _then) = __$FrbStatusEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String purpose, BigInt index, String listUrl, String entryJson
});




}
/// @nodoc
class __$FrbStatusEntryCopyWithImpl<$Res>
    implements _$FrbStatusEntryCopyWith<$Res> {
  __$FrbStatusEntryCopyWithImpl(this._self, this._then);

  final _FrbStatusEntry _self;
  final $Res Function(_FrbStatusEntry) _then;

/// Create a copy of FrbStatusEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? purpose = null,Object? index = null,Object? listUrl = null,Object? entryJson = null,}) {
  return _then(_FrbStatusEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as BigInt,listUrl: null == listUrl ? _self.listUrl : listUrl // ignore: cast_nullable_to_non_nullable
as String,entryJson: null == entryJson ? _self.entryJson : entryJson // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
