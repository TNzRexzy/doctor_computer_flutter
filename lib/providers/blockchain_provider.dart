import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';

class BlockchainProvider extends ChangeNotifier {
  UserWallet _wallet = UserWallet(userId: 'guest', userName: 'Pengguna Baru');
  bool _isLoading = false;

  UserWallet get wallet => _wallet;
  List<Block> get blockchain => _wallet.blockchain;
  int get totalExp => _wallet.totalExp;
  MemberTier get currentTier => _wallet.currentTier;
  bool get isLoading => _isLoading;

  BlockchainProvider() {
    initWallet('guest', 'Pengguna Baru');
  }

  Future<void> initWallet(String userId, String userName, {bool isAdmin = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (isAdmin) {
        _wallet = UserWallet(
          userId: userId,
          userName: userName,
          totalExp: 999999,
          currentTier: MemberTier.platinum,
        );
        await _saveWallet();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = 'blockchain_wallet_$userId';
      final jsonString = prefs.getString(key);

      if (jsonString != null) {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        _wallet = UserWallet.fromMap(map);
      } else {
        _wallet = UserWallet(userId: userId, userName: userName);
        await _saveWallet();
      }
    } catch (e) {
      debugPrint('Error loading wallet: $e');
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

  void syncWithUser(String userId, String userName, bool isAdmin) {
    if (isAdmin && (_wallet.currentTier != MemberTier.platinum || _wallet.totalExp < 999999)) {
      _wallet = UserWallet(
        userId: userId,
        userName: userName,
        totalExp: 999999,
        currentTier: MemberTier.platinum,
      );
      _saveWallet();
      notifyListeners();
    }
  }

  Future<void> _saveWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'blockchain_wallet_${_wallet.userId}';
      await prefs.setString(key, jsonEncode(_wallet.toMap()));
    } catch (e) {
      debugPrint('Error saving wallet: $e');
    }
  }

  /// Mines Block 1: Minigame reward (+EXP)
  Future<Block> addMinigameReward({
    required String gameTitle,
    required int expEarned,
  }) async {
    final block = _wallet.mineMinigameBlock(
      gameTitle: gameTitle,
      additionalExp: expEarned,
    );
    await _saveWallet();
    notifyListeners();
    return block;
  }

  /// Mines Block 2: Shopping / Belanja Komponen reward (+EXP & potential Tier upgrade)
  Future<Block> addShoppingReward({
    required String itemName,
    required int expEarned,
  }) async {
    final block = _wallet.mineShoppingBlock(
      itemName: itemName,
      additionalExp: expEarned,
    );
    await _saveWallet();
    notifyListeners();
    return block;
  }

  /// Simulates sample Blok 0, Blok 1, Blok 2 from user prompt if empty
  Future<void> seedSampleBlockchainIfNeeded() async {
    if (_wallet.blockchain.length <= 1) {
      // Add Blok 1: Minigames (+100 EXP)
      _wallet.mineMinigameBlock(gameTitle: 'Memory Match Komponen PC', additionalExp: 100);
      // Add Blok 2: Belanja Komponen (+500 EXP -> 600 EXP -> Gold Tier)
      _wallet.mineShoppingBlock(itemName: 'Corsair Vengeance DDR5 32GB RAM', additionalExp: 500);
      await _saveWallet();
      notifyListeners();
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

  /// Admin sets user's EXP and tier directly (creates proper blockchain block)
  Future<bool> adminSetUserPoints({
    required String userId,
    required String userName,
    required int newExp,
    required MemberTier newTier,
    String adminNote = 'Penyesuaian poin oleh admin',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'blockchain_wallet_$userId';
      final jsonString = prefs.getString(key);

      UserWallet targetWallet;
      if (jsonString != null) {
        targetWallet = UserWallet.fromMap(jsonDecode(jsonString) as Map<String, dynamic>);
      } else {
        targetWallet = UserWallet(userId: userId, userName: userName);
      }

      targetWallet.mineAdminAdjustmentBlock(
        newTotalExp: newExp,
        newTier: newTier,
        adminNote: adminNote,
      );

      await prefs.setString(key, jsonEncode(targetWallet.toMap()));

      if (_wallet.userId == userId) {
        _wallet = targetWallet;
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error in adminSetUserPoints: $e');
      return false;
    }
  }
}
