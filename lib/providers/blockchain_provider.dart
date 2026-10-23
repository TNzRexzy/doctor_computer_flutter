import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlockchainProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  UserWallet _wallet = UserWallet(userId: 'guest', userName: 'Pengguna Baru');
  bool _isLoading = false;
  void Function(int exp, String tierName)? onWalletSynced;

  UserWallet get wallet => _wallet;
  List<Block> get blockchain => _wallet.blockchain;
  int get totalExp => _wallet.totalExp;
  MemberTier get currentTier => _wallet.currentTier;
  bool get isLoading => _isLoading;

  BlockchainProvider() {
    initWallet('guest', 'Pengguna Baru');
  }

  /// Initializes the user wallet.
  /// First restores instantly from local SharedPreferences cache (offline-first),
  /// then synchronizes asynchronously with Supabase `blockchain_blocks` table.
  Future<void> initWallet(
    String userId, 
    String userName, {
    bool isAdmin = false,
    int initialExp = 0,
    String? initialTierName,
  }) async {
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
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (userId == 'guest') {
        _wallet = UserWallet(
          userId: 'guest',
          userName: 'Pengguna Baru',
          totalExp: 0,
          currentTier: MemberTier.bronze,
        );
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 1. Instant local restore from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final key = 'blockchain_wallet_$userId';
      final jsonString = prefs.getString(key);

      if (jsonString != null && jsonString.isNotEmpty) {
        try {
          final map = jsonDecode(jsonString) as Map<String, dynamic>;
          _wallet = UserWallet.fromMap(map);
          if (initialExp > _wallet.totalExp) {
            _wallet.totalExp = initialExp;
            _wallet.currentTier = MemberTier.fromExp(initialExp);
          }
          notifyListeners();
        } catch (e) {
          debugPrint('Error decoding local blockchain wallet: $e');
        }
      } else {
        _wallet = UserWallet(
          userId: userId,
          userName: userName,
          totalExp: initialExp,
          currentTier: MemberTier.fromExp(initialExp),
        );
        await _saveWallet();
        notifyListeners();
      }

      // 2. Sync with Supabase blockchain_blocks table
      try {
        final List res = await supabase
            .from('blockchain_blocks')
            .select()
            .eq('user_id', userId)
            .order('block_index', ascending: true);

        if (res.isNotEmpty) {
          final List<Block> remoteBlocks = res
              .map((row) => Block.fromDbMap(row as Map<String, dynamic>))
              .toList();

          int accumulatedExp = 0;
          for (final b in remoteBlocks) {
            accumulatedExp += b.expEarned;
          }

          if (initialExp > accumulatedExp) {
            final diff = initialExp - accumulatedExp;
            final prevHash = remoteBlocks.isNotEmpty ? remoteBlocks.last.hash : 'A1B2';
            final newIndex = remoteBlocks.length;
            final now = DateTime.now().millisecondsSinceEpoch;
            final blockPayload = {
              'User': userName,
              'Exp': initialExp,
              'Tier': MemberTier.fromExp(initialExp).name,
              'Tambahan Exp': '+$diff EXP',
              'Note': 'Sinkronisasi riwayat akumulasi EXP akun',
              'Previous Hash': prevHash,
              'Timestamp': DateTime.fromMillisecondsSinceEpoch(now).toIso8601String(),
            };
            final newHash = Block.calculateHash(
              index: newIndex,
              timestamp: now,
              data: blockPayload,
              previousHash: prevHash,
            );
            final recoveryBlock = Block(
              index: newIndex,
              blockType: 'shopping',
              title: 'Blok $newIndex: Sinkronisasi Akumulasi Poin',
              data: blockPayload,
              previousHash: prevHash,
              initialHash: newHash,
              expEarned: diff,
              upgradeTier: MemberTier.fromExp(initialExp).name,
              customTimestamp: now,
            );
            try {
              await supabase.from('blockchain_blocks').upsert(
                recoveryBlock.toDbMap(userId),
                onConflict: 'user_id,block_index',
              );
              remoteBlocks.add(recoveryBlock);
              accumulatedExp = initialExp;
            } catch (e) {
              debugPrint('Error inserting recovery block: $e');
            }
          }

          final calculatedTier = MemberTier.fromExp(accumulatedExp);

          _wallet = UserWallet(
            userId: userId,
            userName: userName,
            totalExp: accumulatedExp,
            currentTier: calculatedTier,
            existingBlocks: remoteBlocks,
          );

          await _saveWallet();
          notifyListeners();
          onWalletSynced?.call(accumulatedExp, calculatedTier.name);
        } else {
          if (_wallet.blockchain.isEmpty) {
            _wallet = UserWallet(
              userId: userId,
              userName: userName,
              totalExp: initialExp,
              currentTier: MemberTier.fromExp(initialExp),
            );
          }

          if (initialExp > 0 && _wallet.blockchain.length <= 1) {
            final b = _wallet.mineShoppingBlock(
              itemName: 'Akumulasi Poin Akun Member',
              additionalExp: initialExp,
            );
            await _syncBlockToDb(b, userId);
          } else {
            for (final block in _wallet.blockchain) {
              await _syncBlockToDb(block, userId);
            }
          }

          await _saveWallet();
          notifyListeners();
          onWalletSynced?.call(_wallet.totalExp, _wallet.currentTier.name);
        }
      } catch (e) {
        debugPrint('Notice syncing blockchain from Supabase: $e');
      }
    } catch (e) {
      debugPrint('Error initializing wallet: $e');
      final fallbackExp = isAdmin ? 999999 : initialExp;
      _wallet = UserWallet(
        userId: userId,
        userName: userName,
        totalExp: fallbackExp,
        currentTier: MemberTier.fromExp(fallbackExp),
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

  /// Refresh wallet from Supabase
  Future<void> refresh() async {
    await initWallet(
      _wallet.userId,
      _wallet.userName,
      isAdmin: _wallet.currentTier == MemberTier.platinum && _wallet.totalExp >= 999999,
    );
  }

  Future<void> _saveWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'blockchain_wallet_${_wallet.userId}';
      await prefs.setString(key, jsonEncode(_wallet.toMap()));
    } catch (e) {
      debugPrint('Error saving wallet to cache: $e');
    }
  }

  /// Persists a mined block to Supabase `blockchain_blocks` table with onConflict handling
  Future<void> _syncBlockToDb(Block block, String userId) async {
    if (userId == 'guest' || userId.isEmpty) return;

    // 1. Upsert block to blockchain_blocks table
    try {
      await supabase.from('blockchain_blocks').upsert(
            block.toDbMap(userId),
            onConflict: 'user_id,block_index',
          );
      debugPrint('[Blockchain] Mined block #${block.index} (${block.blockType}) synced to Supabase.');
    } catch (e) {
      debugPrint('[Blockchain] Notice syncing block #${block.index} to Supabase: $e');
    }

    // 2. Synchronize points and tier directly to `users` table in Supabase
    try {
      final tierStr = _wallet.currentTier.name.toLowerCase();
      await supabase.from('users').update({
        'points': _wallet.totalExp,
        'membership_tier': tierStr,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      debugPrint('[Blockchain] Synced ${_wallet.totalExp} points and $tierStr tier to users table.');
    } catch (e) {
      debugPrint('Notice updating users table from blockchain: $e');
    }

    // 3. Notify listener callback (e.g. AuthProvider)
    onWalletSynced?.call(_wallet.totalExp, _wallet.currentTier.name);
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

    // Sync to Supabase
    await _syncBlockToDb(block, _wallet.userId);

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

    // Sync to Supabase
    await _syncBlockToDb(block, _wallet.userId);

    return block;
  }

  /// Simulates sample Blok 0, Blok 1, Blok 2 from user prompt if empty
  Future<void> seedSampleBlockchainIfNeeded() async {
    if (_wallet.blockchain.length <= 1) {
      // Add Blok 1: Minigames (+100 EXP)
      final b1 = _wallet.mineMinigameBlock(gameTitle: 'Memory Match Komponen PC', additionalExp: 100);
      await _syncBlockToDb(b1, _wallet.userId);

      // Add Blok 2: Belanja Komponen (+500 EXP -> 600 EXP -> Gold Tier)
      final b2 = _wallet.mineShoppingBlock(itemName: 'Corsair Vengeance DDR5 32GB RAM', additionalExp: 500);
      await _syncBlockToDb(b2, _wallet.userId);

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

      final block = targetWallet.mineAdminAdjustmentBlock(
        newTotalExp: newExp,
        newTier: newTier,
        adminNote: adminNote,
      );

      await prefs.setString(key, jsonEncode(targetWallet.toMap()));

      if (_wallet.userId == userId) {
        _wallet = targetWallet;
        notifyListeners();
      }

      // Sync the adjustment block to Supabase
      await _syncBlockToDb(block, userId);

      return true;
    } catch (e) {
      debugPrint('Error in adminSetUserPoints: $e');
      return false;
    }
  }
}
