// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'biometrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FrbAgeEstimate {

 int get estimatedAge; double get confidence; int get ageRangeLow; int get ageRangeHigh;
/// Create a copy of FrbAgeEstimate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrbAgeEstimateCopyWith<FrbAgeEstimate> get copyWith => _$FrbAgeEstimateCopyWithImpl<FrbAgeEstimate>(this as FrbAgeEstimate, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrbAgeEstimate&&(identical(other.estimatedAge, estimatedAge) || other.estimatedAge == estimatedAge)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.ageRangeLow, ageRangeLow) || other.ageRangeLow == ageRangeLow)&&(identical(other.ageRangeHigh, ageRangeHigh) || other.ageRangeHigh == ageRangeHigh));
}


@override
int get hashCode => Object.hash(runtimeType,estimatedAge,confidence,ageRangeLow,ageRangeHigh);

@override
String toString() {
  return 'FrbAgeEstimate(estimatedAge: $estimatedAge, confidence: $confidence, ageRangeLow: $ageRangeLow, ageRangeHigh: $ageRangeHigh)';
}


}

/// @nodoc
abstract mixin class $FrbAgeEstimateCopyWith<$Res>  {
  factory $FrbAgeEstimateCopyWith(FrbAgeEstimate value, $Res Function(FrbAgeEstimate) _then) = _$FrbAgeEstimateCopyWithImpl;
@useResult
$Res call({
 int estimatedAge, double confidence, int ageRangeLow, int ageRangeHigh
});




}
/// @nodoc
class _$FrbAgeEstimateCopyWithImpl<$Res>
    implements $FrbAgeEstimateCopyWith<$Res> {
  _$FrbAgeEstimateCopyWithImpl(this._self, this._then);

  final FrbAgeEstimate _self;
  final $Res Function(FrbAgeEstimate) _then;

/// Create a copy of FrbAgeEstimate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? estimatedAge = null,Object? confidence = null,Object? ageRangeLow = null,Object? ageRangeHigh = null,}) {
  return _then(_self.copyWith(
estimatedAge: null == estimatedAge ? _self.estimatedAge : estimatedAge // ignore: cast_nullable_to_non_nullable
as int,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,ageRangeLow: null == ageRangeLow ? _self.ageRangeLow : ageRangeLow // ignore: cast_nullable_to_non_nullable
as int,ageRangeHigh: null == ageRangeHigh ? _self.ageRangeHigh : ageRangeHigh // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FrbAgeEstimate].
extension FrbAgeEstimatePatterns on FrbAgeEstimate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrbAgeEstimate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrbAgeEstimate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrbAgeEstimate value)  $default,){
final _that = this;
switch (_that) {
case _FrbAgeEstimate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrbAgeEstimate value)?  $default,){
final _that = this;
switch (_that) {
case _FrbAgeEstimate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int estimatedAge,  double confidence,  int ageRangeLow,  int ageRangeHigh)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrbAgeEstimate() when $default != null:
return $default(_that.estimatedAge,_that.confidence,_that.ageRangeLow,_that.ageRangeHigh);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int estimatedAge,  double confidence,  int ageRangeLow,  int ageRangeHigh)  $default,) {final _that = this;
switch (_that) {
case _FrbAgeEstimate():
return $default(_that.estimatedAge,_that.confidence,_that.ageRangeLow,_that.ageRangeHigh);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int estimatedAge,  double confidence,  int ageRangeLow,  int ageRangeHigh)?  $default,) {final _that = this;
switch (_that) {
case _FrbAgeEstimate() when $default != null:
return $default(_that.estimatedAge,_that.confidence,_that.ageRangeLow,_that.ageRangeHigh);case _:
  return null;

}
}

}

/// @nodoc


class _FrbAgeEstimate implements FrbAgeEstimate {
  const _FrbAgeEstimate({required this.estimatedAge, required this.confidence, required this.ageRangeLow, required this.ageRangeHigh});
  

@override final  int estimatedAge;
@override final  double confidence;
@override final  int ageRangeLow;
@override final  int ageRangeHigh;

/// Create a copy of FrbAgeEstimate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrbAgeEstimateCopyWith<_FrbAgeEstimate> get copyWith => __$FrbAgeEstimateCopyWithImpl<_FrbAgeEstimate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrbAgeEstimate&&(identical(other.estimatedAge, estimatedAge) || other.estimatedAge == estimatedAge)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.ageRangeLow, ageRangeLow) || other.ageRangeLow == ageRangeLow)&&(identical(other.ageRangeHigh, ageRangeHigh) || other.ageRangeHigh == ageRangeHigh));
}


