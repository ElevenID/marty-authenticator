// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pi_server_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$PiServerResponse<T extends PiServerResultValue> {
  int get statusCode => throw _privateConstructorUsedError;
  dynamic get detail => throw _privateConstructorUsedError;
  int get id => throw _privateConstructorUsedError;
  String get jsonrpc => throw _privateConstructorUsedError;
  double get time => throw _privateConstructorUsedError;
  String get version => throw _privateConstructorUsedError;
  String get versionNumber => throw _privateConstructorUsedError;
  String get signature => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            T resultValue,
            double time,
            String version,
            String versionNumber,
            String signature)
        success,
    required TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            PiServerResultError piServerResultError,
            double time,
            String version,
            String versionNumber,
            String signature)
        error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            T resultValue,
            double time,
            String version,
            String versionNumber,
            String signature)?
        success,
    TResult? Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            PiServerResultError piServerResultError,
            double time,
            String version,
            String versionNumber,
            String signature)?
        error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            T resultValue,
            double time,
            String version,
            String versionNumber,
            String signature)?
        success,
    TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            PiServerResultError piServerResultError,
            double time,
            String version,
            String versionNumber,
            String signature)?
        error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PiSuccessResponse<T> value) success,
    required TResult Function(PiErrorResponse<T> value) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PiSuccessResponse<T> value)? success,
    TResult? Function(PiErrorResponse<T> value)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PiSuccessResponse<T> value)? success,
    TResult Function(PiErrorResponse<T> value)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc

class _$PiSuccessResponseImpl<T extends PiServerResultValue>
    extends PiSuccessResponse<T> {
  _$PiSuccessResponseImpl(
      {required this.statusCode,
      required this.detail,
      required this.id,
      required this.jsonrpc,
      required this.resultValue,
      required this.time,
      required this.version,
      required this.versionNumber,
      required this.signature})
      : super._();

  @override
  final int statusCode;
  @override
  final dynamic detail;
  @override
  final int id;
  @override
  final String jsonrpc;
  @override
  final T resultValue;
  @override
  final double time;
  @override
  final String version;
  @override
  final String versionNumber;
  @override
  final String signature;

  @override
  String toString() {
    return 'PiServerResponse<$T>.success(statusCode: $statusCode, detail: $detail, id: $id, jsonrpc: $jsonrpc, resultValue: $resultValue, time: $time, version: $version, versionNumber: $versionNumber, signature: $signature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PiSuccessResponseImpl<T> &&
            (identical(other.statusCode, statusCode) ||
                other.statusCode == statusCode) &&
            const DeepCollectionEquality().equals(other.detail, detail) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.jsonrpc, jsonrpc) || other.jsonrpc == jsonrpc) &&
            const DeepCollectionEquality()
                .equals(other.resultValue, resultValue) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.versionNumber, versionNumber) ||
                other.versionNumber == versionNumber) &&
            (identical(other.signature, signature) ||
                other.signature == signature));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      statusCode,
      const DeepCollectionEquality().hash(detail),
      id,
      jsonrpc,
      const DeepCollectionEquality().hash(resultValue),
      time,
      version,
      versionNumber,
      signature);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            T resultValue,
            double time,
            String version,
            String versionNumber,
            String signature)
        success,
    required TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            PiServerResultError piServerResultError,
            double time,
            String version,
            String versionNumber,
            String signature)
        error,
  }) {
    return success(statusCode, detail, id, jsonrpc, resultValue, time, version,
        versionNumber, signature);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            T resultValue,
            double time,
            String version,
            String versionNumber,
            String signature)?
        success,
    TResult? Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            PiServerResultError piServerResultError,
            double time,
            String version,
            String versionNumber,
            String signature)?
        error,
  }) {
    return success?.call(statusCode, detail, id, jsonrpc, resultValue, time,
        version, versionNumber, signature);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            T resultValue,
            double time,
            String version,
            String versionNumber,
            String signature)?
        success,
    TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            PiServerResultError piServerResultError,
            double time,
            String version,
            String versionNumber,
            String signature)?
        error,
    required TResult orElse(),
  }) {
    if (success != null) {
      return success(statusCode, detail, id, jsonrpc, resultValue, time,
          version, versionNumber, signature);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PiSuccessResponse<T> value) success,
    required TResult Function(PiErrorResponse<T> value) error,
  }) {
    return success(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PiSuccessResponse<T> value)? success,
    TResult? Function(PiErrorResponse<T> value)? error,
  }) {
    return success?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PiSuccessResponse<T> value)? success,
    TResult Function(PiErrorResponse<T> value)? error,
    required TResult orElse(),
  }) {
    if (success != null) {
      return success(this);
    }
    return orElse();
  }
}

