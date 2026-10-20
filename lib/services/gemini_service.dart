import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  String apiKey = '';

  /// Generate AI reply for Customer Service Chat
  Future<String> getCustomerServiceResponse(
    String userQuery,
    List<Map<String, String>> history,
  ) async {
    if (apiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
        );

        final systemPrompt = '''
Anda adalah AI Customer Service resmi dari "Doctor Computer", toko komputer dan perakitan PC terpercaya.
Bantu pelanggan dengan ramah, informatif, dan profesional berbahasa Indonesia.
Layanan kami meliputi:
1. Penjualan komponen PC (CPU, GPU, Motherboard, RAM, SSD, PSU, Casing, Cooler, Monitor, Laptop).
2. Perakitan Custom PC dengan pengujian stabilitas dan cable management rapi.
3. Garansi Resmi & Toko (1-3 tahun), serta klaim servis cepat.
4. Troubleshooting masalah komputer (bluescreen, overheat, lambat, upgrade komponen).
5. Sistem Member Loyalty berjenjang berbasis Blockchain (Bronze, Silver, Gold, Platinum).
Jawab pertanyaan pengguna dengan padat, jelas, dan solusi teknis yang tepat.
''';

        final contents = [
          {
            'role': 'user',
            'parts': [
              {'text': systemPrompt}
            ]
          },
          ...history.map((h) => {
                'role': h['role'] == 'user' ? 'user' : 'model',
                'parts': [
                  {'text': h['text'] ?? ''}
                ]
              }),
          {
            'role': 'user',
            'parts': [
              {'text': userQuery}
            ]
          }
        ];

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'contents': contents}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'].toString();
            }
          }
        }
      } catch (e) {
        debugPrint('Gemini API request failed: $e, using expert fallback.');
      }
    }

    // Smart Domain Expert Fallback Engine
    return _generateFallbackCustomerService(userQuery);
  }

  /// AI-powered Smart Search
  Future<Map<String, dynamic>> searchWithAI({
    required String query,
    required List<ProductModel> catalog,
  }) async {
    final lower = query.toLowerCase();

    // Match products based on intent
    List<ProductModel> matches = [];
    String explanation = '';

    if (lower.contains('gaming') || lower.contains('game') || lower.contains('rtx') || lower.contains('fps')) {
      matches = catalog.where((p) {
        final n = p.name.toLowerCase();
        final b = p.brand.toLowerCase();
        return n.contains('rtx') || n.contains('tuf') || n.contains('gaming') || n.contains('katana') || b.contains('nvidia');
      }).toList();
      explanation = 'Berdasarkan analisis kebutuhan gaming, kami merekomendasikan produk dengan kartu grafis terdedikasi (RTX series) dan refresh rate tinggi untuk performa mulus pada game berat.';
    } else if (lower.contains('budget') || lower.contains('murah') || lower.contains('terjangkau') || lower.contains('juta')) {
      final sortedByPrice = List<ProductModel>.from(catalog)..sort((a, b) => a.price.compareTo(b.price));
      matches = sortedByPrice.take(4).toList();
      explanation = 'AI mengurutkan produk dengan value-for-money terbaik untuk memaksimalkan efisiensi anggaran belanja Anda.';
    } else if (lower.contains('editing') || lower.contains('render') || lower.contains('desain') || lower.contains('ram 32')) {
      matches = catalog.where((p) {
        final n = p.name.toLowerCase();
        return n.contains('ram') || n.contains('core i7') || n.contains('ssd') || n.contains('oled') || n.contains('macbook');
      }).toList();
      explanation = 'Untuk kebutuhan video editing & rendering, AI memprioritaskan prosesor multi-core tinggi, kapasitas RAM besar, dan SSD berkecepatan tinggi.';
    } else if (lower.contains('dingin') || lower.contains('panas') || lower.contains('cooler') || lower.contains('overheat')) {
      matches = catalog.where((p) {
        final n = p.name.toLowerCase();
        return n.contains('cooler') || n.contains('noctua') || n.contains('case');
      }).toList();
      explanation = 'AI merekomendasikan solusi pendinginan performa tinggi dengan airflow optimal untuk menjaga temperatur sistem tetap stabil di bawah 65°C.';
    } else {
      matches = catalog.where((p) {
        return p.name.toLowerCase().contains(lower) ||
            p.brand.toLowerCase().contains(lower) ||
            p.description.toLowerCase().contains(lower);
      }).toList();
      explanation = 'Hasil kurasi rekomendasi AI Doctor Computer yang paling relevan dengan kata kunci pencarian Anda.';
    }

    if (matches.isEmpty && catalog.isNotEmpty) {
      matches = catalog.take(4).toList();
    }

    return {
      'explanation': explanation,
      'recommendations': matches,
    };
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
        'gamingFps': {},
      };
    }

    // Estimate relative tiers (1 - 10)
    int cpuTier = _getCpuTier(cpu.name);
    int gpuTier = _getGpuTier(gpu.name);

    int diff = cpuTier - gpuTier;
    int percentage = 0;
    String type = 'balanced';
    String status = 'Sangat Seimbang (Optimal)';
    String advice = 'Kombinasi prosesor dan kartu grafis sangat harmonis. Tidak terjadi pemborosan performa.';
    Color color = Colors.green;

    if (diff < -2) {
      // CPU is much weaker than GPU
      percentage = (20 + (diff.abs() * 5)).clamp(15, 38);
      type = 'cpu_bottleneck';
      status = 'CPU Bottleneck ($percentage%)';
      color = Colors.red;
      advice = 'CPU Anda (${cpu.name}) terlalu lemah untuk mengimbangi daya kartu grafis ${gpu.name}. GPU tidak akan mencapai utilisasi 100%. Disarankan upgrade prosesor ke seri yang lebih tinggi.';
    } else if (diff > 2) {
      // GPU is weaker than CPU
      percentage = (15 + (diff * 4)).clamp(12, 30);
      type = 'gpu_bottleneck';
      status = 'GPU Bottleneck ($percentage%)';
      color = Colors.orange;
      advice = 'Kartu grafis Anda (${gpu.name}) menjadi batas performa game dibandingkan kemampuan prosesor ${cpu.name}. Untuk gaming resolusi 1440p/4K, disarankan upgrade GPU.';
    } else {
      percentage = (diff.abs() * 3 + 4).clamp(3, 9);
      type = 'balanced';
      status = 'Optimal ($percentage% Bottleneck)';
      color = Colors.green;
      advice = 'Kombinasi ${cpu.name} & ${gpu.name} bekerja sempurna dengan efisiensi maksimal tanpa hambatan signifikan.';
    }

    // Gaming FPS Estimates based on GPU tier
    Map<String, String> fpsEstimates = {
      'Cyberpunk 2077 (1440p Ultra)': '${_estimateFps(gpuTier, 45, 120)} FPS',
      'Valorant / CS2 (1080p High)': '${_estimateFps(cpuTier, 180, 450)} FPS',
      'GTA V / Forza Horizon 5': '${_estimateFps(gpuTier, 75, 165)} FPS',
      'Black Myth: Wukong (High)': '${_estimateFps(gpuTier, 40, 105)} FPS',
    };

    return {
      'bottleneckPercentage': percentage,
      'type': type,
      'status': status,
      'advice': advice,
      'color': color,
      'gamingFps': fpsEstimates,
      'recommendedResolution': gpuTier >= 7 ? '1440p / 4K Gaming' : (gpuTier >= 4 ? '1080p / 1440p Gaming' : '1080p Esports'),
    };
  }

  int _estimateFps(int tier, int minFps, int maxFps) {
    double factor = (tier / 10).clamp(0.2, 1.0);
    return (minFps + (maxFps - minFps) * factor).toInt();
  }

  int _getCpuTier(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('i9') || lower.contains('7900') || lower.contains('7950')) return 10;
    if (lower.contains('7800x3d') || lower.contains('i7-14700') || lower.contains('i7-13700')) return 9;
    if (lower.contains('i7') || lower.contains('7700')) return 8;
    if (lower.contains('i5-14600') || lower.contains('7600x')) return 7;
    if (lower.contains('i5-14400') || lower.contains('7600')) return 6;
    if (lower.contains('i5') || lower.contains('ryzen 5')) return 5;
    if (lower.contains('i3-14100')) return 4;
    if (lower.contains('i3') || lower.contains('ryzen 3')) return 3;
    return 5;
  }

  int _getGpuTier(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('4090')) return 10;
    if (lower.contains('4080') || lower.contains('7900 xtx')) return 9;
    if (lower.contains('4070 ti') || lower.contains('7900 xt')) return 8;
    if (lower.contains('4070') || lower.contains('7800 xt')) return 7;
    if (lower.contains('4060 ti') || lower.contains('7700 xt')) return 6;
    if (lower.contains('4060') || lower.contains('7600')) return 5;
    if (lower.contains('3060') || lower.contains('6600')) return 4;
    return 5;
  }

  String _generateFallbackCustomerService(String query) {
    final lower = query.toLowerCase();

    if (lower.contains('garansi') || lower.contains('klaim')) {
      return 'Halo! Seluruh produk di Doctor Computer dilindungi garansi resmi distributor 1-3 tahun serta garansi toko 14 hari ganti baru jika terdapat cacat pabrik. Anda dapat memeriksa status garansi aktif di menu "Cek Masa Garansi Aktif" dengan memasukkan nomor pesanan Anda.';
    } else if (lower.contains('rakit') || lower.contains('pc builder') || lower.contains('custom')) {
      return 'Kami menyediakan layanan perakitan PC lengkap dengan kalkulator bottleneck AI dan pengecekan kompatibilitas soket otomatis. Anda bisa memilih layanan Standard Build (Rp250.000) atau Premium Cable Management & Stress Testing (Rp500.000) di tab "Rakit PC".';
    } else if (lower.contains('pesanan') || lower.contains('kirim') || lower.contains('resi') || lower.contains('status')) {
      return 'Untuk melacak status pesanan dan nomor resi kurir, silakan buka menu "Pesanan Saya / My Orders" lalu pilih "Cek Status Pesanan". Anda dapat melihat alur lengkap mulai dari Quality Check komponen hingga kurir menuju lokasi Anda.';
    } else if (lower.contains('bluescreen') || lower.contains('rusak') || lower.contains('lemot') || lower.contains('mati')) {
      return 'Masalah Blue Screen (BSOD) umumnya disebabkan oleh driver grafis yang tidak kompatibel, modul RAM yang kotor/tidak stabil, atau temperatur prosesor berlebih. Kami sarankan mencoba bersihkan pin RAM, update driver via website resmi, atau bawa unit Anda ke outlet servis Doctor Computer terdekat.';
    } else if (lower.contains('member') || lower.contains('poin') || lower.contains('tier') || lower.contains('game')) {
      return 'Sistem keanggotaan Doctor Computer menggunakan pencatatan terenkripsi Blockchain (mulai dari Blok 0 Genesis Hash A1B2). Anda dapat menaikkan tier ke Silver, Gold, atau Platinum dengan berbelanja komponen (+500 EXP) atau memenangkan Minigames di tab Member!';
    }

    return 'Terima kasih telah menghubungi Customer Service Doctor Computer AI! Kami siap membantu konsultasi spesifikasi PC, pengecekan garansi resmi, panduan perakitan, maupun pelacakan status pesanan Anda. Ada yang bisa kami bantu lebih spesifik?';
  }
}