@override
int get hashCode => Object.hash(runtimeType,estimatedAge,confidence,ageRangeLow,ageRangeHigh);

@override
String toString() {
  return 'FrbAgeEstimate(estimatedAge: $estimatedAge, confidence: $confidence, ageRangeLow: $ageRangeLow, ageRangeHigh: $ageRangeHigh)';
}


}

/// @nodoc
abstract mixin class _$FrbAgeEstimateCopyWith<$Res> implements $FrbAgeEstimateCopyWith<$Res> {
  factory _$FrbAgeEstimateCopyWith(_FrbAgeEstimate value, $Res Function(_FrbAgeEstimate) _then) = __$FrbAgeEstimateCopyWithImpl;
@override @useResult
$Res call({
 int estimatedAge, double confidence, int ageRangeLow, int ageRangeHigh
});




}
/// @nodoc
class __$FrbAgeEstimateCopyWithImpl<$Res>
    implements _$FrbAgeEstimateCopyWith<$Res> {
  __$FrbAgeEstimateCopyWithImpl(this._self, this._then);

  final _FrbAgeEstimate _self;
  final $Res Function(_FrbAgeEstimate) _then;

/// Create a copy of FrbAgeEstimate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? estimatedAge = null,Object? confidence = null,Object? ageRangeLow = null,Object? ageRangeHigh = null,}) {
  return _then(_FrbAgeEstimate(
estimatedAge: null == estimatedAge ? _self.estimatedAge : estimatedAge // ignore: cast_nullable_to_non_nullable
as int,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,ageRangeLow: null == ageRangeLow ? _self.ageRangeLow : ageRangeLow // ignore: cast_nullable_to_non_nullable
as int,ageRangeHigh: null == ageRangeHigh ? _self.ageRangeHigh : ageRangeHigh // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$FrbFaceMatchResult {

 bool get verified; double get similarity; double get threshold; String get provider; double? get referenceQuality; double? get probeQuality; BigInt get processingTimeMs;
/// Create a copy of FrbFaceMatchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrbFaceMatchResultCopyWith<FrbFaceMatchResult> get copyWith => _$FrbFaceMatchResultCopyWithImpl<FrbFaceMatchResult>(this as FrbFaceMatchResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrbFaceMatchResult&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.similarity, similarity) || other.similarity == similarity)&&(identical(other.threshold, threshold) || other.threshold == threshold)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.referenceQuality, referenceQuality) || other.referenceQuality == referenceQuality)&&(identical(other.probeQuality, probeQuality) || other.probeQuality == probeQuality)&&(identical(other.processingTimeMs, processingTimeMs) || other.processingTimeMs == processingTimeMs));
}


@override
int get hashCode => Object.hash(runtimeType,verified,similarity,threshold,provider,referenceQuality,probeQuality,processingTimeMs);

@override
String toString() {
  return 'FrbFaceMatchResult(verified: $verified, similarity: $similarity, threshold: $threshold, provider: $provider, referenceQuality: $referenceQuality, probeQuality: $probeQuality, processingTimeMs: $processingTimeMs)';
}


}

/// @nodoc
abstract mixin class $FrbFaceMatchResultCopyWith<$Res>  {
  factory $FrbFaceMatchResultCopyWith(FrbFaceMatchResult value, $Res Function(FrbFaceMatchResult) _then) = _$FrbFaceMatchResultCopyWithImpl;
@useResult
$Res call({
 bool verified, double similarity, double threshold, String provider, double? referenceQuality, double? probeQuality, BigInt processingTimeMs
});




}
/// @nodoc
class _$FrbFaceMatchResultCopyWithImpl<$Res>
    implements $FrbFaceMatchResultCopyWith<$Res> {
  _$FrbFaceMatchResultCopyWithImpl(this._self, this._then);

  final FrbFaceMatchResult _self;
  final $Res Function(FrbFaceMatchResult) _then;

/// Create a copy of FrbFaceMatchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? verified = null,Object? similarity = null,Object? threshold = null,Object? provider = null,Object? referenceQuality = freezed,Object? probeQuality = freezed,Object? processingTimeMs = null,}) {
  return _then(_self.copyWith(
verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,similarity: null == similarity ? _self.similarity : similarity // ignore: cast_nullable_to_non_nullable
as double,threshold: null == threshold ? _self.threshold : threshold // ignore: cast_nullable_to_non_nullable
as double,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,referenceQuality: freezed == referenceQuality ? _self.referenceQuality : referenceQuality // ignore: cast_nullable_to_non_nullable
as double?,probeQuality: freezed == probeQuality ? _self.probeQuality : probeQuality // ignore: cast_nullable_to_non_nullable
as double?,processingTimeMs: null == processingTimeMs ? _self.processingTimeMs : processingTimeMs // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}

}


/// Adds pattern-matching-related methods to [FrbFaceMatchResult].
extension FrbFaceMatchResultPatterns on FrbFaceMatchResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrbFaceMatchResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrbFaceMatchResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrbFaceMatchResult value)  $default,){
final _that = this;
switch (_that) {
case _FrbFaceMatchResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrbFaceMatchResult value)?  $default,){
final _that = this;
switch (_that) {
case _FrbFaceMatchResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool verified,  double similarity,  double threshold,  String provider,  double? referenceQuality,  double? probeQuality,  BigInt processingTimeMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrbFaceMatchResult() when $default != null:
return $default(_that.verified,_that.similarity,_that.threshold,_that.provider,_that.referenceQuality,_that.probeQuality,_that.processingTimeMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool verified,  double similarity,  double threshold,  String provider,  double? referenceQuality,  double? probeQuality,  BigInt processingTimeMs)  $default,) {final _that = this;
switch (_that) {
case _FrbFaceMatchResult():
return $default(_that.verified,_that.similarity,_that.threshold,_that.provider,_that.referenceQuality,_that.probeQuality,_that.processingTimeMs);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool verified,  double similarity,  double threshold,  String provider,  double? referenceQuality,  double? probeQuality,  BigInt processingTimeMs)?  $default,) {final _that = this;
switch (_that) {
case _FrbFaceMatchResult() when $default != null:
return $default(_that.verified,_that.similarity,_that.threshold,_that.provider,_that.referenceQuality,_that.probeQuality,_that.processingTimeMs);case _:
  return null;

}
}

}

/// @nodoc


class _FrbFaceMatchResult implements FrbFaceMatchResult {
  const _FrbFaceMatchResult({required this.verified, required this.similarity, required this.threshold, required this.provider, this.referenceQuality, this.probeQuality, required this.processingTimeMs});
  

@override final  bool verified;
@override final  double similarity;
@override final  double threshold;
@override final  String provider;
@override final  double? referenceQuality;
@override final  double? probeQuality;
@override final  BigInt processingTimeMs;

/// Create a copy of FrbFaceMatchResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrbFaceMatchResultCopyWith<_FrbFaceMatchResult> get copyWith => __$FrbFaceMatchResultCopyWithImpl<_FrbFaceMatchResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrbFaceMatchResult&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.similarity, similarity) || other.similarity == similarity)&&(identical(other.threshold, threshold) || other.threshold == threshold)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.referenceQuality, referenceQuality) || other.referenceQuality == referenceQuality)&&(identical(other.probeQuality, probeQuality) || other.probeQuality == probeQuality)&&(identical(other.processingTimeMs, processingTimeMs) || other.processingTimeMs == processingTimeMs));
}


@override
int get hashCode => Object.hash(runtimeType,verified,similarity,threshold,provider,referenceQuality,probeQuality,processingTimeMs);

@override
String toString() {
  return 'FrbFaceMatchResult(verified: $verified, similarity: $similarity, threshold: $threshold, provider: $provider, referenceQuality: $referenceQuality, probeQuality: $probeQuality, processingTimeMs: $processingTimeMs)';
}


}

