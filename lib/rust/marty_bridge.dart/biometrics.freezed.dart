// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'biometrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$FrbAgeEstimate {
  int get estimatedAge => throw _privateConstructorUsedError;
  double get confidence => throw _privateConstructorUsedError;
  int get ageRangeLow => throw _privateConstructorUsedError;
  int get ageRangeHigh => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $FrbAgeEstimateCopyWith<FrbAgeEstimate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FrbAgeEstimateCopyWith<$Res> {
  factory $FrbAgeEstimateCopyWith(
    FrbAgeEstimate value,
    $Res Function(FrbAgeEstimate) then,
  ) = _$FrbAgeEstimateCopyWithImpl<$Res, FrbAgeEstimate>;
  @useResult
  $Res call({
    int estimatedAge,
    double confidence,
    int ageRangeLow,
    int ageRangeHigh,
  });
}

/// @nodoc
class _$FrbAgeEstimateCopyWithImpl<$Res, $Val extends FrbAgeEstimate>
    implements $FrbAgeEstimateCopyWith<$Res> {
  _$FrbAgeEstimateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? estimatedAge = null,
    Object? confidence = null,
    Object? ageRangeLow = null,
    Object? ageRangeHigh = null,
  }) {
    return _then(
      _value.copyWith(
            estimatedAge: null == estimatedAge
                ? _value.estimatedAge
                : estimatedAge // ignore: cast_nullable_to_non_nullable
                      as int,
            confidence: null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                      as double,
            ageRangeLow: null == ageRangeLow
                ? _value.ageRangeLow
                : ageRangeLow // ignore: cast_nullable_to_non_nullable
                      as int,
            ageRangeHigh: null == ageRangeHigh
                ? _value.ageRangeHigh
                : ageRangeHigh // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FrbAgeEstimateImplCopyWith<$Res>
    implements $FrbAgeEstimateCopyWith<$Res> {
  factory _$$FrbAgeEstimateImplCopyWith(
    _$FrbAgeEstimateImpl value,
    $Res Function(_$FrbAgeEstimateImpl) then,
  ) = __$$FrbAgeEstimateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int estimatedAge,
    double confidence,
    int ageRangeLow,
    int ageRangeHigh,
  });
}

/// @nodoc
class __$$FrbAgeEstimateImplCopyWithImpl<$Res>
    extends _$FrbAgeEstimateCopyWithImpl<$Res, _$FrbAgeEstimateImpl>
    implements _$$FrbAgeEstimateImplCopyWith<$Res> {
  __$$FrbAgeEstimateImplCopyWithImpl(
    _$FrbAgeEstimateImpl _value,
    $Res Function(_$FrbAgeEstimateImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? estimatedAge = null,
    Object? confidence = null,
    Object? ageRangeLow = null,
    Object? ageRangeHigh = null,
  }) {
    return _then(
      _$FrbAgeEstimateImpl(
        estimatedAge: null == estimatedAge
            ? _value.estimatedAge
            : estimatedAge // ignore: cast_nullable_to_non_nullable
                  as int,
        confidence: null == confidence
            ? _value.confidence
            : confidence // ignore: cast_nullable_to_non_nullable
                  as double,
        ageRangeLow: null == ageRangeLow
            ? _value.ageRangeLow
            : ageRangeLow // ignore: cast_nullable_to_non_nullable
                  as int,
        ageRangeHigh: null == ageRangeHigh
            ? _value.ageRangeHigh
            : ageRangeHigh // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$FrbAgeEstimateImpl implements _FrbAgeEstimate {
  const _$FrbAgeEstimateImpl({
    required this.estimatedAge,
    required this.confidence,
    required this.ageRangeLow,
    required this.ageRangeHigh,
  });

  @override
  final int estimatedAge;
  @override
  final double confidence;
  @override
  final int ageRangeLow;
  @override
  final int ageRangeHigh;

  @override
  String toString() {
    return 'FrbAgeEstimate(estimatedAge: $estimatedAge, confidence: $confidence, ageRangeLow: $ageRangeLow, ageRangeHigh: $ageRangeHigh)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FrbAgeEstimateImpl &&
            (identical(other.estimatedAge, estimatedAge) ||
                other.estimatedAge == estimatedAge) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.ageRangeLow, ageRangeLow) ||
                other.ageRangeLow == ageRangeLow) &&
            (identical(other.ageRangeHigh, ageRangeHigh) ||
                other.ageRangeHigh == ageRangeHigh));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    estimatedAge,
    confidence,
    ageRangeLow,
    ageRangeHigh,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FrbAgeEstimateImplCopyWith<_$FrbAgeEstimateImpl> get copyWith =>
      __$$FrbAgeEstimateImplCopyWithImpl<_$FrbAgeEstimateImpl>(
        this,
        _$identity,
      );
}

abstract class _FrbAgeEstimate implements FrbAgeEstimate {
  const factory _FrbAgeEstimate({
    required final int estimatedAge,
    required final double confidence,
    required final int ageRangeLow,
    required final int ageRangeHigh,
  }) = _$FrbAgeEstimateImpl;

  @override
  int get estimatedAge;
  @override
  double get confidence;
  @override
  int get ageRangeLow;
  @override
  int get ageRangeHigh;
  @override
  @JsonKey(ignore: true)
  _$$FrbAgeEstimateImplCopyWith<_$FrbAgeEstimateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$FrbFaceMatchResult {
  bool get verified => throw _privateConstructorUsedError;
  double get similarity => throw _privateConstructorUsedError;
  double get threshold => throw _privateConstructorUsedError;
  String get provider => throw _privateConstructorUsedError;
  double? get referenceQuality => throw _privateConstructorUsedError;
  double? get probeQuality => throw _privateConstructorUsedError;
  BigInt get processingTimeMs => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $FrbFaceMatchResultCopyWith<FrbFaceMatchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FrbFaceMatchResultCopyWith<$Res> {
  factory $FrbFaceMatchResultCopyWith(
    FrbFaceMatchResult value,
    $Res Function(FrbFaceMatchResult) then,
  ) = _$FrbFaceMatchResultCopyWithImpl<$Res, FrbFaceMatchResult>;
  @useResult
  $Res call({
    bool verified,
    double similarity,
    double threshold,
    String provider,
    double? referenceQuality,
    double? probeQuality,
    BigInt processingTimeMs,
  });
}

/// @nodoc
class _$FrbFaceMatchResultCopyWithImpl<$Res, $Val extends FrbFaceMatchResult>
    implements $FrbFaceMatchResultCopyWith<$Res> {
  _$FrbFaceMatchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? verified = null,
    Object? similarity = null,
    Object? threshold = null,
    Object? provider = null,
    Object? referenceQuality = freezed,
    Object? probeQuality = freezed,
    Object? processingTimeMs = null,
  }) {
    return _then(
      _value.copyWith(
            verified: null == verified
                ? _value.verified
                : verified // ignore: cast_nullable_to_non_nullable
                      as bool,
            similarity: null == similarity
                ? _value.similarity
                : similarity // ignore: cast_nullable_to_non_nullable
                      as double,
            threshold: null == threshold
                ? _value.threshold
                : threshold // ignore: cast_nullable_to_non_nullable
                      as double,
            provider: null == provider
                ? _value.provider
                : provider // ignore: cast_nullable_to_non_nullable
                      as String,
            referenceQuality: freezed == referenceQuality
                ? _value.referenceQuality
                : referenceQuality // ignore: cast_nullable_to_non_nullable
                      as double?,
            probeQuality: freezed == probeQuality
                ? _value.probeQuality
                : probeQuality // ignore: cast_nullable_to_non_nullable
                      as double?,
            processingTimeMs: null == processingTimeMs
                ? _value.processingTimeMs
                : processingTimeMs // ignore: cast_nullable_to_non_nullable
                      as BigInt,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FrbFaceMatchResultImplCopyWith<$Res>
    implements $FrbFaceMatchResultCopyWith<$Res> {
  factory _$$FrbFaceMatchResultImplCopyWith(
    _$FrbFaceMatchResultImpl value,
    $Res Function(_$FrbFaceMatchResultImpl) then,
  ) = __$$FrbFaceMatchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool verified,
    double similarity,
    double threshold,
    String provider,
    double? referenceQuality,
    double? probeQuality,
    BigInt processingTimeMs,
  });
}

/// @nodoc
class __$$FrbFaceMatchResultImplCopyWithImpl<$Res>
    extends _$FrbFaceMatchResultCopyWithImpl<$Res, _$FrbFaceMatchResultImpl>
    implements _$$FrbFaceMatchResultImplCopyWith<$Res> {
  __$$FrbFaceMatchResultImplCopyWithImpl(
    _$FrbFaceMatchResultImpl _value,
    $Res Function(_$FrbFaceMatchResultImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? verified = null,
    Object? similarity = null,
    Object? threshold = null,
    Object? provider = null,
    Object? referenceQuality = freezed,
    Object? probeQuality = freezed,
    Object? processingTimeMs = null,
  }) {
    return _then(
      _$FrbFaceMatchResultImpl(
        verified: null == verified
            ? _value.verified
            : verified // ignore: cast_nullable_to_non_nullable
                  as bool,
        similarity: null == similarity
            ? _value.similarity
            : similarity // ignore: cast_nullable_to_non_nullable
                  as double,
        threshold: null == threshold
            ? _value.threshold
            : threshold // ignore: cast_nullable_to_non_nullable
                  as double,
        provider: null == provider
            ? _value.provider
            : provider // ignore: cast_nullable_to_non_nullable
                  as String,
        referenceQuality: freezed == referenceQuality
            ? _value.referenceQuality
            : referenceQuality // ignore: cast_nullable_to_non_nullable
                  as double?,
        probeQuality: freezed == probeQuality
            ? _value.probeQuality
            : probeQuality // ignore: cast_nullable_to_non_nullable
                  as double?,
        processingTimeMs: null == processingTimeMs
            ? _value.processingTimeMs
            : processingTimeMs // ignore: cast_nullable_to_non_nullable
                  as BigInt,
      ),
    );
  }
}

/// @nodoc

class _$FrbFaceMatchResultImpl implements _FrbFaceMatchResult {
  const _$FrbFaceMatchResultImpl({
    required this.verified,
    required this.similarity,
    required this.threshold,
    required this.provider,
    this.referenceQuality,
    this.probeQuality,
    required this.processingTimeMs,
  });

  @override
  final bool verified;
  @override
  final double similarity;
  @override
  final double threshold;
  @override
  final String provider;
  @override
  final double? referenceQuality;
  @override
  final double? probeQuality;
  @override
  final BigInt processingTimeMs;

  @override
  String toString() {
    return 'FrbFaceMatchResult(verified: $verified, similarity: $similarity, threshold: $threshold, provider: $provider, referenceQuality: $referenceQuality, probeQuality: $probeQuality, processingTimeMs: $processingTimeMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FrbFaceMatchResultImpl &&
            (identical(other.verified, verified) ||
                other.verified == verified) &&
            (identical(other.similarity, similarity) ||
                other.similarity == similarity) &&
            (identical(other.threshold, threshold) ||
                other.threshold == threshold) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.referenceQuality, referenceQuality) ||
                other.referenceQuality == referenceQuality) &&
            (identical(other.probeQuality, probeQuality) ||
                other.probeQuality == probeQuality) &&
            (identical(other.processingTimeMs, processingTimeMs) ||
                other.processingTimeMs == processingTimeMs));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    verified,
    similarity,
    threshold,
    provider,
    referenceQuality,
    probeQuality,
    processingTimeMs,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FrbFaceMatchResultImplCopyWith<_$FrbFaceMatchResultImpl> get copyWith =>
      __$$FrbFaceMatchResultImplCopyWithImpl<_$FrbFaceMatchResultImpl>(
        this,
        _$identity,
      );
}

abstract class _FrbFaceMatchResult implements FrbFaceMatchResult {
  const factory _FrbFaceMatchResult({
    required final bool verified,
    required final double similarity,
    required final double threshold,
    required final String provider,
    final double? referenceQuality,
    final double? probeQuality,
    required final BigInt processingTimeMs,
  }) = _$FrbFaceMatchResultImpl;

  @override
  bool get verified;
  @override
  double get similarity;
  @override
  double get threshold;
  @override
  String get provider;
  @override
  double? get referenceQuality;
  @override
  double? get probeQuality;
  @override
  BigInt get processingTimeMs;
  @override
  @JsonKey(ignore: true)
  _$$FrbFaceMatchResultImplCopyWith<_$FrbFaceMatchResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$FrbFaceQuality {
  double get overallScore => throw _privateConstructorUsedError;
  bool get faceDetected => throw _privateConstructorUsedError;
  int get faceCount => throw _privateConstructorUsedError;
  double get sharpness => throw _privateConstructorUsedError;
  double get brightness => throw _privateConstructorUsedError;
  double get contrast => throw _privateConstructorUsedError;
  double get faceSize => throw _privateConstructorUsedError;
  double get pose => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $FrbFaceQualityCopyWith<FrbFaceQuality> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FrbFaceQualityCopyWith<$Res> {
  factory $FrbFaceQualityCopyWith(
    FrbFaceQuality value,
    $Res Function(FrbFaceQuality) then,
  ) = _$FrbFaceQualityCopyWithImpl<$Res, FrbFaceQuality>;
  @useResult
  $Res call({
    double overallScore,
    bool faceDetected,
    int faceCount,
    double sharpness,
    double brightness,
    double contrast,
    double faceSize,
    double pose,
  });
}

/// @nodoc
class _$FrbFaceQualityCopyWithImpl<$Res, $Val extends FrbFaceQuality>
    implements $FrbFaceQualityCopyWith<$Res> {
  _$FrbFaceQualityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? overallScore = null,
    Object? faceDetected = null,
    Object? faceCount = null,
    Object? sharpness = null,
    Object? brightness = null,
    Object? contrast = null,
    Object? faceSize = null,
    Object? pose = null,
  }) {
    return _then(
      _value.copyWith(
            overallScore: null == overallScore
                ? _value.overallScore
                : overallScore // ignore: cast_nullable_to_non_nullable
                      as double,
            faceDetected: null == faceDetected
                ? _value.faceDetected
                : faceDetected // ignore: cast_nullable_to_non_nullable
                      as bool,
            faceCount: null == faceCount
                ? _value.faceCount
                : faceCount // ignore: cast_nullable_to_non_nullable
                      as int,
            sharpness: null == sharpness
                ? _value.sharpness
                : sharpness // ignore: cast_nullable_to_non_nullable
                      as double,
            brightness: null == brightness
                ? _value.brightness
                : brightness // ignore: cast_nullable_to_non_nullable
                      as double,
            contrast: null == contrast
                ? _value.contrast
                : contrast // ignore: cast_nullable_to_non_nullable
                      as double,
            faceSize: null == faceSize
                ? _value.faceSize
                : faceSize // ignore: cast_nullable_to_non_nullable
                      as double,
            pose: null == pose
                ? _value.pose
                : pose // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FrbFaceQualityImplCopyWith<$Res>
    implements $FrbFaceQualityCopyWith<$Res> {
  factory _$$FrbFaceQualityImplCopyWith(
    _$FrbFaceQualityImpl value,
    $Res Function(_$FrbFaceQualityImpl) then,
  ) = __$$FrbFaceQualityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double overallScore,
    bool faceDetected,
    int faceCount,
    double sharpness,
    double brightness,
    double contrast,
    double faceSize,
    double pose,
  });
}

/// @nodoc
class __$$FrbFaceQualityImplCopyWithImpl<$Res>
    extends _$FrbFaceQualityCopyWithImpl<$Res, _$FrbFaceQualityImpl>
    implements _$$FrbFaceQualityImplCopyWith<$Res> {
  __$$FrbFaceQualityImplCopyWithImpl(
    _$FrbFaceQualityImpl _value,
    $Res Function(_$FrbFaceQualityImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? overallScore = null,
    Object? faceDetected = null,
    Object? faceCount = null,
    Object? sharpness = null,
    Object? brightness = null,
    Object? contrast = null,
    Object? faceSize = null,
    Object? pose = null,
  }) {
    return _then(
      _$FrbFaceQualityImpl(
        overallScore: null == overallScore
            ? _value.overallScore
            : overallScore // ignore: cast_nullable_to_non_nullable
                  as double,
        faceDetected: null == faceDetected
            ? _value.faceDetected
            : faceDetected // ignore: cast_nullable_to_non_nullable
                  as bool,
        faceCount: null == faceCount
            ? _value.faceCount
            : faceCount // ignore: cast_nullable_to_non_nullable
                  as int,
        sharpness: null == sharpness
            ? _value.sharpness
            : sharpness // ignore: cast_nullable_to_non_nullable
                  as double,
        brightness: null == brightness
            ? _value.brightness
            : brightness // ignore: cast_nullable_to_non_nullable
                  as double,
        contrast: null == contrast
            ? _value.contrast
            : contrast // ignore: cast_nullable_to_non_nullable
                  as double,
        faceSize: null == faceSize
            ? _value.faceSize
            : faceSize // ignore: cast_nullable_to_non_nullable
                  as double,
        pose: null == pose
            ? _value.pose
            : pose // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$FrbFaceQualityImpl implements _FrbFaceQuality {
  const _$FrbFaceQualityImpl({
    required this.overallScore,
    required this.faceDetected,
    required this.faceCount,
    required this.sharpness,
    required this.brightness,
    required this.contrast,
    required this.faceSize,
    required this.pose,
  });

  @override
  final double overallScore;
  @override
  final bool faceDetected;
  @override
  final int faceCount;
  @override
  final double sharpness;
  @override
  final double brightness;
  @override
  final double contrast;
  @override
  final double faceSize;
  @override
  final double pose;

  @override
  String toString() {
    return 'FrbFaceQuality(overallScore: $overallScore, faceDetected: $faceDetected, faceCount: $faceCount, sharpness: $sharpness, brightness: $brightness, contrast: $contrast, faceSize: $faceSize, pose: $pose)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FrbFaceQualityImpl &&
            (identical(other.overallScore, overallScore) ||
                other.overallScore == overallScore) &&
            (identical(other.faceDetected, faceDetected) ||
                other.faceDetected == faceDetected) &&
            (identical(other.faceCount, faceCount) ||
                other.faceCount == faceCount) &&
            (identical(other.sharpness, sharpness) ||
                other.sharpness == sharpness) &&
            (identical(other.brightness, brightness) ||
                other.brightness == brightness) &&
            (identical(other.contrast, contrast) ||
                other.contrast == contrast) &&
            (identical(other.faceSize, faceSize) ||
                other.faceSize == faceSize) &&
            (identical(other.pose, pose) || other.pose == pose));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    overallScore,
    faceDetected,
    faceCount,
    sharpness,
    brightness,
    contrast,
    faceSize,
    pose,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FrbFaceQualityImplCopyWith<_$FrbFaceQualityImpl> get copyWith =>
      __$$FrbFaceQualityImplCopyWithImpl<_$FrbFaceQualityImpl>(
        this,
        _$identity,
      );
}

abstract class _FrbFaceQuality implements FrbFaceQuality {
  const factory _FrbFaceQuality({
    required final double overallScore,
    required final bool faceDetected,
    required final int faceCount,
    required final double sharpness,
    required final double brightness,
    required final double contrast,
    required final double faceSize,
    required final double pose,
  }) = _$FrbFaceQualityImpl;

  @override
  double get overallScore;
  @override
  bool get faceDetected;
  @override
  int get faceCount;
  @override
  double get sharpness;
  @override
  double get brightness;
  @override
  double get contrast;
  @override
  double get faceSize;
  @override
  double get pose;
  @override
  @JsonKey(ignore: true)
  _$$FrbFaceQualityImplCopyWith<_$FrbFaceQualityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
