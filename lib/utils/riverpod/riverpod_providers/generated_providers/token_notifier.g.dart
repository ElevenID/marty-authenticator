// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tokenNotifierHash() => r'5655030440e74e9ab14ab5a1a809750d85938ece';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$TokenNotifier extends BuildlessAsyncNotifier<TokenState> {
  late final TokenRepository repo;

  FutureOr<TokenState> build({required TokenRepository repo});
}

/// See also [TokenNotifier].
@ProviderFor(TokenNotifier)
const tokenNotifierProviderOf = TokenNotifierFamily();

/// See also [TokenNotifier].
class TokenNotifierFamily extends Family<AsyncValue<TokenState>> {
  /// See also [TokenNotifier].
  const TokenNotifierFamily();

  /// See also [TokenNotifier].
  TokenNotifierProvider call({required TokenRepository repo}) {
    return TokenNotifierProvider(repo: repo);
  }

  @override
  TokenNotifierProvider getProviderOverride(
    covariant TokenNotifierProvider provider,
  ) {
    return call(repo: provider.repo);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'tokenNotifierProviderOf';
}

/// See also [TokenNotifier].
class TokenNotifierProvider
    extends AsyncNotifierProviderImpl<TokenNotifier, TokenState> {
  /// See also [TokenNotifier].
  TokenNotifierProvider({required TokenRepository repo})
    : this._internal(
        () => TokenNotifier()..repo = repo,
        from: tokenNotifierProviderOf,
        name: r'tokenNotifierProviderOf',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$tokenNotifierHash,
        dependencies: TokenNotifierFamily._dependencies,
        allTransitiveDependencies:
            TokenNotifierFamily._allTransitiveDependencies,
        repo: repo,
      );

  TokenNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.repo,
  }) : super.internal();

  final TokenRepository repo;

  @override
  FutureOr<TokenState> runNotifierBuild(covariant TokenNotifier notifier) {
    return notifier.build(repo: repo);
  }

  @override
  Override overrideWith(TokenNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: TokenNotifierProvider._internal(
        () => create()..repo = repo,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        repo: repo,
      ),
    );
  }

  @override
  AsyncNotifierProviderElement<TokenNotifier, TokenState> createElement() {
    return _TokenNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TokenNotifierProvider && other.repo == repo;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, repo.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin TokenNotifierRef on AsyncNotifierProviderRef<TokenState> {
  /// The parameter `repo` of this provider.
  TokenRepository get repo;
}

class _TokenNotifierProviderElement
    extends AsyncNotifierProviderElement<TokenNotifier, TokenState>
    with TokenNotifierRef {
  _TokenNotifierProviderElement(super.provider);

  @override
  TokenRepository get repo => (origin as TokenNotifierProvider).repo;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