/// @nodoc
abstract mixin class _$FrbFaceMatchResultCopyWith<$Res> implements $FrbFaceMatchResultCopyWith<$Res> {
  factory _$FrbFaceMatchResultCopyWith(_FrbFaceMatchResult value, $Res Function(_FrbFaceMatchResult) _then) = __$FrbFaceMatchResultCopyWithImpl;
@override @useResult
$Res call({
 bool verified, double similarity, double threshold, String provider, double? referenceQuality, double? probeQuality, BigInt processingTimeMs
});




}
/// @nodoc
class __$FrbFaceMatchResultCopyWithImpl<$Res>
    implements _$FrbFaceMatchResultCopyWith<$Res> {
  __$FrbFaceMatchResultCopyWithImpl(this._self, this._then);

  final _FrbFaceMatchResult _self;
  final $Res Function(_FrbFaceMatchResult) _then;

/// Create a copy of FrbFaceMatchResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? verified = null,Object? similarity = null,Object? threshold = null,Object? provider = null,Object? referenceQuality = freezed,Object? probeQuality = freezed,Object? processingTimeMs = null,}) {
  return _then(_FrbFaceMatchResult(
verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,similarity: null == similarity ? _self.similarity : similarity // ignore: cast_nullable_to_non_nullable
as double,threshold: null == threshold ? _self.threshold : threshold // ignore: cast_nullable_to_non_nullable
as double,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,referenceQuality: freezed == referenceQuality ? _self.referenceQuality : referenceQuality // ignore: cast_nullable_to_non_nullable
as double?,probeQuality: freezed == probeQuality ? _self.probeQuality : probeQuality // ignore: cast_nullable_to_non_nullable
as double?,processingTimeMs: null == processingTimeMs ? _self.processingTimeMs : processingTimeMs // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc
mixin _$FrbFaceQuality {

 double get overallScore; bool get faceDetected; int get faceCount; double get sharpness; double get brightness; double get contrast; double get faceSize; double get pose;
/// Create a copy of FrbFaceQuality
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrbFaceQualityCopyWith<FrbFaceQuality> get copyWith => _$FrbFaceQualityCopyWithImpl<FrbFaceQuality>(this as FrbFaceQuality, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrbFaceQuality&&(identical(other.overallScore, overallScore) || other.overallScore == overallScore)&&(identical(other.faceDetected, faceDetected) || other.faceDetected == faceDetected)&&(identical(other.faceCount, faceCount) || other.faceCount == faceCount)&&(identical(other.sharpness, sharpness) || other.sharpness == sharpness)&&(identical(other.brightness, brightness) || other.brightness == brightness)&&(identical(other.contrast, contrast) || other.contrast == contrast)&&(identical(other.faceSize, faceSize) || other.faceSize == faceSize)&&(identical(other.pose, pose) || other.pose == pose));
}


@override
int get hashCode => Object.hash(runtimeType,overallScore,faceDetected,faceCount,sharpness,brightness,contrast,faceSize,pose);

@override
String toString() {
  return 'FrbFaceQuality(overallScore: $overallScore, faceDetected: $faceDetected, faceCount: $faceCount, sharpness: $sharpness, brightness: $brightness, contrast: $contrast, faceSize: $faceSize, pose: $pose)';
}


}

/// @nodoc
abstract mixin class $FrbFaceQualityCopyWith<$Res>  {
  factory $FrbFaceQualityCopyWith(FrbFaceQuality value, $Res Function(FrbFaceQuality) _then) = _$FrbFaceQualityCopyWithImpl;
@useResult
$Res call({
 double overallScore, bool faceDetected, int faceCount, double sharpness, double brightness, double contrast, double faceSize, double pose
});




}
/// @nodoc
class _$FrbFaceQualityCopyWithImpl<$Res>
    implements $FrbFaceQualityCopyWith<$Res> {
  _$FrbFaceQualityCopyWithImpl(this._self, this._then);

  final FrbFaceQuality _self;
  final $Res Function(FrbFaceQuality) _then;

/// Create a copy of FrbFaceQuality
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? overallScore = null,Object? faceDetected = null,Object? faceCount = null,Object? sharpness = null,Object? brightness = null,Object? contrast = null,Object? faceSize = null,Object? pose = null,}) {
  return _then(_self.copyWith(
overallScore: null == overallScore ? _self.overallScore : overallScore // ignore: cast_nullable_to_non_nullable
as double,faceDetected: null == faceDetected ? _self.faceDetected : faceDetected // ignore: cast_nullable_to_non_nullable
as bool,faceCount: null == faceCount ? _self.faceCount : faceCount // ignore: cast_nullable_to_non_nullable
as int,sharpness: null == sharpness ? _self.sharpness : sharpness // ignore: cast_nullable_to_non_nullable
as double,brightness: null == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as double,contrast: null == contrast ? _self.contrast : contrast // ignore: cast_nullable_to_non_nullable
as double,faceSize: null == faceSize ? _self.faceSize : faceSize // ignore: cast_nullable_to_non_nullable
as double,pose: null == pose ? _self.pose : pose // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [FrbFaceQuality].
extension FrbFaceQualityPatterns on FrbFaceQuality {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrbFaceQuality value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrbFaceQuality() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrbFaceQuality value)  $default,){
final _that = this;
switch (_that) {
case _FrbFaceQuality():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrbFaceQuality value)?  $default,){
final _that = this;
switch (_that) {
case _FrbFaceQuality() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double overallScore,  bool faceDetected,  int faceCount,  double sharpness,  double brightness,  double contrast,  double faceSize,  double pose)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrbFaceQuality() when $default != null:
return $default(_that.overallScore,_that.faceDetected,_that.faceCount,_that.sharpness,_that.brightness,_that.contrast,_that.faceSize,_that.pose);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double overallScore,  bool faceDetected,  int faceCount,  double sharpness,  double brightness,  double contrast,  double faceSize,  double pose)  $default,) {final _that = this;
switch (_that) {
case _FrbFaceQuality():
return $default(_that.overallScore,_that.faceDetected,_that.faceCount,_that.sharpness,_that.brightness,_that.contrast,_that.faceSize,_that.pose);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double overallScore,  bool faceDetected,  int faceCount,  double sharpness,  double brightness,  double contrast,  double faceSize,  double pose)?  $default,) {final _that = this;
switch (_that) {
case _FrbFaceQuality() when $default != null:
return $default(_that.overallScore,_that.faceDetected,_that.faceCount,_that.sharpness,_that.brightness,_that.contrast,_that.faceSize,_that.pose);case _:
  return null;

}
}

}

/// @nodoc


class _FrbFaceQuality implements FrbFaceQuality {
  const _FrbFaceQuality({required this.overallScore, required this.faceDetected, required this.faceCount, required this.sharpness, required this.brightness, required this.contrast, required this.faceSize, required this.pose});
  

@override final  double overallScore;
@override final  bool faceDetected;
@override final  int faceCount;
@override final  double sharpness;
@override final  double brightness;
@override final  double contrast;
@override final  double faceSize;
@override final  double pose;

/// Create a copy of FrbFaceQuality
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrbFaceQualityCopyWith<_FrbFaceQuality> get copyWith => __$FrbFaceQualityCopyWithImpl<_FrbFaceQuality>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrbFaceQuality&&(identical(other.overallScore, overallScore) || other.overallScore == overallScore)&&(identical(other.faceDetected, faceDetected) || other.faceDetected == faceDetected)&&(identical(other.faceCount, faceCount) || other.faceCount == faceCount)&&(identical(other.sharpness, sharpness) || other.sharpness == sharpness)&&(identical(other.brightness, brightness) || other.brightness == brightness)&&(identical(other.contrast, contrast) || other.contrast == contrast)&&(identical(other.faceSize, faceSize) || other.faceSize == faceSize)&&(identical(other.pose, pose) || other.pose == pose));
}


