/*
 * privacyIDEA Authenticator
 *
 * Author: Frank Merkel <frank.merkel@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:mutex/mutex.dart';
import 'package:marty_authenticator/model/extensions/token_list_extension.dart';
import 'package:marty_authenticator/utils/riverpod/riverpod_providers/generated_providers/localization_notifier.dart';
import 'package:marty_authenticator/utils/view_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../interfaces/repo/token_repository.dart';
import '../../../../model/processor_result.dart';
import '../../../../model/riverpod_states/token_state.dart';
import '../../../../model/tokens/hotp_token.dart';
import '../../../../model/tokens/otp_token.dart';
import '../../../../model/tokens/token.dart';
import '../../../../repo/secure_token_repository.dart';
import '../../../globals.dart';
import '../../../lock_auth.dart';
import '../../../logger.dart';
import '../../../utils.dart';
import '../state_providers/status_message_provider.dart';

part 'token_notifier.g.dart';

final tokenProvider = tokenNotifierProviderOf(repo: SecureTokenRepository());

@Riverpod(keepAlive: true)
class TokenNotifier extends _$TokenNotifier with ResultHandler {
  static final Map<String, Timer> _hidingTimers = {};

  /// Lock the repo before any update (e.g. [repo.saveOrReplaceTokens]) and release it after the change is done (await or .then).
  final _repoMutex = Mutex();

  /// Lock the state before accessing it and release it after the change is done.
  final _stateMutex = Mutex();

  TokenNotifier({TokenRepository? repoOverride}) : _repoOverride = repoOverride;

  @override
  TokenRepository get repo => _repoOverride ?? super.repo;
  final TokenRepository? _repoOverride;

  @override
  Future<TokenState> build({required TokenRepository repo}) async {
    await _stateMutex.acquire();
    final newState = await _loadStateFromRepo();
    _stateMutex.release();
    return newState;
  }
  //   /*
  //   /////////////////////////////////////////////////////////////////////////////
  //   /////////////////////// Repository and Token Handling ///////////////////////
  //   /////////////////////////////////////////////////////////////////////////////
  //   /// Repository layer is always use _repoMutex for the latest state
  //   */

  /// Loads the tokens from the repository and returns them as a [TokenState].
  Future<TokenState> _loadStateFromRepo() async {
    await _repoMutex.acquire();
    final tokens = await repo.loadTokens();
    final newState = TokenState(tokens: tokens, lastlyUpdatedTokens: tokens);
    _repoMutex.release();
    return newState;
  }

  /// Adds a token and returns true if successful, false if not.
  /// Updates repo and state.
  Future<bool> _addOrReplaceToken(Token token) async {
    await _repoMutex.acquire();
    final success = await repo.saveOrReplaceToken(token);
    _repoMutex.release();
    await _stateMutex.acquire();
    final currentId = (await future).currentOf(token)?.id;
    if (currentId != null) {
      token = token.copyWith(id: currentId);
    }
    if (!success) {
      Logger.warning('Saving token failed. Token: ${token.id}');
      _stateMutex.release();
      return false;
    }
    state = AsyncValue.data((await future).addOrReplaceToken(token));
    _stateMutex.release();
    return true;
  }

  /// Adds a list of tokens and returns the tokens that could not be added or replaced.
  /// Updates repo and state.
  Future<List<Token>> _addOrReplaceTokens(List<Token> tokens) async {
    await _stateMutex.acquire();
    tokens = [...tokens, ...(await future).tokens].filterDuplicates();
    if (tokens.isEmpty) {
      _stateMutex.release();
      return [];
    }
    Logger.debug('Adding ${tokens.length} tokens.', verbose: true);
    // We set currentState because the map function cant be async
    final currentState = await future;
    tokens = tokens.map((token) {
      final currentId = currentState.currentOf(token)?.id;
      if (currentId != null) return token.copyWith(id: currentId);
      return token;
    }).toList();
    await _repoMutex.acquire();
    final failedTokens = await repo.saveOrReplaceTokens(tokens);
    _repoMutex.release();
    if (failedTokens.isNotEmpty) {
      Logger.warning(
        'Saving tokens failed. Failed Tokens: ${failedTokens.length}',
      );
    }
    // Every token that is saved should not be in the failedTokens list
    final savedTokens = tokens
        .where((element) => !failedTokens.contains(element))
        .toList();
    // Add the saved tokens to the state
    Logger.info('Saved ${savedTokens.length} Tokens to storage.');
    state = AsyncValue.data((await future).addOrReplaceTokens(savedTokens));
    Logger.debug('New State: ${(await future).tokens.length} Tokens');
    _stateMutex.release();
    return [];
  }

  /// Replaces a token if it exists and returns true if successful, false if not.
  /// Updates repo and state.
  Future<bool> _replaceToken(Token token) async {
    await _stateMutex.acquire();
    final (newState, replaced) = (await future).replaceToken(token);
    if (!replaced) {
      Logger.warning('Tried to replace a token that does not exist.');
      _stateMutex.release();
      return false;
    }
    await _repoMutex.acquire();
    final saved = await repo.saveOrReplaceToken(token);
    _repoMutex.release();
    if (!saved) {
      Logger.warning('Saving token failed. Token: ${token.id}');
      _stateMutex.release();
      return false;
    }
    state = AsyncValue.data(newState);
    _stateMutex.release();
    return true;
  }

  /// Returns a list of tokens that could not be replaced
  /// Updates repo and state.
  Future<List<T>> _replaceTokens<T extends Token>(List<T> tokens) async {
    await _stateMutex.acquire();
    final failedToReplace = (await future).replaceTokens(tokens);
    if (failedToReplace.isNotEmpty) {
      Logger.warning('Failed to replace ${failedToReplace.length} tokens');
      _stateMutex.release();
      return failedToReplace;
    }
    tokens = tokens
        .where((element) => !failedToReplace.contains(element))
        .toList();
    await _repoMutex.acquire();
    final failedToSave = await repo.saveOrReplaceTokens<T>(tokens);
    _repoMutex.release();
    if (failedToSave.isNotEmpty) {
      Logger.warning('Failed to save ${failedToSave.length} tokens');
    }
    tokens = tokens
        .where((element) => !failedToSave.contains(element))
        .toList();
    state = AsyncValue.data((await future).addOrReplaceTokens(tokens));
    _stateMutex.release();
    return [];
  }

  /// Removes a token and returns true if successful, false if not.
  Future<bool> _removeToken(Token token) async {
    await _repoMutex.acquire();
    final success = await repo.deleteToken(token);
    _repoMutex.release();
    if (!success) {
      Logger.warning('Deleting token failed. Token: ${token.id}');
      return false;
    }
    await _stateMutex.acquire();
    state = AsyncValue.data((await future).withoutToken(token));
    _stateMutex.release();

    return true;
  }

  /// Removes a list of tokens and returns the tokens that could not be removed.
  Future<List<Token>> _removeTokens(List<Token> tokens) async {
    if (tokens.isEmpty) return [];
    Logger.info('Removing ${tokens.length} tokens.');
    await _repoMutex.acquire();
    final failedTokens = await repo.deleteTokens(tokens);
    _repoMutex.release();
    if (failedTokens.isNotEmpty) {
      Logger.warning(
        'Deleting tokens failed. Failed Tokens: ${failedTokens.length}',
      );
      return failedTokens;
    }
    tokens = tokens
        .where((element) => !failedTokens.contains(element))
        .toList();
    await _stateMutex.acquire();
    state = AsyncValue.data((await future).withoutTokens(tokens));
    _stateMutex.release();

    return [];
  }

  /// Loads the tokens from the repository sets it as the new state and returns the new(await future).
  Future<TokenState> _updateStateFromRepo() async {
    TokenState newState;

    try {
      await _stateMutex.acquire();
      List<Token> tokens;
      await _repoMutex.acquire();
      tokens = await repo.loadTokens();
      _repoMutex.release();
      newState = TokenState(tokens: tokens, lastlyUpdatedTokens: tokens);
      state = AsyncValue.data(newState);
      _stateMutex.release();
    } catch (e) {
      Logger.error('Loading tokens from storage failed.', error: e);
      _stateMutex.release();
      return (await future);
    }

    return newState;
  }

  Future<bool> _saveStateToRepo() async {
    try {
      await _repoMutex.acquire();
      await repo.saveOrReplaceTokens((await future).tokens);
      _repoMutex.release();
    } catch (e) {
      Logger.error('Saving tokens to storage failed.', error: e);
      return false;
    }
    return true;
  }

  /*
  //////////////////////////////////////////////////////////////////////////////
  ///////////////////////// Update Token Methods //////////////////////////////-
  //////////////////////////////////////////////////////////////////////////////
  /// Updating layer: Do not use any mutexes and do not update the state directly.
  /// To update the state use the methods from the repository layer.
  */

  /// Updates a token and returns the updated token if successful, the old token if not and null if the token does not exist.
  Future<T?> _updateToken<T extends Token>(
    T token,
    T Function(T) updater,
  ) async {
    final current = (await future).currentOf<T>(token);
    if (current == null) {
      Logger.warning('Tried to update a token that does not exist.');
      return null;
    }
    final updated = updater(current);
    final replaced = await _replaceToken(updated);
    return replaced ? updated : current;
  }

  /// Updates a list of tokens and returns the updated tokens if successful.
  /// Returns the old tokens if not and an empty list if the tokens does not exist.
  Future<List<T>> _updateTokens<T extends Token>(
    List<T> tokens,
    T Function(T) updater,
  ) async {
    if (tokens.isEmpty) return [];
    List<T> updatedTokens = [];
    for (final token in tokens) {
      final current = (await future).currentOf<T>(token) ?? token;
      updatedTokens.add(updater(current));
    }

    await _replaceTokens(updatedTokens);

    final newState = (await future);
    return newState.tokens
        .whereType<T>()
        .where((stateToken) => tokens.contains(stateToken))
        .toList();
  }

  /*
  //////////////////////////////////////////////////////////////////////////////
  //////////////////////// UI Interaction Methods //////////////////////////////
  /////// These methods are used to interact with the UI and the user. /////////
  //////////////////////////////////////////////////////////////////////////////
  /// There is no need to use mutexes because the updating functions are always using the latest version of the updating tokens.
  */

  /// Adds a new token and returns true if successful, false if not.
  Future<bool> addNewToken(Token token) async {
    return _addOrReplaceToken(token);
  }

  /// Adds new tokens and returns the tokens that could not be added.
  Future<List<Token>> addNewTokens(List<Token> tokens) async {
    return _addOrReplaceTokens(tokens);
  }

  /// Adds or replaces a token and returns true if successful, false if not.
  Future<bool> addOrReplaceToken(Token token) => _addOrReplaceToken(token);

  /// Adds or replaces a list of tokens and returns the tokens that could not be added or replaced.
  Future<List<Token>> addOrReplaceTokens(List<Token> tokens) =>
      _addOrReplaceTokens(tokens);

  /// Updates a token and returns the updated token if successful, the old token if not and null if the token does not exist.
  Future<T?> updateToken<T extends Token>(T token, T Function(T) updater) =>
      _updateToken(token, updater);

  /// Updates a list of tokens and returns the updated tokens if successful, the old tokens if not and an empty list if the tokens does not exist.
  Future<List<T>> updateTokens<T extends Token>(
    List<T> tokens,
    T Function(T) updater,
  ) => _updateTokens(tokens, updater);

  /// Increments the counter of a HOTPToken and returns the updated token if successful, the old token if not and null if the token does not exist.
  Future<HOTPToken?> incrementCounter(HOTPToken token) =>
      _updateToken(token, (p0) => p0.copyWith(counter: token.counter + 1));

  /// Hides a token and returns the updated token ifTok successful, the old token if not and null if the token does not exist.
  Future<T?> hideToken<T extends Token>(T token) =>
      _updateToken(token, (p0) => p0.copyWith(isHidden: true) as T);

  /// Shows a token and returns the updated token if successful, the old token if not and null if the token does not exist or the user is not authenticated.
  Future<T?> showToken<T extends OTPToken>(T token) async {
    final authenticated = await lockAuth(
      localization: ref.read(localizationNotifierProvider),
      reason: (localization) => localization.authenticateToShowOtp,
    );
    if (!authenticated) return null;
    final updated = await _updateToken(
      token,
      (p0) => p0.copyWith(isHidden: false) as T,
    );
    if (updated?.isHidden == false) {
      _hidingTimers[token.id]?.cancel();
      _hidingTimers[token.id] = Timer(token.showDuration, () async {
        await hideToken(token);
      });
    }
    return updated;
  }

  /// Shows a token and returns the updated token if successful, the old token if not and null if the token does not exist or the user is not authenticated.
  Future<OTPToken?> showTokenById(String tokenId) async {
    final token = await getTokenById(tokenId);
    if (token is! OTPToken) {
      Logger.warning('Tried to show a token that is not an OTPToken.');
      return Future.value(null);
    }
    return showToken(token);
  }

  Future<TokenState?> loadStateFromRepo() async {
    try {
      return await _updateStateFromRepo();
    } catch (_) {
      Logger.warning('Loading tokens from storage failed.');
      return null;
    }
  }

  Future<bool> saveStateToRepo() => _saveStateToRepo();

  /// Minimizing the app needs to cancel all timers and save the state to the repository.
  Future<bool> onMinimizeApp() {
    Logger.info('TokenNotifier: Preparing to minimize app.');
    _cancelTimers();
    return hideLockedTokens();
  }

  Future<bool> hideLockedTokens() async {
    final lockedTokens = <Token>[];
    for (var token in (await future).tokens) {
      if (token.isLocked && !token.isHidden) {
        lockedTokens.add(token);
      }
    }
    return (await updateTokens(
          lockedTokens,
          (p0) => p0.copyWith(isHidden: true),
        )).length ==
        lockedTokens.length;
  }

  /// Removes a token from the state and the repository.
  Future<void> removeToken(Token token) async {
    await _removeToken(token);
  }

  /// Removes a list of tokens from the state and the repository.
  Future<void> removeTokens(List<Token> tokens) async {
    Logger.info('Removing ${tokens.length} tokens.');
    await _removeTokens(tokens);
  }

  Future<void> removeTokensBySerials(List<String> serials) async {
    final tokens = (await future).tokens
        .where((token) => serials.contains(token.serial))
        .toList();
    await removeTokens(tokens);
  }

  /// Handles a link and returns true if the link was handled, false if not.
  Future<bool> handleLink(Uri uri) async {
    // Token import via URI is not currently supported
    return false;
  }

  @override
  Future<void> handleProcessorResult(
    ProcessorResult result, {
    Map<String, dynamic> args = const {},
  }) {
    if (result is ProcessorResult<Token>) {
      return handleProcessorResults([result], args: args);
    }
    return Future.value();
  }

  @override
  Future handleProcessorResults(
    List<ProcessorResult> results, {
    Map<String, dynamic> args = const {},
  }) async {
    final List<ProcessorResult<Token>> tokenResults = results
        .whereType<ProcessorResult<Token>>()
        .toList();
    if (tokenResults.isEmpty) return;
    final List<Token> resultTokens = tokenResults.getData();
    addNewTokens(resultTokens);
  }

  Future<T?> getTokenById<T extends Token>(String id) async {
    return (await future).tokens.whereType<T>().firstWhereOrNull(
      (element) => element.id == id,
    );
  }

  void _cancelTimers() {
    for (final key in _hidingTimers.keys) {
      _hidingTimers[key]?.cancel();
    }
    _hidingTimers.clear();
  }
}
