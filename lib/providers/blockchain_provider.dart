import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';

class BlockchainProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
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
      // 1. Try to fetch existing blocks from Supabase if valid user
      if (userId.isNotEmpty && userId != 'guest') {
        try {
          final response = await _supabase
              .from('blockchain_blocks')
              .select()
              .eq('user_id', userId)
              .order('block_index', ascending: true);

          if (response.isNotEmpty) {
            final List<Block> remoteBlocks = response
                .map((item) => Block.fromDbMap(item))
                .toList();

            // Calculate accumulated EXP from remote blocks
            int calculatedExp = 0;
            for (final b in remoteBlocks) {
              calculatedExp += b.expEarned;
            }
            final tier = isAdmin ? MemberTier.platinum : MemberTier.fromExp(calculatedExp);

            _wallet = UserWallet(
              userId: userId,
              userName: userName,
              totalExp: isAdmin ? 999999 : calculatedExp,
              currentTier: tier,
              existingBlocks: remoteBlocks,
            );

            await _saveWalletLocal();
            return;
          }
        } catch (e) {
          debugPrint('[BlockchainProvider] Notice loading blockchain from Supabase: $e');
        }
      }

      // If Admin and had no blocks in Supabase, create initial platinum wallet
      if (isAdmin) {
        _wallet = UserWallet(
          userId: userId,
          userName: userName,
          totalExp: 999999,
          currentTier: MemberTier.platinum,
        );
        await _saveWalletLocal();
        if (_wallet.blockchain.isNotEmpty) {
          await _syncBlockToSupabase(_wallet.blockchain.first);
        }
        return;
      }

      // 2. Fallback to SharedPreferences if Supabase had 0 blocks or was unreachable
      final prefs = await SharedPreferences.getInstance();
      final key = 'blockchain_wallet_$userId';
      final jsonString = prefs.getString(key);

      if (jsonString != null) {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        _wallet = UserWallet.fromMap(map);

        // If user is valid and Supabase had 0 blocks, backfill them to Supabase
        if (userId.isNotEmpty && userId != 'guest' && _wallet.blockchain.isNotEmpty) {
          _syncAllBlocksToSupabase();
        }
      } else {
        _wallet = UserWallet(userId: userId, userName: userName);
        await _saveWalletLocal();

        // Save initial Genesis block to Supabase if valid user
        if (userId.isNotEmpty && userId != 'guest' && _wallet.blockchain.isNotEmpty) {
          await _syncBlockToSupabase(_wallet.blockchain.first);
        }
      }
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

  /// Insert single block into Supabase and update user's EXP / Tier
  Future<void> _syncBlockToSupabase(Block block) async {
    if (_wallet.userId.isEmpty || _wallet.userId == 'guest') {
      debugPrint('[BlockchainProvider] SKIP Supabase sync: user is guest (${_wallet.userId})');
      return;
    }

    try {
      final payload = block.toDbMap(_wallet.userId);
      debugPrint('[BlockchainProvider] Inserting block #${block.index} to Supabase for user ${_wallet.userId}...');
      await _supabase.from('blockchain_blocks').insert(payload);
      debugPrint('[BlockchainProvider] SUCCESS: Block #${block.index} inserted into Supabase!');
    } catch (e) {
      debugPrint('[BlockchainProvider] Supabase blockchain insert ERROR: $e');
    }

    // Note: Supabase database triggers 'sync_user_points_from_blockchain' and
    // 'sync_user_tier_from_blockchain' automatically update public.users (points & membership_tier)
    // with SECURITY DEFINER when a block is inserted. Non-admin users are blocked from updating
    // users table directly by 'guard_privileged_user_columns'.
    debugPrint('[BlockchainProvider] Points and tier will be synced automatically by DB trigger.');
  }

  /// Backfill local blocks to Supabase if they are missing
  Future<void> _syncAllBlocksToSupabase() async {
    if (_wallet.userId.isEmpty || _wallet.userId == 'guest') return;

    try {
      final existing = await _supabase
          .from('blockchain_blocks')
          .select('block_index')
          .eq('user_id', _wallet.userId);

      final existingIndices = <int>{};
      for (final item in existing) {
        if (item['block_index'] != null) {
          existingIndices.add(item['block_index'] as int);
        }
      }

      for (final block in _wallet.blockchain) {
        if (!existingIndices.contains(block.index)) {
          await _supabase.from('blockchain_blocks').insert(block.toDbMap(_wallet.userId));
        }
      }

      // DB trigger automatically updates points & tier upon block insertion
    } catch (e) {
      debugPrint('[BlockchainProvider] Supabase backfill notice: $e');
    }
  }

  /// Mines Block 1: Minigame reward (+EXP)
  Future<Block> addMinigameReward({
    required String gameTitle,
    required int expEarned,
    String? userId,
    String? userName,
  }) async {
    if (userId != null && userId.isNotEmpty && userId != 'guest' && _wallet.userId != userId) {
      await initWallet(userId, userName ?? 'User');
    }
    final block = _wallet.mineMinigameBlock(
      gameTitle: gameTitle,
      additionalExp: expEarned,
    );
    await _saveWalletLocal();
    await _syncBlockToSupabase(block);
    notifyListeners();
    return block;
  }

  /// Mines Block 2: Shopping / Belanja Komponen reward (+EXP & potential Tier upgrade)
  Future<Block> addShoppingReward({
    required String itemName,
    required int expEarned,
    String? userId,
    String? userName,
  }) async {
    if (userId != null && userId.isNotEmpty && userId != 'guest' && _wallet.userId != userId) {
      await initWallet(userId, userName ?? 'User');
    }
    final block = _wallet.mineShoppingBlock(
      itemName: itemName,
      additionalExp: expEarned,
    );
    await _saveWalletLocal();
    await _syncBlockToSupabase(block);
    notifyListeners();
    return block;
  }

  /// Simulates sample Blok 0, Blok 1, Blok 2 from user prompt if empty
  Future<void> seedSampleBlockchainIfNeeded() async {
    if (_wallet.blockchain.length <= 1) {
      final b1 = _wallet.mineMinigameBlock(gameTitle: 'Memory Match Komponen PC', additionalExp: 100);
      await _syncBlockToSupabase(b1);

      final b2 = _wallet.mineShoppingBlock(itemName: 'Corsair Vengeance DDR5 32GB RAM', additionalExp: 500);
      await _syncBlockToSupabase(b2);

      await _saveWalletLocal();
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

      // Sync adjustment block to Supabase
      if (userId.isNotEmpty && userId != 'guest') {
        try {
          await _supabase.from('blockchain_blocks').insert(block.toDbMap(userId));
          await _supabase.from('users').update({
            'points': newExp,
            'membership_tier': newTier.name.toLowerCase(),
          }).eq('id', userId);
        } catch (e) {
          debugPrint('[BlockchainProvider] Notice syncing admin blockchain block to Supabase: $e');
        }
      }

      if (_wallet.userId == userId) {
        _wallet = targetWallet;
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('[BlockchainProvider] Error in adminSetUserPoints: $e');
      return false;
    }
  }
}