@override
int get hashCode => Object.hash(runtimeType,overallScore,faceDetected,faceCount,sharpness,brightness,contrast,faceSize,pose);

@override
String toString() {
  return 'FrbFaceQuality(overallScore: $overallScore, faceDetected: $faceDetected, faceCount: $faceCount, sharpness: $sharpness, brightness: $brightness, contrast: $contrast, faceSize: $faceSize, pose: $pose)';
}


}

/// @nodoc
abstract mixin class _$FrbFaceQualityCopyWith<$Res> implements $FrbFaceQualityCopyWith<$Res> {
  factory _$FrbFaceQualityCopyWith(_FrbFaceQuality value, $Res Function(_FrbFaceQuality) _then) = __$FrbFaceQualityCopyWithImpl;
@override @useResult
$Res call({
 double overallScore, bool faceDetected, int faceCount, double sharpness, double brightness, double contrast, double faceSize, double pose
});




}
/// @nodoc
class __$FrbFaceQualityCopyWithImpl<$Res>
    implements _$FrbFaceQualityCopyWith<$Res> {
  __$FrbFaceQualityCopyWithImpl(this._self, this._then);

  final _FrbFaceQuality _self;
  final $Res Function(_FrbFaceQuality) _then;

/// Create a copy of FrbFaceQuality
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? overallScore = null,Object? faceDetected = null,Object? faceCount = null,Object? sharpness = null,Object? brightness = null,Object? contrast = null,Object? faceSize = null,Object? pose = null,}) {
  return _then(_FrbFaceQuality(
overallScore: null == overallScore ? _self.overallScore : overallScore // ignore: cast_nullable_to_non_nullable
as double,faceDetected: null == faceDetected ? _self.faceDetected : faceDetected // ignore: cast_nullable_to_non_nullable
as bool,faceCount: null == faceCount ? _self.faceCount : faceCount // ignore: cast_nullable_to_non_nullable
as int,sharpness: null == sharpness ? _self.sharpness : sharpness // ignore: cast_nullable_to_non_nullable
as double,brightness: null == brightness ? _self.brightness : brightness // ignore: cast_nullable_to_non_nullable
as double,contrast: null == contrast ? _self.contrast : contrast // ignore: cast_nullable_to_non_nullable
as double,faceSize: null == faceSize ? _self.faceSize : faceSize // ignore: cast_nullable_to_non_nullable
as double,pose: null == pose ? _self.pose : pose // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$FrbLivenessChallenge {

 String get challengeId; String get nonce; String get issuedAt; String get expiresAt; List<String> get gestures; String get signature; String get nativePayload;
/// Create a copy of FrbLivenessChallenge
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrbLivenessChallengeCopyWith<FrbLivenessChallenge> get copyWith => _$FrbLivenessChallengeCopyWithImpl<FrbLivenessChallenge>(this as FrbLivenessChallenge, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrbLivenessChallenge&&(identical(other.challengeId, challengeId) || other.challengeId == challengeId)&&(identical(other.nonce, nonce) || other.nonce == nonce)&&(identical(other.issuedAt, issuedAt) || other.issuedAt == issuedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other.gestures, gestures)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.nativePayload, nativePayload) || other.nativePayload == nativePayload));
}


