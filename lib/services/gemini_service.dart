import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  /// Generate AI reply for Customer Service Chat
  Future<String> getCustomerServiceResponse(
    String userQuery,
    List<Map<String, String>> history,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'gemini-chat',
        body: {'query': userQuery, 'history': history},
      );
      if (response.status == 200 && response.data is Map) {
        final text = (response.data as Map)['text'];
        if (text is String && text.isNotEmpty) return text;
      }
      debugPrint('Gemini Edge Function returned an unexpected response.');
    } catch (e) {
      debugPrint(
        'Gemini Edge Function request failed; using local fallback: $e',
      );
    }

    // Smart Domain Expert Fallback Engine
    return _generateFallbackCustomerService(userQuery);
  }

  /// AI-powered Smart Search
  Future<Map<String, dynamic>> searchWithAI({
    required String query,
    required List<ProductModel> catalog,
  }) async {
    final lower = query.toLowerCase().trim();
    List<ProductModel> matches = [];
    String explanation = '';

    // Step 1: Exact category match first
    final categoryKeywords = {
      'ssd': 'storage',
      'hdd': 'storage',
      'nvme': 'storage',
      'laptop': 'laptop',
      'monitor': 'monitor',
      'keyboard': 'keyboard',
      'mouse': 'mouse',
      'headset': 'headset',
      'router': 'networking',
      'wifi': 'networking',
      'desktop': 'desktop',
    };

    String? matchedCategory;
    for (final entry in categoryKeywords.entries) {
      if (lower.contains(entry.key)) {
        matchedCategory = entry.value;
        break;
      }
    }

    if (matchedCategory != null) {
      // Filter by category FIRST, then by query relevance
      matches = catalog.where((p) {
        return p.categoryId.toLowerCase() == matchedCategory;
      }).toList();

      // Further filter by query terms within that category
      final queryTerms = lower.split(' ').where((t) => t.length > 2).toList();
      if (queryTerms.length > 1) {
        final refined = matches.where((p) {
          final searchable = '${p.name} ${p.brand} ${p.description}'
              .toLowerCase();
          return queryTerms.any((term) => searchable.contains(term));
        }).toList();
        if (refined.isNotEmpty) matches = refined;
      }

      explanation =
          'Menampilkan produk kategori ${matchedCategory.toUpperCase()} yang sesuai dengan pencarian "$query".';
    } else if (lower.contains('gaming') ||
        lower.contains('game') ||
        lower.contains('rtx') ||
        lower.contains('fps')) {
      // Gaming intent - but be smarter
      matches = catalog.where((p) {
        final n = p.name.toLowerCase();
        final cat = p.categoryId.toLowerCase();
        return n.contains('gaming') ||
            n.contains('rtx') ||
            cat == 'laptop' &&
                (n.contains('tuf') ||
                    n.contains('rog') ||
                    n.contains('legion') ||
                    n.contains('katana'));
      }).toList();
      explanation =
          'Rekomendasi produk gaming berdasarkan analisis kebutuhan Anda.';
    } else if (lower.contains('budget') ||
        lower.contains('murah') ||
        lower.contains('terjangkau')) {
      final sorted = List<ProductModel>.from(catalog)
        ..sort((a, b) => a.price.compareTo(b.price));
      matches = sorted.take(6).toList();
      explanation =
          'Produk dengan harga terjangkau untuk memaksimalkan anggaran Anda.';
    } else {
      // General search: match name, brand, description
      matches = catalog.where((p) {
        final searchable = '${p.name} ${p.brand}'.toLowerCase();
        return searchable.contains(lower);
      }).toList();

      if (matches.isEmpty) {
        // Try partial matching
        final terms = lower.split(' ').where((t) => t.length > 2);
        matches = catalog.where((p) {
          final searchable = '${p.name} ${p.brand} ${p.description}'
              .toLowerCase();
          return terms.any((term) => searchable.contains(term));
        }).toList();
      }
      explanation = matches.isEmpty
          ? 'Tidak ditemukan produk yang cocok dengan "$query". Coba kata kunci lain.'
          : 'Hasil pencarian untuk "$query".';
    }

    return {'explanation': explanation, 'recommendations': matches};
  }

  /// AI Bottleneck Calculator
  Map<String, dynamic> calculateBottleneck({
    required PcPartModel? cpu,
    required PcPartModel? gpu,
    PcPartModel? ram,
  }) {
    if (cpu == null || gpu == null) {
      return {
        'bottleneckPercentage': 0,
        'type': 'incomplete',
        'status': 'Pilih CPU dan GPU terlebih dahulu',
        'advice': 'Kombinasi CPU dan GPU diperlukan untuk menghitung persentase bottleneck.',
        'gamingFps': <String, String>{},
      };
    }

    // Estimate relative tiers (1 - 10)
    int cpuTier = _getCpuTier(cpu.name);
    int gpuTier = _getGpuTier(gpu.name);

    int diff = cpuTier - gpuTier;
    int percentage = 0;
    String type = 'balanced';
    String status = 'Sangat Seimbang (Optimal)';
    String advice =
        'Kombinasi prosesor dan kartu grafis sangat harmonis. Tidak terjadi pemborosan performa.';
    Color color = Colors.green;

    if (diff < -2) {
      // CPU is much weaker than GPU
      percentage = (20 + (diff.abs() * 5)).clamp(15, 38);
      type = 'cpu_bottleneck';
      status = 'CPU Bottleneck ($percentage%)';
      color = Colors.red;
      advice =
          'CPU Anda (${cpu.name}) terlalu lemah untuk mengimbangi daya kartu grafis ${gpu.name}. GPU tidak akan mencapai utilisasi 100%. Disarankan upgrade prosesor ke seri yang lebih tinggi.';
    } else if (diff > 2) {
      // GPU is weaker than CPU
      percentage = (15 + (diff * 4)).clamp(12, 30);
      type = 'gpu_bottleneck';
      status = 'GPU Bottleneck ($percentage%)';
      color = Colors.orange;
      advice =
          'Kartu grafis Anda (${gpu.name}) menjadi batas performa game dibandingkan kemampuan prosesor ${cpu.name}. Untuk gaming resolusi 1440p/4K, disarankan upgrade GPU.';
    } else {
      percentage = (diff.abs() * 3 + 4).clamp(3, 9);
      type = 'balanced';
      status = 'Optimal ($percentage% Bottleneck)';
      color = Colors.green;
      advice =
          'Kombinasi ${cpu.name} & ${gpu.name} bekerja sempurna dengan efisiensi maksimal tanpa hambatan signifikan.';
    }

    // Gaming FPS Estimates based on realistic database
    Map<String, String> fpsEstimates = {};
    final fpsDb = _fpsDatabase();
    for (final entry in fpsDb.entries) {
      final gameName = entry.key;
      final tiers = entry.value;
      // Use GPU tier for GPU-bound games, CPU tier for CPU-bound (Valorant, CS2)
      final isGpuBound =
          !gameName.contains('Valorant') && !gameName.contains('CS2');
      final tier = isGpuBound ? gpuTier : cpuTier;
      final fps = tiers[tier.clamp(1, 10)] ?? tiers[5]!;
      // Apply bottleneck penalty
      final penalizedFps = (fps * (1 - percentage / 100)).round();
      fpsEstimates[gameName] = '$penalizedFps FPS';
    }

    return {
      'bottleneckPercentage': percentage,
      'type': type,
      'status': status,
      'advice': advice,
      'color': color,
      'gamingFps': fpsEstimates,
      'recommendedResolution': gpuTier >= 7
          ? '1440p / 4K Gaming'
          : (gpuTier >= 4 ? '1080p / 1440p Gaming' : '1080p Esports'),
    };
  }

  Map<String, Map<int, int>> _fpsDatabase() {
    // tier -> {game: fps}
    return {
      // GPU-bound games at 1080p Ultra
      'Cyberpunk 2077 (1080p Ultra)': {
        1: 20,
        2: 28,
        3: 35,
        4: 45,
        5: 55,
        6: 65,
        7: 80,
        8: 95,
        9: 110,
        10: 130,
      },
      'Cyberpunk 2077 (1440p Ultra)': {
        1: 15,
        2: 20,
        3: 25,
        4: 32,
        5: 42,
        6: 52,
        7: 65,
        8: 78,
        9: 90,
        10: 110,
      },
      'Red Dead Redemption 2 (1080p Ultra)': {
        1: 25,
        2: 32,
        3: 40,
        4: 50,
        5: 60,
        6: 72,
        7: 88,
        8: 100,
        9: 115,
        10: 135,
      },
      'Valorant (1080p High)': {
        1: 120,
        2: 160,
        3: 200,
        4: 250,
        5: 300,
        6: 350,
        7: 400,
        8: 450,
        9: 500,
        10: 550,
      },
      'GTA V (1080p Very High)': {
        1: 40,
        2: 55,
        3: 65,
        4: 80,
        5: 95,
        6: 110,
        7: 130,
        8: 150,
        9: 165,
        10: 180,
      },
      'Black Myth Wukong (1080p High)': {
        1: 18,
        2: 24,
        3: 30,
        4: 38,
        5: 48,
        6: 58,
        7: 70,
        8: 82,
        9: 95,
        10: 110,
      },
      'Forza Horizon 5 (1080p Ultra)': {
        1: 35,
        2: 45,
        3: 55,
        4: 68,
        5: 80,
        6: 95,
        7: 110,
        8: 128,
        9: 145,
        10: 165,
      },
      'CS2 (1080p High)': {
        1: 100,
        2: 140,
        3: 180,
        4: 220,
        5: 270,
        6: 310,
        7: 360,
        8: 400,
        9: 440,
        10: 500,
      },
    };
  }

  int _getCpuTier(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('i9') ||
        lower.contains('7900') ||
        lower.contains('7950') ||
        lower.contains('9950'))
      return 10;
    if (lower.contains('7800x3d') ||
        lower.contains('9800x3d') ||
        lower.contains('i7-14700') ||
        lower.contains('i7-13700'))
      return 9;
    if (lower.contains('i7') ||
        lower.contains('7700') ||
        lower.contains('9700'))
      return 8;
    if (lower.contains('i5-14600') ||
        lower.contains('i5-13600') ||
        lower.contains('7600x') ||
        lower.contains('9600x'))
      return 7;
    if (lower.contains('i5-14400') ||
        lower.contains('i5-13400') ||
        lower.contains('7600'))
      return 6;
    if (lower.contains('i5') ||
        lower.contains('ryzen 5') ||
        lower.contains('5600'))
      return 5;
    if (lower.contains('i3-14100') ||
        lower.contains('i3-13100') ||
        lower.contains('i3-12100'))
      return 4;
    if (lower.contains('i3') ||
        lower.contains('ryzen 3') ||
        lower.contains('4100'))
      return 3;
    return 5;
  }

  int _getGpuTier(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('4090')) return 10;
    if (lower.contains('4080') || lower.contains('7900 xtx')) return 9;
    if (lower.contains('4070 ti') || lower.contains('7900 xt')) return 8;
    if (lower.contains('4070') || lower.contains('7800 xt')) return 7;
    if (lower.contains('4060 ti') ||
        lower.contains('7700 xt') ||
        lower.contains('6750 xt'))
      return 6;
    if (lower.contains('4060') ||
        lower.contains('7600') ||
        lower.contains('6700 xt'))
      return 5;
    if (lower.contains('3060') ||
        lower.contains('6600') ||
        lower.contains('4050'))
      return 4;
    if (lower.contains('3050') ||
        lower.contains('6500') ||
        lower.contains('1660'))
      return 3;
    if (lower.contains('1650') ||
        lower.contains('rx 580') ||
        lower.contains('rx 570'))
      return 2;
    return 5;
  }

  String _generateFallbackCustomerService(String query) {
    final lower = query.toLowerCase().trim();
    final rng = Random();

    T pick<T>(List<T> list) => list[rng.nextInt(list.length)];

    // Greetings
    if (lower == 'halo' ||
        lower == 'hai' ||
        lower == 'hi' ||
        lower == 'selamat pagi' ||
        lower == 'selamat siang' ||
        lower == 'selamat sore' ||
        lower == 'selamat malam' ||
        lower.startsWith('halo') ||
        lower.startsWith('hai') ||
        lower.startsWith('assalam')) {
      final greetings = [
        'Halo! Selamat datang di Doctor Computer AI Assistant. Ada yang bisa saya bantu hari ini seputar konsultasi rakit PC, cek garansi, rekomendasi spesifikasi, atau pesanan Anda?',
        'Hai kak! Dokter AI siap membantu. Apakah Anda butuh rekomendasi komponen PC/laptop, panduan upgrade, atau informasi seputar pesanan dan garansi toko?',
        'Halo! Senang bisa menyapa Anda. Silakan beri tahu kebutuhan komputasi Anda—mulai dari pemilihan prosesor & kartu grafis hingga troubleshooting teknis!',
      ];
      return pick(greetings);
    }

    // Garansi / Klaim
    if (lower.contains('garansi') ||
        lower.contains('klaim') ||
        lower.contains('retur') ||
        lower.contains('tukar') ||
        lower.contains('cacat')) {
      final warrantyResponses = [
        'Semua produk di Doctor Computer bergaransi resmi distributor Indonesia (1-3 tahun tergantung brand) dan dilindungi garansi tukar baru toko 14 hari bila terdapat cacat pabrik.\n\nUntuk memeriksa masa garansi aktif Anda, buka menu "Cek Garansi" di aplikasi atau sebutkan nomor pesanan Anda.',
        'Klaim garansi di Doctor Computer sangat mudah! Cukup bawa invoice digital di aplikasi dan unit produk beserta kelengkapan boks ke gerai kami, atau kirimkan via ekspedisi. Tim teknisi kami akan melakukan pengecekan dalam 1-3 hari kerja.',
        'Garansi resmi kami mencakup perbaikan dan penggantian suku cadang resmi. Jangan lupa simpan segel garansi dan nota pembelian digital di profil Anda. Ada nomor pesanan yang ingin Anda cek status garansinya?',
      ];
      return pick(warrantyResponses);
    }

    // Rakit PC / Custom Build / Compatibility
    if (lower.contains('rakit') ||
        lower.contains('pc builder') ||
        lower.contains('custom') ||
        lower.contains('spesifikasi') ||
        lower.contains('kompatibel') ||
        lower.contains('build')) {
      final buildResponses = [
        'Doctor Computer menyediakan layanan perakitan PC profesional!\n• Standard Assembly: Rp250.000 (perakitan presisi + cable management rapi + update BIOS).\n• Performance Tuning Build: Rp500.000 (termasuk stress test thermal 24 jam & fine tuning RAM XMP/EXPO).\n\nGunakan fitur "PC Builder" di aplikasi untuk kalkulator kompatibilitas dan AI bottleneck otomatis!',
        'Ingin merakit PC impian? Anda bisa memilih komponen sendiri di menu "Rakit PC". Sistem kami otomatis memfilter soket prosesor, ukuran motherboard, serta kebutuhan daya PSU yang sesuai. Setelah dirakit, teknisi kami melakukan pengujian stabilitas komprehensif sebelum dikirim.',
        'Untuk konsultasi rakit PC, Anda bisa sebutkan budget dan tujuan penggunaan (misal: gaming AAA 1440p, render video 4K, atau kerja harian). Kami akan siapkan racikan spesifikasi paling seimbang tanpa pemborosan dana!',
      ];
      return pick(buildResponses);
    }

    // Pesanan / Resi / Pengiriman / Status
    if (lower.contains('pesanan') ||
        lower.contains('kirim') ||
        lower.contains('resi') ||
        lower.contains('status') ||
        lower.contains('lacak') ||
        lower.contains('ongkir') ||
        lower.contains('kurir')) {
      final orderResponses = [
        'Untuk memantau perjalanan pesanan Anda, silakan cek tab "Pesanan Saya" di aplikasi. Anda dapat melihat tracking real-time mulai dari tahapan Quality Check (QC), pengemasan bubble wrap tebal + kayu, hingga posisi kurir menuju alamat Anda.',
        'Pengiriman Doctor Computer bekerja sama dengan kurir terpercaya (JNE, SiCepat, Gosend/Grab Instant untuk area Jabodetabek). Nomor resi otomatis diperbarui setelah paket diserahkan ke pihak ekspedisi.',
        'Pesanan yang masuk sebelum pukul 15.00 WIB akan diproses dan dikirim di hari yang sama (kecuali perakitan PC custom membutuhkan waktu QC 1 hari kerja). Anda dapat memasukkan ID pesanan Anda di sini jika ingin kami bantu cekkan.',
      ];
      return pick(orderResponses);
    }

    // Bluescreen / Masalah Teknis / Rusak / Overheat / Lemot
    if (lower.contains('bluescreen') ||
        lower.contains('bsod') ||
        lower.contains('rusak') ||
        lower.contains('lemot') ||
        lower.contains('mati') ||
        lower.contains('overheat') ||
        lower.contains('panas') ||
        lower.contains('hang') ||
        lower.contains('freeze') ||
        lower.contains('restart')) {
      final techResponses = [
        'Gejala Blue Screen (BSOD) atau restart mendadak umumnya dipicu oleh beberapa hal:\n1. Crash driver GPU: Gunakan DDU (Display Driver Uninstaller) dan install ulang driver terbaru.\n2. RAM tidak stabil: Bersihkan pin kuningan RAM dengan penghapus pensil lembut, coba pasang 1 keping bergantian.\n3. Overheat: Cek suhu CPU dengan HWMonitor. Jika melebihi 85°C saat beban normal, pertimbangkan ganti pasta termal (thermal paste).\n\nJika kendala berlanjut, teknisi Doctor Computer siap melakukan diagnosa gratis di outlet kami.',
        'Komputer yang lambat atau sering macet sering kali diakibatkan oleh kapasitas penyimpanan penuh, SSD sudah aus, atau background process yang membebani RAM. Kami sarankan upgrade SSD NVMe Gen 4 dan minimal RAM 16GB dual-channel untuk multitasking lancar.',
        'Suhu PC yang terlalu panas dapat menurunkan performa (thermal throttling). Pastikan arah aliran udara (airflow) casing sudah benar (front intake, rear/top exhaust) dan bersihkan debu pada heatsink pendingin secara berkala.',
      ];
      return pick(techResponses);
    }

    // Member / Loyalty / Blockchain / Poin / Tier
    if (lower.contains('member') ||
        lower.contains('poin') ||
        lower.contains('tier') ||
        lower.contains('blockchain') ||
        lower.contains('level') ||
        lower.contains('exp') ||
        lower.contains('hadiah') ||
        lower.contains('voucher') ||
        lower.contains('diskon')) {
      final memberResponses = [
        'Program Loyalitas Doctor Computer mengadopsi pencatatan terenkripsi Blockchain terdesentralisasi (Blok Genesis A1B2).\n• Dapatkan +500 EXP setiap transaksi belanja komponen.\n• Raih bonus EXP harian lewat minigames di tab "Member".\n• Tingkatan tier: Bronze, Silver (diskon 3%), Gold (diskon 5% + bebas biaya rakit), Platinum (diskon 8% + prioritas garansi servis VIP).',
        'Status member dan akumulasi poin Anda tersimpan aman dan transparan di buku besar blockchain internal Doctor Computer. Poin dapat ditukarkan langsung dengan voucher belanja, merchandise eksklusif, atau potongan servis di kasir.',
        'Tingkatkan tier member Anda dengan rajin berbelanja atau menyelesaikan misi mingguan! Setiap kenaikan tier membuka kupon potongan harga tambahan dan fasilitas konsultasi teknis prioritas.',
      ];
      return pick(memberResponses);
    }

    // RAM & Penyimpanan (SSD / HDD)
    if (lower.contains('ram') ||
        lower.contains('ssd') ||
        lower.contains('nvme') ||
        lower.contains('harddisk') ||
        lower.contains('hdd') ||
        lower.contains('storage') ||
        lower.contains('penyimpanan')) {
      final storageResponses = [
        'Untuk performa terbaik saat ini, kami merekomendasikan:\n• SSD: M.2 NVMe PCIe Gen 4x4 (kecepatan baca hingga 7000 MB/s) seperti Samsung 980/990 Pro atau Kingston KC3000.\n• RAM: Minimal 16GB (2x8GB) Dual Channel untuk gaming & office, atau 32GB (2x16GB) untuk editing 4K & rendering 3D. Pastikan frekuensi didukung oleh motherboard Anda!',
        'Upgrade dari HDD ke SSD adalah cara paling hemat untuk membuat laptop/PC lama Anda 5x lebih kencang saat boot Windows dan buka aplikasi. Kami juga menyediakan jasa kloning data sehingga Windows Anda tidak perlu diinstal ulang dari awal.',
        'Ingin tambah RAM atau SSD? Sebutkan tipe laptop atau motherboard Anda, agar kami dapat memastikan jenis soket (DDR4 vs DDR5 / NVMe vs SATA) yang cocok!',
      ];
      return pick(storageResponses);
    }

    // Kartu Grafis (VGA / GPU) & Gaming
    if (lower.contains('vga') ||
        lower.contains('gpu') ||
        lower.contains('rtx') ||
        lower.contains('gtx') ||
        lower.contains('radeon') ||
        lower.contains('gaming') ||
        lower.contains('fps')) {
      final gpuResponses = [
        'Untuk gaming modern di resolusi 1080p kompetitif, RTX 4060 sudah sangat bertenaga dengan konsumsi daya rendah dan dukungan DLSS 3 Frame Generation. Untuk resolusi 1440p Ultra, kami sarankan RTX 4070 Super atau Radeon RX 7800 XT yang memiliki VRAM minimal 12GB - 16GB.',
        'Saat memilih kartu grafis, pastikan juga Power Supply (PSU) Anda mencukupi (RTX 4060 butuh min 550W, RTX 4070 butuh min 650W Berkualitas 80+ Bronze/Gold) dan panjang casing cukup untuk menampung ukuran VGA.',
        'Koleksi kartu grafis di Doctor Computer dijamin 100% baru, bergaransi resmi, dan bukan bekas mining. Butuh rekomendasi VGA untuk game tertentu? Sebutkan judul gamenya!',
      ];
      return pick(gpuResponses);
    }

    // Prosesor / CPU
    if (lower.contains('cpu') ||
        lower.contains('prosesor') ||
        lower.contains('processor') ||
        lower.contains('intel') ||
        lower.contains('amd') ||
        lower.contains('ryzen') ||
        lower.contains('core i')) {
      final cpuResponses = [
        'Pilihan prosesor terbaik saat ini:\n• Budget Gaming: Intel Core i5-12400F atau AMD Ryzen 5 5600 (value terbaik di bawah 2 juta).\n• Mid-Range: AMD Ryzen 5 7600 (platform AM5 future-proof) atau Intel Core i5-14600K.\n• High-End Gaming: AMD Ryzen 7 7800X3D (prosesor gaming terkencang di dunia dengan 3D V-Cache).\n• Content Creation: Intel Core i7-14700K / Ryzen 9 7900X.',
        'Jangan lupa bahwa prosesor seri kencang (seperti Core i7/i9 atau Ryzen 7/9) membutuhkan pendingin yang memadai (Liquid Cooler AIO 240mm/360mm) agar performanya tidak drop karena panas berlebih.',
      ];
      return pick(cpuResponses);
    }

    // Pembayaran / Cicilan / Harga
    if (lower.contains('bayar') ||
        lower.contains('pembayaran') ||
        lower.contains('cicilan') ||
        lower.contains('kredit') ||
        lower.contains('qris') ||
        lower.contains('transfer') ||
        lower.contains('cod')) {
      final payResponses = [
        'Metode pembayaran di Doctor Computer sangat fleksibel:\n• QRIS (BCA, GoPay, OVO, Dana, ShopeePay)\n• Transfer Virtual Account (BCA, Mandiri, BRI, BNI)\n• Cicilan Kartu Kredit 0% hingga 12 bulan\n• PayLater (Kredivo, Akulaku, SpayLater)\n• COD (khusus pengiriman kurir instan di area tertentu).',
        'Seluruh transaksi pembayaran diproses melalui payment gateway terenkripsi sehingga keamanan data Anda 100% terlindungi.',
      ];
      return pick(payResponses);
    }

    // Kontak / Toko Fisik / Jam Buka
    if (lower.contains('alamat') ||
        lower.contains('lokasi') ||
        lower.contains('toko') ||
        lower.contains('buka') ||
        lower.contains('jam') ||
        lower.contains('whatsapp') ||
        lower.contains('cabang')) {
      final locationResponses = [
        'Outlet & Service Center Doctor Computer beroperasi:\n• Senin - Sabtu: 09.00 - 20.00 WIB\n• Minggu & Hari Libur: 10.00 - 17.00 WIB\n\nAnda dapat berkonsultasi langsung dengan teknisi kami di toko atau berbelanja online melalui aplikasi dengan jaminan pengiriman aman.',
        'Lokasi toko kami dilengkapi dengan Clean Bench untuk perakitan PC, ruang pengujian suku cadang, dan area konsultasi ber-AC. Silakan kunjungi gerai kami untuk konsultasi langsung!',
      ];
      return pick(locationResponses);
    }

    // General fallback
    final generalResponses = [
      'Terima kasih telah berkonsultasi dengan Doctor Computer AI! Kami siap membantu kebutuhan perakitan PC, cek stok & garansi komponen, perbaikan hardware, hingga rekomendasi belanja hemat. Silakan ceritakan kebutuhan Anda lebih spesifik!',
      'Halo! Ada hal spesifik yang ingin Anda diskusikan? Misalnya: "Rekomendasi PC budget 10 juta", "Cara klaim garansi SSD", atau "Penyebab PC sering blue screen". Tim AI kami siap memberi jawaban teknis terbaik!',
      'Dokter PC siap melayani! Anda bisa menanyakan rekomendasi spesifikasi gaming, editing, pengecekan kompatibilitas soket, maupun pelacakan pesanan Anda di Doctor Computer.',
    ];
    return pick(generalResponses);
  }
}