abstract class PiSuccessResponse<T extends PiServerResultValue>
    extends PiServerResponse<T> {
  factory PiSuccessResponse(
      {required final int statusCode,
      required final dynamic detail,
      required final int id,
      required final String jsonrpc,
      required final T resultValue,
      required final double time,
      required final String version,
      required final String versionNumber,
      required final String signature}) = _$PiSuccessResponseImpl<T>;
  PiSuccessResponse._() : super._();

  @override
  int get statusCode;
  @override
  dynamic get detail;
  @override
  int get id;
  @override
  String get jsonrpc;
  T get resultValue;
  @override
  double get time;
  @override
  String get version;
  @override
  String get versionNumber;
  @override
  String get signature;
}

/// @nodoc

class _$PiErrorResponseImpl<T extends PiServerResultValue>
    extends PiErrorResponse<T> {
  _$PiErrorResponseImpl(
      {required this.statusCode,
      required this.detail,
      required this.id,
      required this.jsonrpc,
      required this.piServerResultError,
      required this.time,
      required this.version,
      required this.versionNumber,
      required this.signature})
      : super._();

  @override
  final int statusCode;
  @override
  final dynamic detail;
  @override
  final int id;
  @override
  final String jsonrpc;

  /// This is a throwable error
  @override
  final PiServerResultError piServerResultError;
  @override
  final double time;
  @override
  final String version;
  @override
  final String versionNumber;
  @override
  final String signature;

  @override
  String toString() {
    return 'PiServerResponse<$T>.error(statusCode: $statusCode, detail: $detail, id: $id, jsonrpc: $jsonrpc, piServerResultError: $piServerResultError, time: $time, version: $version, versionNumber: $versionNumber, signature: $signature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PiErrorResponseImpl<T> &&
            (identical(other.statusCode, statusCode) ||
                other.statusCode == statusCode) &&
            const DeepCollectionEquality().equals(other.detail, detail) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.jsonrpc, jsonrpc) || other.jsonrpc == jsonrpc) &&
            (identical(other.piServerResultError, piServerResultError) ||
                other.piServerResultError == piServerResultError) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.versionNumber, versionNumber) ||
                other.versionNumber == versionNumber) &&
            (identical(other.signature, signature) ||
                other.signature == signature));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      statusCode,
      const DeepCollectionEquality().hash(detail),
      id,
      jsonrpc,
      piServerResultError,
      time,
      version,
      versionNumber,
      signature);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            T resultValue,
            double time,
            String version,
            String versionNumber,
            String signature)
        success,
    required TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            PiServerResultError piServerResultError,
            double time,
            String version,
            String versionNumber,
            String signature)
        error,
  }) {
    return error(statusCode, detail, id, jsonrpc, piServerResultError, time,
        version, versionNumber, signature);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            T resultValue,
            double time,
            String version,
            String versionNumber,
            String signature)?
        success,
    TResult? Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            PiServerResultError piServerResultError,
            double time,
            String version,
            String versionNumber,
            String signature)?
        error,
  }) {
    return error?.call(statusCode, detail, id, jsonrpc, piServerResultError,
        time, version, versionNumber, signature);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            T resultValue,
            double time,
            String version,
            String versionNumber,
            String signature)?
        success,
    TResult Function(
            int statusCode,
            dynamic detail,
            int id,
            String jsonrpc,
            PiServerResultError piServerResultError,
            double time,
            String version,
            String versionNumber,
            String signature)?
        error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(statusCode, detail, id, jsonrpc, piServerResultError, time,
          version, versionNumber, signature);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PiSuccessResponse<T> value) success,
    required TResult Function(PiErrorResponse<T> value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PiSuccessResponse<T> value)? success,
    TResult? Function(PiErrorResponse<T> value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PiSuccessResponse<T> value)? success,
    TResult Function(PiErrorResponse<T> value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class PiErrorResponse<T extends PiServerResultValue>
    extends PiServerResponse<T> {
  factory PiErrorResponse(
      {required final int statusCode,
      required final dynamic detail,
      required final int id,
      required final String jsonrpc,
      required final PiServerResultError piServerResultError,
      required final double time,
      required final String version,
      required final String versionNumber,
      required final String signature}) = _$PiErrorResponseImpl<T>;
  PiErrorResponse._() : super._();

  @override
  int get statusCode;
  @override
  dynamic get detail;
  @override
  int get id;
  @override
  String get jsonrpc;

  /// This is a throwable error
  PiServerResultError get piServerResultError;
  @override
  double get time;
  @override
  String get version;
  @override
  String get versionNumber;
  @override
  String get signature;
}