@override
int get hashCode => Object.hash(runtimeType,challengeId,nonce,issuedAt,expiresAt,const DeepCollectionEquality().hash(gestures),signature,nativePayload);

@override
String toString() {
  return 'FrbLivenessChallenge(challengeId: $challengeId, nonce: $nonce, issuedAt: $issuedAt, expiresAt: $expiresAt, gestures: $gestures, signature: $signature, nativePayload: $nativePayload)';
}


}

/// @nodoc
abstract mixin class $FrbLivenessChallengeCopyWith<$Res>  {
  factory $FrbLivenessChallengeCopyWith(FrbLivenessChallenge value, $Res Function(FrbLivenessChallenge) _then) = _$FrbLivenessChallengeCopyWithImpl;
@useResult
$Res call({
 String challengeId, String nonce, String issuedAt, String expiresAt, List<String> gestures, String signature, String nativePayload
});




}
/// @nodoc
class _$FrbLivenessChallengeCopyWithImpl<$Res>
    implements $FrbLivenessChallengeCopyWith<$Res> {
  _$FrbLivenessChallengeCopyWithImpl(this._self, this._then);

  final FrbLivenessChallenge _self;
  final $Res Function(FrbLivenessChallenge) _then;

/// Create a copy of FrbLivenessChallenge
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? challengeId = null,Object? nonce = null,Object? issuedAt = null,Object? expiresAt = null,Object? gestures = null,Object? signature = null,Object? nativePayload = null,}) {
  return _then(_self.copyWith(
challengeId: null == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String,nonce: null == nonce ? _self.nonce : nonce // ignore: cast_nullable_to_non_nullable
as String,issuedAt: null == issuedAt ? _self.issuedAt : issuedAt // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String,gestures: null == gestures ? _self.gestures : gestures // ignore: cast_nullable_to_non_nullable
as List<String>,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,nativePayload: null == nativePayload ? _self.nativePayload : nativePayload // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FrbLivenessChallenge].
extension FrbLivenessChallengePatterns on FrbLivenessChallenge {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrbLivenessChallenge value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrbLivenessChallenge() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrbLivenessChallenge value)  $default,){
final _that = this;
switch (_that) {
case _FrbLivenessChallenge():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrbLivenessChallenge value)?  $default,){
final _that = this;
switch (_that) {
case _FrbLivenessChallenge() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String challengeId,  String nonce,  String issuedAt,  String expiresAt,  List<String> gestures,  String signature,  String nativePayload)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrbLivenessChallenge() when $default != null:
return $default(_that.challengeId,_that.nonce,_that.issuedAt,_that.expiresAt,_that.gestures,_that.signature,_that.nativePayload);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String challengeId,  String nonce,  String issuedAt,  String expiresAt,  List<String> gestures,  String signature,  String nativePayload)  $default,) {final _that = this;
switch (_that) {
case _FrbLivenessChallenge():
return $default(_that.challengeId,_that.nonce,_that.issuedAt,_that.expiresAt,_that.gestures,_that.signature,_that.nativePayload);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String challengeId,  String nonce,  String issuedAt,  String expiresAt,  List<String> gestures,  String signature,  String nativePayload)?  $default,) {final _that = this;
switch (_that) {
case _FrbLivenessChallenge() when $default != null:
return $default(_that.challengeId,_that.nonce,_that.issuedAt,_that.expiresAt,_that.gestures,_that.signature,_that.nativePayload);case _:
  return null;

}
}

}

