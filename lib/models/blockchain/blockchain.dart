import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Member Tier System
enum MemberTier {
  bronze(value: 0, name: 'Bronze', color: 0xFFCD7F32, discountPercent: 5),
  silver(value: 300, name: 'Silver', color: 0xFFC0C0C0, discountPercent: 10),
  gold(value: 600, name: 'Gold', color: 0xFFFFD700, discountPercent: 15),
  platinum(value: 1200, name: 'Platinum', color: 0xFFE5E4E2, discountPercent: 20);

  final int value;
  final String name;
  final int color;
  final int discountPercent;

  const MemberTier({
    required this.value,
    required this.name,
    required this.color,
    required this.discountPercent,
  });

  MemberTier? getNextTier() {
    switch (this) {
      case bronze:
        return silver;
      case silver:
        return gold;
      case gold:
        return platinum;
      case platinum:
        return null;
    }
  }

  static MemberTier fromExp(int exp) {
    if (exp >= platinum.value) return platinum;
    if (exp >= gold.value) return gold;
    if (exp >= silver.value) return silver;
    return bronze;
  }
}

/// Blockchain Block
class Block {
  final int index;
  final int timestamp;
  final String blockType; // 'genesis', 'minigame', 'shopping', 'admin_adjustment'
  final String title;
  final Map<String, dynamic> data;
  final String previousHash;
  late String hash;
  final int expEarned;
  final String? upgradeTier;

  Block({
    required this.index,
    required this.blockType,
    required this.title,
    required this.data,
    required this.previousHash,
    required String initialHash,
    this.expEarned = 0,
    this.upgradeTier,
    int? customTimestamp,
  }) : timestamp = customTimestamp ?? DateTime.now().millisecondsSinceEpoch {
    hash = initialHash;
  }

  static String calculateHash({
    required int index,
    required int timestamp,
    required Map<String, dynamic> data,
    required String previousHash,
  }) {
    final dataString = jsonEncode(data);
    final input = '$index$timestamp$dataString$previousHash';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Local cache map (SharedPreferences)
  Map<String, dynamic> toMap() => {
        'index': index,
        'timestamp': timestamp,
        'blockType': blockType,
        'title': title,
        'data': data,
        'previousHash': previousHash,
        'hash': hash,
        'expEarned': expEarned,
        'upgradeTier': upgradeTier,
      };

  /// Database-safe map matching Supabase `blockchain_blocks` table schema
  Map<String, dynamic> toDbMap(String userId) => {
        'user_id': userId,
        'block_index': index,
        'block_type': blockType,
        'title': title,
        'data': data,
        'previous_hash': previousHash,
        'hash': hash,
        'exp_earned': expEarned,
        'upgrade_tier': upgradeTier,
        'timestamp': timestamp,
      };

  /// Deserializer supporting both local camelCase cache and Supabase snake_case rows
  factory Block.fromMap(Map<String, dynamic> map) {
    final rawIndex = map['index'] ?? map['block_index'];
    final rawType = map['blockType'] ?? map['block_type'];
    final rawPrevHash = map['previousHash'] ?? map['previous_hash'];
    final rawExp = map['expEarned'] ?? map['exp_earned'];
    final rawTier = map['upgradeTier'] ?? map['upgrade_tier'];
    final rawTimestamp = map['timestamp'];

    return Block(
      index: (rawIndex as num?)?.toInt() ?? 0,
      blockType: rawType as String? ?? 'generic',
      title: map['title'] as String? ?? 'Block #$rawIndex',
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      previousHash: rawPrevHash as String? ?? '0000000000000000',
      initialHash: map['hash'] as String? ?? '',
      expEarned: (rawExp as num?)?.toInt() ?? 0,
      upgradeTier: rawTier as String?,
      customTimestamp: (rawTimestamp as num?)?.toInt(),
    );
  }

  /// Explicit factory from Supabase `blockchain_blocks` table
  factory Block.fromDbMap(Map<String, dynamic> map) => Block.fromMap(map);
}

/// User Wallet and Blockchain state
class UserWallet {
  final String userId;
  final String userName;
  int totalExp;
  MemberTier currentTier;
  final List<Block> blockchain;

  UserWallet({
    required this.userId,
    required this.userName,
    this.totalExp = 0,
    this.currentTier = MemberTier.bronze,
    List<Block>? existingBlocks,
  }) : blockchain = existingBlocks ?? [] {
    if (blockchain.isEmpty) {
      _createGenesisBlock();
    }
  }

  /// Blok 0: Genesis Block pada pengguna baru daftar akun
  /// Data: [User; Exp; Tier] dan Hash: A1B2
  void _createGenesisBlock() {
    final genesisData = {
      'User': userName.isNotEmpty ? userName : userId,
      'Exp': 0,
      'Tier': MemberTier.bronze.name,
      'Note': 'Genesis Block (Akun Baru Terdaftar)',
    };

    final genesisBlock = Block(
      index: 0,
      blockType: 'genesis',
      title: 'Blok 0: Genesis Block',
      data: genesisData,
      previousHash: '0000000000000000',
      initialHash: 'A1B2',
      expEarned: 0,
      upgradeTier: MemberTier.bronze.name,
    );

    blockchain.add(genesisBlock);
    totalExp = 0;
    currentTier = MemberTier.bronze;
  }

