import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';

class BlockchainProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  UserWallet _wallet = UserWallet(userId: 'guest', userName: 'Pengguna Baru');
  bool _isLoading = false;
  bool _isAdminWallet = false;

  UserWallet get wallet => _wallet;
  List<Block> get blockchain => _wallet.blockchain;
  int get totalExp => _wallet.totalExp;
  MemberTier get currentTier => _wallet.currentTier;
  bool get isLoading => _isLoading;

  BlockchainProvider() {
    initWallet('guest', 'Pengguna Baru');
  }

  Future<void> initWallet(
    String userId,
    String userName, {
    bool isAdmin = false,
  }) async {
    _isLoading = true;
    _isAdminWallet = isAdmin;
    notifyListeners();

    try {
      var serverPoints = 0;
      List<Block>? remoteBlocks;
      if (userId.isNotEmpty && userId != 'guest') {
        try {
          final profile = await _supabase
              .from('users')
              .select('points')
              .eq('id', userId)
              .limit(1);
          if (profile.isNotEmpty) {
            serverPoints = (profile.first['points'] as num? ?? 0).toInt();
          }
        } catch (e) {
          debugPrint(
            '[BlockchainProvider] Could not load authoritative points: $e',
          );
        }

        try {
          final response = await _supabase
              .from('blockchain_blocks')
              .select()
              .eq('user_id', userId)
              .order('block_index', ascending: true);
          if (response.isNotEmpty) {
            remoteBlocks = response
                .map((item) => Block.fromDbMap(item))
                .toList();
          }
        } catch (e) {
          debugPrint(
            '[BlockchainProvider] Notice loading blockchain from Supabase: $e',
          );
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final key = 'blockchain_wallet_$userId';
      final jsonString = prefs.getString(key);

      if (remoteBlocks != null) {
        _wallet = UserWallet(
          userId: userId,
          userName: userName,
          existingBlocks: remoteBlocks,
        );
      } else if (jsonString != null) {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        _wallet = UserWallet.fromMap(map);
      } else {
        _wallet = UserWallet(userId: userId, userName: userName);
      }

      _wallet.totalExp = isAdmin ? 999999 : serverPoints;
      _wallet.currentTier = isAdmin
          ? MemberTier.platinum
          : MemberTier.fromExp(serverPoints);
      await _saveWalletLocal();
    } catch (e) {
      debugPrint('[BlockchainProvider] Error loading wallet: $e');
      _wallet = UserWallet(
        userId: userId,
        userName: userName,
        totalExp: isAdmin ? 999999 : 0,
        currentTier: isAdmin ? MemberTier.platinum : MemberTier.bronze,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reloads points and ledger blocks from Supabase for the current user.
  Future<void> refreshWallet() async {
    if (_wallet.userId.isEmpty || _wallet.userId == 'guest') return;
    await initWallet(
      _wallet.userId,
      _wallet.userName,
      isAdmin: _isAdminWallet,
    );
  }

  /// Asks the server to award EXP for a finished minigame. The server decides the
  /// amount (fixed per game, cooldown, daily cap) and writes the ledger block.
  /// Returns the server response: `awarded_exp`, `reason`, `total_points`, `tier`.
  Future<Map<String, dynamic>> awardMinigameExp({
    required String game,
    Map<String, dynamic> result = const {},
  }) async {
    if (_wallet.userId == 'guest') {
      return {'awarded_exp': 0, 'reason': 'not_logged_in'};
    }
    try {
      final response = await _supabase.rpc(
        'award_minigame_exp',
        params: {'p_game': game, 'p_result': result},
      );
      final map = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{'awarded_exp': 0, 'reason': 'invalid_response'};
      await refreshWallet();
      return map;
    } catch (e) {
      debugPrint('[BlockchainProvider] award_minigame_exp failed: $e');
      return {'awarded_exp': 0, 'reason': 'error', 'message': e.toString()};
    }
  }

  /// Human readable text for the result of [awardMinigameExp].
  static String describeAward(Map<String, dynamic> award) {
    final exp = (award['awarded_exp'] as num?)?.toInt() ?? 0;
    if (exp > 0) {
      final upgraded = award['tier_upgraded'] == true
          ? ' Tier naik ke ${award['tier']}!'
          : '';
      return '+$exp EXP tersimpan ke database.$upgraded';
    }
    switch (award['reason']) {
      case 'cooldown':
        return 'EXP belum bertambah: tunggu sebentar sebelum memainkan game ini lagi.';
      case 'daily_cap':
        return 'Batas EXP minigame hari ini sudah tercapai. Coba lagi besok.';
      case 'not_passed':
        return 'Skor belum cukup untuk mendapat EXP.';
      case 'not_logged_in':
        return 'Login dulu agar EXP bisa tersimpan.';
      default:
        return 'EXP gagal disimpan ke database. Pastikan migrasi 20261026 sudah dijalankan.';
    }
  }

  void syncWithUser(String userId, String userName, bool isAdmin) {
    if (isAdmin) {
      bool changed = false;
      if (_wallet.currentTier != MemberTier.platinum) {
        _wallet.currentTier = MemberTier.platinum;
        changed = true;
      }
      if (_wallet.totalExp < 999999) {
        _wallet.totalExp = 999999;
        changed = true;
      }
      if (changed) {
        _saveWalletLocal();
        notifyListeners();
      }
    }
  }

  Future<void> _saveWalletLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'blockchain_wallet_${_wallet.userId}';
      await prefs.setString(key, jsonEncode(_wallet.toMap()));
    } catch (e) {
      debugPrint('[BlockchainProvider] Error saving wallet locally: $e');
    }
  }

  /// Verify chain cryptographic integrity
  bool verifyChain() {
    for (int i = 1; i < _wallet.blockchain.length; i++) {
      final current = _wallet.blockchain[i];
      final previous = _wallet.blockchain[i - 1];

      if (current.previousHash != previous.hash) {
        return false;
      }
    }
    return true;
  }
}