/// @nodoc


class _FrbLivenessChallenge implements FrbLivenessChallenge {
  const _FrbLivenessChallenge({required this.challengeId, required this.nonce, required this.issuedAt, required this.expiresAt, required final  List<String> gestures, required this.signature, required this.nativePayload}): _gestures = gestures;
  

@override final  String challengeId;
@override final  String nonce;
@override final  String issuedAt;
@override final  String expiresAt;
 final  List<String> _gestures;
@override List<String> get gestures {
  if (_gestures is EqualUnmodifiableListView) return _gestures;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_gestures);
}

@override final  String signature;
@override final  String nativePayload;

/// Create a copy of FrbLivenessChallenge
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrbLivenessChallengeCopyWith<_FrbLivenessChallenge> get copyWith => __$FrbLivenessChallengeCopyWithImpl<_FrbLivenessChallenge>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrbLivenessChallenge&&(identical(other.challengeId, challengeId) || other.challengeId == challengeId)&&(identical(other.nonce, nonce) || other.nonce == nonce)&&(identical(other.issuedAt, issuedAt) || other.issuedAt == issuedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other._gestures, _gestures)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.nativePayload, nativePayload) || other.nativePayload == nativePayload));
}


@override
int get hashCode => Object.hash(runtimeType,challengeId,nonce,issuedAt,expiresAt,const DeepCollectionEquality().hash(_gestures),signature,nativePayload);