  /// Block 1: Minigames
  /// Data: [User; Exp; Tier; Tambahan Exp; Previous Hash; New Hash]
  Block mineMinigameBlock({
    required String gameTitle,
    required int additionalExp,
  }) {
    final previousHash = blockchain.isNotEmpty ? blockchain.last.hash : 'A1B2';
    final newIndex = blockchain.length;
    final newTotalExp = totalExp + additionalExp;
    final oldTier = currentTier;
    final newTier = MemberTier.fromExp(newTotalExp);
    final now = DateTime.now().millisecondsSinceEpoch;

    final blockPayload = {
      'User': userName.isNotEmpty ? userName : userId,
      'Exp': newTotalExp,
      'Tier': newTier.name,
      'Tambahan Exp': '+$additionalExp EXP',
      'Game': gameTitle,
      'Previous Hash': previousHash,
      'Timestamp': DateTime.fromMillisecondsSinceEpoch(now).toIso8601String(),
    };

    final newHash = Block.calculateHash(
      index: newIndex,
      timestamp: now,
      data: blockPayload,
      previousHash: previousHash,
    );

    blockPayload['New Hash'] = newHash;

    final block = Block(
      index: newIndex,
      blockType: 'minigame',
      title: 'Blok $newIndex: Minigame ($gameTitle)',
      data: blockPayload,
      previousHash: previousHash,
      initialHash: newHash,
      expEarned: additionalExp,
      upgradeTier: newTier != oldTier ? newTier.name : null,
      customTimestamp: now,
    );

    blockchain.add(block);
    totalExp = newTotalExp;
    currentTier = newTier;

    return block;
  }

  /// Block 2: Belanja Komponen
  /// Contoh: user belanja RAM dan mendapat +500 EXP. Akumulasi EXP menjadi 600,
  /// dan sistem otomatis menaikkan tier menjadi Gold.
  /// Datanya [User; Tambahan EXP; Upgrade Tier; Previous Hash; New Hash;]
  Block mineShoppingBlock({
    required String itemName,
    required int additionalExp,
  }) {
    final previousHash = blockchain.isNotEmpty ? blockchain.last.hash : 'A1B2';
    final newIndex = blockchain.length;
    final newTotalExp = totalExp + additionalExp;
    final oldTier = currentTier;
    final newTier = MemberTier.fromExp(newTotalExp);
    final now = DateTime.now().millisecondsSinceEpoch;

    final blockPayload = {
      'User': userName.isNotEmpty ? userName : userId,
      'Tambahan EXP': '+$additionalExp EXP',
      'Total EXP': newTotalExp,
      'Upgrade Tier': newTier.name,
      'Item': itemName,
      'Previous Hash': previousHash,
      'Timestamp': DateTime.fromMillisecondsSinceEpoch(now).toIso8601String(),
    };

    final newHash = Block.calculateHash(
      index: newIndex,
      timestamp: now,
      data: blockPayload,
      previousHash: previousHash,
    );

    blockPayload['New Hash'] = newHash;

    final block = Block(
      index: newIndex,
      blockType: 'shopping',
      title: 'Blok $newIndex: Belanja ($itemName)',
      data: blockPayload,
      previousHash: previousHash,
      initialHash: newHash,
      expEarned: additionalExp,
      upgradeTier: newTier != oldTier ? newTier.name : newTier.name,
      customTimestamp: now,
    );

    blockchain.add(block);
    totalExp = newTotalExp;
    currentTier = newTier;

    return block;
  }

  /// Admin adjustment block - safely adjusts EXP and tier via blockchain
  Block mineAdminAdjustmentBlock({
    required int newTotalExp,
    required MemberTier newTier,
    required String adminNote,
  }) {
    final previousHash = blockchain.isNotEmpty ? blockchain.last.hash : 'A1B2';
    final newIndex = blockchain.length;
    final now = DateTime.now().millisecondsSinceEpoch;

    final blockPayload = {
      'User': userName.isNotEmpty ? userName : userId,
      'Penyesuaian': adminNote,
      'EXP Sebelum': totalExp,
      'EXP Sesudah': newTotalExp,
      'Tier Sebelum': currentTier.name,
      'Tier Sesudah': newTier.name,
      'Previous Hash': previousHash,
      'Timestamp': DateTime.fromMillisecondsSinceEpoch(now).toIso8601String(),
    };

    final newHash = Block.calculateHash(
      index: newIndex,
      timestamp: now,
      data: blockPayload,
      previousHash: previousHash,
    );

    blockPayload['New Hash'] = newHash;

    final block = Block(
      index: newIndex,
      blockType: 'admin_adjustment',
      title: 'Blok $newIndex: Penyesuaian Admin',
      data: blockPayload,
      previousHash: previousHash,
      initialHash: newHash,
      expEarned: newTotalExp - totalExp,
      upgradeTier: newTier != currentTier ? newTier.name : null,
      customTimestamp: now,
    );

    blockchain.add(block);
    totalExp = newTotalExp;
    currentTier = newTier;

    return block;
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'totalExp': totalExp,
        'currentTier': currentTier.name,
        'blockchain': blockchain.map((b) => b.toMap()).toList(),
      };

  factory UserWallet.fromMap(Map<String, dynamic> map) {
    final rawBlocks = map['blockchain'] as List? ?? [];
    final blocks = rawBlocks.map((b) => Block.fromMap(Map<String, dynamic>.from(b as Map))).toList();
    
    int blockExp = 0;
    for (final b in blocks) {
      blockExp += b.expEarned;
    }

    final cachedExp = (map['totalExp'] as num?)?.toInt() ?? 0;
    final effectiveExp = blockExp > cachedExp ? blockExp : cachedExp;
    final tier = MemberTier.fromExp(effectiveExp);

    return UserWallet(
      userId: map['userId'] as String? ?? 'guest',
      userName: map['userName'] as String? ?? 'User',
      totalExp: effectiveExp,
      currentTier: tier,
      existingBlocks: blocks,
    );
  }
}
