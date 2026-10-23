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

  /// Initializes the user wallet with bidirectional synchronization.
  /// 1. Instantly restores from local cache (offline-first).
  /// 2. Fetches remote blocks from Supabase `blockchain_blocks`.
  /// 3. Reconciles: any unsynced local blocks are pushed to Supabase;
  ///    remote blocks are incorporated into the local chain without data loss.
  /// 4. Synchronizes verified EXP and tier to Supabase `users` table.
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
      if (userId == 'guest' || userId.isEmpty) {
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

      // 1. Instant local restore from SharedPreferences (offline-first)
      final prefs = await SharedPreferences.getInstance();
      final key = 'blockchain_wallet_$userId';
      final jsonString = prefs.getString(key);

      List<Block> localBlocks = [];
      if (jsonString != null && jsonString.isNotEmpty) {
        try {
          final map = jsonDecode(jsonString) as Map<String, dynamic>;
          _wallet = UserWallet.fromMap(map);
          localBlocks = List<Block>.from(_wallet.blockchain);
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
        localBlocks = List<Block>.from(_wallet.blockchain);
        await _saveWallet();
        notifyListeners();
      }

      // 2. Bidirectional sync with Supabase blockchain_blocks table
      try {
        final List res = await supabase
            .from('blockchain_blocks')
            .select()
            .eq('user_id', userId)
            .order('block_index', ascending: true);

        final List<Block> remoteBlocks = res.isNotEmpty
            ? res.map((row) => Block.fromDbMap(row as Map<String, dynamic>)).toList()
            : [];

        // Build index lookup map with remote blocks
        final Map<int, Block> mergedMap = {};
        for (final b in remoteBlocks) {
          mergedMap[b.index] = b;
        }

        // Push any local blocks that are missing from remote Supabase
        for (final lb in localBlocks) {
          if (!mergedMap.containsKey(lb.index)) {
            await _syncBlockToDb(lb, userId);
            mergedMap[lb.index] = lb;
          }
        }

        // Ensure Genesis block (block_index: 0) exists
        if (!mergedMap.containsKey(0)) {
          final genesisWallet = UserWallet(userId: userId, userName: userName);
          final genesisBlock = genesisWallet.blockchain.first;
          await _syncBlockToDb(genesisBlock, userId);
          mergedMap[0] = genesisBlock;
        }

        final sortedIndices = mergedMap.keys.toList()..sort();
        final List<Block> finalBlocks = sortedIndices.map((i) => mergedMap[i]!).toList();

        int accumulatedExp = 0;
        for (final b in finalBlocks) {
          accumulatedExp += b.expEarned;
        }

        // Reconcile: If initial points in users table exceed blockchain sum (e.g. legacy/admin seed),
        // mine a reconciliation block so the blockchain ledger perfectly matches.
        final targetPoints = initialExp > accumulatedExp ? initialExp : accumulatedExp;
        if (targetPoints > accumulatedExp && !isAdmin) {
          final diff = targetPoints - accumulatedExp;
          final prevHash = finalBlocks.isNotEmpty ? finalBlocks.last.hash : 'A1B2';
          final newIndex = finalBlocks.length;
          final now = DateTime.now().millisecondsSinceEpoch;
          final blockPayload = {
            'User': userName.isNotEmpty ? userName : userId,
            'Exp': targetPoints,
            'Tier': MemberTier.fromExp(targetPoints).name,
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
          blockPayload['New Hash'] = newHash;
          final recoveryBlock = Block(
            index: newIndex,
            blockType: 'shopping',
            title: 'Blok $newIndex: Sinkronisasi Akumulasi Poin',
            data: blockPayload,
            previousHash: prevHash,
            initialHash: newHash,
            expEarned: diff,
            upgradeTier: MemberTier.fromExp(targetPoints).name,
            customTimestamp: now,
          );
          await _syncBlockToDb(recoveryBlock, userId);
          finalBlocks.add(recoveryBlock);
          accumulatedExp = targetPoints;
        }

        final effectiveExp = isAdmin ? (accumulatedExp < 999999 ? 999999 : accumulatedExp) : accumulatedExp;
        final calculatedTier = isAdmin ? MemberTier.platinum : MemberTier.fromExp(effectiveExp);

        _wallet = UserWallet(
          userId: userId,
          userName: userName,
          totalExp: effectiveExp,
          currentTier: calculatedTier,
          existingBlocks: finalBlocks,
        );

        await _saveWallet();
        notifyListeners();

        // 3. Synchronize points and tier directly to `users` table
        try {
          await supabase.from('users').update({
            'points': effectiveExp,
            'membership_tier': calculatedTier.name.toLowerCase(),
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);
        } catch (e) {
          debugPrint('Notice updating users table from initWallet: $e');
        }

        onWalletSynced?.call(effectiveExp, calculatedTier.name);
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
        existingBlocks: _wallet.blockchain,
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

  /// Persists a mined block to Supabase `blockchain_blocks` table and updates `users` table
  Future<bool> _syncBlockToDb(Block block, String userId) async {
    if (userId == 'guest' || userId.isEmpty) return false;

    bool synced = false;
    // 1. Try insert first (standard for newly mined blocks)
    try {
      await supabase.from('blockchain_blocks').insert(block.toDbMap(userId));
      synced = true;
      debugPrint('[Blockchain] Mined block #${block.index} (${block.blockType}) inserted into Supabase.');
    } catch (insertError) {
      // If insert fails (e.g. duplicate key), fallback to upsert
      try {
        await supabase.from('blockchain_blocks').upsert(
              block.toDbMap(userId),
              onConflict: 'user_id,block_index',
            );
        synced = true;
        debugPrint('[Blockchain] Mined block #${block.index} (${block.blockType}) upserted into Supabase.');
      } catch (upsertError) {
        debugPrint('[Blockchain] Notice syncing block #${block.index} to Supabase: $upsertError');
      }
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

    return synced;
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

    // Persist and sync to Supabase
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

    // Persist and sync to Supabase
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
      // Fetch latest blocks from Supabase for target user to maintain cryptographic chain
      List<Block> targetBlocks = [];
      try {
        final List res = await supabase
            .from('blockchain_blocks')
            .select()
            .eq('user_id', userId)
            .order('block_index', ascending: true);
        if (res.isNotEmpty) {
          targetBlocks = res.map((r) => Block.fromDbMap(r as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('Notice fetching remote blocks for admin adjustment: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      final key = 'blockchain_wallet_$userId';
      final jsonString = prefs.getString(key);

      UserWallet targetWallet;
      if (targetBlocks.isNotEmpty) {
        int currentExp = 0;
        for (final b in targetBlocks) {
          currentExp += b.expEarned;
        }
        targetWallet = UserWallet(
          userId: userId,
          userName: userName,
          totalExp: currentExp,
          currentTier: MemberTier.fromExp(currentExp),
          existingBlocks: targetBlocks,
        );
      } else if (jsonString != null) {
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

      // Also ensure users table is updated
      try {
        await supabase.from('users').update({
          'points': newExp,
          'membership_tier': newTier.name.toLowerCase(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error in adminSetUserPoints: $e');
      return false;
    }
  }
}