@override
String toString() {
  return 'FrbLivenessChallenge(challengeId: $challengeId, nonce: $nonce, issuedAt: $issuedAt, expiresAt: $expiresAt, gestures: $gestures, signature: $signature, nativePayload: $nativePayload)';
}


}

/// @nodoc
abstract mixin class _$FrbLivenessChallengeCopyWith<$Res> implements $FrbLivenessChallengeCopyWith<$Res> {
  factory _$FrbLivenessChallengeCopyWith(_FrbLivenessChallenge value, $Res Function(_FrbLivenessChallenge) _then) = __$FrbLivenessChallengeCopyWithImpl;
@override @useResult
$Res call({
 String challengeId, String nonce, String issuedAt, String expiresAt, List<String> gestures, String signature, String nativePayload
});




}
/// @nodoc
class __$FrbLivenessChallengeCopyWithImpl<$Res>
    implements _$FrbLivenessChallengeCopyWith<$Res> {
  __$FrbLivenessChallengeCopyWithImpl(this._self, this._then);

  final _FrbLivenessChallenge _self;
  final $Res Function(_FrbLivenessChallenge) _then;

/// Create a copy of FrbLivenessChallenge
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? challengeId = null,Object? nonce = null,Object? issuedAt = null,Object? expiresAt = null,Object? gestures = null,Object? signature = null,Object? nativePayload = null,}) {
  return _then(_FrbLivenessChallenge(
challengeId: null == challengeId ? _self.challengeId : challengeId // ignore: cast_nullable_to_non_nullable
as String,nonce: null == nonce ? _self.nonce : nonce // ignore: cast_nullable_to_non_nullable
as String,issuedAt: null == issuedAt ? _self.issuedAt : issuedAt // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String,gestures: null == gestures ? _self._gestures : gestures // ignore: cast_nullable_to_non_nullable
as List<String>,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,nativePayload: null == nativePayload ? _self.nativePayload : nativePayload // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
