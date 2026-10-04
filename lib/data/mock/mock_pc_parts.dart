import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/data/models/review_model.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/data/models/cart_item_model.dart';

final List<PcPartModel> mockPcParts = [
  // CPUs (10)
  const PcPartModel(id: 'c1', name: 'Intel Core i3-14100F', category: PcPartCategory.cpu, brand: 'Intel', price: 1800000, specs: {'Cores': '4', 'Threads': '8', 'Base Clock': '3.5 GHz', 'Socket': 'LGA 1700'}, compatibilityTags: ['intel_lga1700']),
  const PcPartModel(id: 'c2', name: 'Intel Core i5-14400F', category: PcPartCategory.cpu, brand: 'Intel', price: 2900000, specs: {'Cores': '10', 'Threads': '16', 'Base Clock': '2.5 GHz', 'Socket': 'LGA 1700'}, compatibilityTags: ['intel_lga1700']),
  const PcPartModel(id: 'c3', name: 'Intel Core i5-14600K', category: PcPartCategory.cpu, brand: 'Intel', price: 4200000, specs: {'Cores': '14', 'Threads': '20', 'Base Clock': '3.5 GHz', 'Socket': 'LGA 1700'}, compatibilityTags: ['intel_lga1700']),
  const PcPartModel(id: 'c4', name: 'Intel Core i7-14700K', category: PcPartCategory.cpu, brand: 'Intel', price: 6200000, specs: {'Cores': '20', 'Threads': '28', 'Base Clock': '3.4 GHz', 'Socket': 'LGA 1700'}, compatibilityTags: ['intel_lga1700']),
  const PcPartModel(id: 'c5', name: 'Intel Core i9-14900K', category: PcPartCategory.cpu, brand: 'Intel', price: 8500000, specs: {'Cores': '24', 'Threads': '32', 'Base Clock': '3.2 GHz', 'Socket': 'LGA 1700'}, compatibilityTags: ['intel_lga1700']),
  const PcPartModel(id: 'c6', name: 'AMD Ryzen 5 7600', category: PcPartCategory.cpu, brand: 'AMD', price: 3100000, specs: {'Cores': '6', 'Threads': '12', 'Base Clock': '3.8 GHz', 'Socket': 'AM5'}, compatibilityTags: ['amd_am5']),
  const PcPartModel(id: 'c7', name: 'AMD Ryzen 5 7600X', category: PcPartCategory.cpu, brand: 'AMD', price: 3500000, specs: {'Cores': '6', 'Threads': '12', 'Base Clock': '4.7 GHz', 'Socket': 'AM5'}, compatibilityTags: ['amd_am5']),
  const PcPartModel(id: 'c8', name: 'AMD Ryzen 7 7700X', category: PcPartCategory.cpu, brand: 'AMD', price: 4800000, specs: {'Cores': '8', 'Threads': '16', 'Base Clock': '4.5 GHz', 'Socket': 'AM5'}, compatibilityTags: ['amd_am5']),
  const PcPartModel(id: 'c9', name: 'AMD Ryzen 7 7800X3D', category: PcPartCategory.cpu, brand: 'AMD', price: 5900000, specs: {'Cores': '8', 'Threads': '16', 'Base Clock': '4.2 GHz', 'Socket': 'AM5'}, compatibilityTags: ['amd_am5']),
  const PcPartModel(id: 'c10', name: 'AMD Ryzen 9 7900X', category: PcPartCategory.cpu, brand: 'AMD', price: 6500000, specs: {'Cores': '12', 'Threads': '24', 'Base Clock': '4.7 GHz', 'Socket': 'AM5'}, compatibilityTags: ['amd_am5']),

  // GPUs (10)
  const PcPartModel(id: 'g1', name: 'NVIDIA RTX 4060', category: PcPartCategory.gpu, brand: 'NVIDIA', price: 5200000, specs: {'VRAM': '8GB', 'Memory Type': 'GDDR6'}, compatibilityTags: []),
  const PcPartModel(id: 'g2', name: 'NVIDIA RTX 4060 Ti', category: PcPartCategory.gpu, brand: 'NVIDIA', price: 6800000, specs: {'VRAM': '8GB', 'Memory Type': 'GDDR6'}, compatibilityTags: []),
  const PcPartModel(id: 'g3', name: 'NVIDIA RTX 4070', category: PcPartCategory.gpu, brand: 'NVIDIA', price: 9500000, specs: {'VRAM': '12GB', 'Memory Type': 'GDDR6X'}, compatibilityTags: []),
  const PcPartModel(id: 'g4', name: 'NVIDIA RTX 4070 Ti Super', category: PcPartCategory.gpu, brand: 'NVIDIA', price: 12500000, specs: {'VRAM': '16GB', 'Memory Type': 'GDDR6X'}, compatibilityTags: []),
  const PcPartModel(id: 'g5', name: 'NVIDIA RTX 4080 Super', category: PcPartCategory.gpu, brand: 'NVIDIA', price: 18000000, specs: {'VRAM': '16GB', 'Memory Type': 'GDDR6X'}, compatibilityTags: []),
  const PcPartModel(id: 'g6', name: 'NVIDIA RTX 4090', category: PcPartCategory.gpu, brand: 'NVIDIA', price: 28000000, specs: {'VRAM': '24GB', 'Memory Type': 'GDDR6X'}, compatibilityTags: []),
  const PcPartModel(id: 'g7', name: 'AMD RX 7600', category: PcPartCategory.gpu, brand: 'AMD', price: 4500000, specs: {'VRAM': '8GB', 'Memory Type': 'GDDR6'}, compatibilityTags: []),
  const PcPartModel(id: 'g8', name: 'AMD RX 7700 XT', category: PcPartCategory.gpu, brand: 'AMD', price: 6800000, specs: {'VRAM': '12GB', 'Memory Type': 'GDDR6'}, compatibilityTags: []),
  const PcPartModel(id: 'g9', name: 'AMD RX 7800 XT', category: PcPartCategory.gpu, brand: 'AMD', price: 8200000, specs: {'VRAM': '16GB', 'Memory Type': 'GDDR6'}, compatibilityTags: []),
  const PcPartModel(id: 'g10', name: 'AMD RX 7900 XTX', category: PcPartCategory.gpu, brand: 'AMD', price: 14500000, specs: {'VRAM': '24GB', 'Memory Type': 'GDDR6'}, compatibilityTags: []),

  // Motherboards (8)
  const PcPartModel(id: 'm1', name: 'ASUS Prime B660M-A', category: PcPartCategory.motherboard, brand: 'ASUS', price: 1800000, specs: {'Socket': 'LGA 1700', 'Form Factor': 'mATX'}, compatibilityTags: ['intel_lga1700', 'ddr4']),
  const PcPartModel(id: 'm2', name: 'MSI PRO B760M-P', category: PcPartCategory.motherboard, brand: 'MSI', price: 2200000, specs: {'Socket': 'LGA 1700', 'Form Factor': 'mATX'}, compatibilityTags: ['intel_lga1700', 'ddr5']),
  const PcPartModel(id: 'm3', name: 'ASUS ROG Strix Z790-E', category: PcPartCategory.motherboard, brand: 'ASUS', price: 4500000, specs: {'Socket': 'LGA 1700', 'Form Factor': 'ATX'}, compatibilityTags: ['intel_lga1700', 'ddr5']),
  const PcPartModel(id: 'm4', name: 'MSI MEG Z790 ACE', category: PcPartCategory.motherboard, brand: 'MSI', price: 8500000, specs: {'Socket': 'LGA 1700', 'Form Factor': 'E-ATX'}, compatibilityTags: ['intel_lga1700', 'ddr5']),
  const PcPartModel(id: 'm5', name: 'Gigabyte B650M DS3H', category: PcPartCategory.motherboard, brand: 'Gigabyte', price: 2000000, specs: {'Socket': 'AM5', 'Form Factor': 'mATX'}, compatibilityTags: ['amd_am5', 'ddr5']),
  const PcPartModel(id: 'm6', name: 'MSI MAG B650 Tomahawk', category: PcPartCategory.motherboard, brand: 'MSI', price: 3200000, specs: {'Socket': 'AM5', 'Form Factor': 'ATX'}, compatibilityTags: ['amd_am5', 'ddr5']),
  const PcPartModel(id: 'm7', name: 'ASUS ROG Strix B650E-F', category: PcPartCategory.motherboard, brand: 'ASUS', price: 3800000, specs: {'Socket': 'AM5', 'Form Factor': 'ATX'}, compatibilityTags: ['amd_am5', 'ddr5']),
  const PcPartModel(id: 'm8', name: 'ASUS ROG Crosshair X670E Hero', category: PcPartCategory.motherboard, brand: 'ASUS', price: 5500000, specs: {'Socket': 'AM5', 'Form Factor': 'ATX'}, compatibilityTags: ['amd_am5', 'ddr5']),

  // RAM (6)
  const PcPartModel(id: 'r1', name: 'Kingston Fury Beast 16GB DDR5-5600', category: PcPartCategory.ram, brand: 'Kingston', price: 850000, specs: {'Type': 'DDR5', 'Speed': '5600 MHz'}, compatibilityTags: ['ddr5']),
  const PcPartModel(id: 'r2', name: 'Corsair Vengeance 16GB DDR5-5600', category: PcPartCategory.ram, brand: 'Corsair', price: 950000, specs: {'Type': 'DDR5', 'Speed': '5600 MHz'}, compatibilityTags: ['ddr5']),
  const PcPartModel(id: 'r3', name: 'G.Skill Trident Z5 32GB DDR5-6000', category: PcPartCategory.ram, brand: 'G.Skill', price: 1800000, specs: {'Type': 'DDR5', 'Speed': '6000 MHz'}, compatibilityTags: ['ddr5']),
  const PcPartModel(id: 'r4', name: 'Kingston Fury Beast 32GB DDR5-5600', category: PcPartCategory.ram, brand: 'Kingston', price: 1500000, specs: {'Type': 'DDR5', 'Speed': '5600 MHz'}, compatibilityTags: ['ddr5']),
  const PcPartModel(id: 'r5', name: 'Corsair Dominator Platinum 32GB DDR5-6400', category: PcPartCategory.ram, brand: 'Corsair', price: 2200000, specs: {'Type': 'DDR5', 'Speed': '6400 MHz'}, compatibilityTags: ['ddr5']),
  const PcPartModel(id: 'r6', name: 'G.Skill Trident Z5 RGB 64GB DDR5-6000', category: PcPartCategory.ram, brand: 'G.Skill', price: 3500000, specs: {'Type': 'DDR5', 'Speed': '6000 MHz'}, compatibilityTags: ['ddr5']),

  // Storage (6)
  const PcPartModel(id: 's1', name: 'Samsung 980 500GB NVMe', category: PcPartCategory.storage, brand: 'Samsung', price: 700000, specs: {'Capacity': '500GB', 'Form Factor': 'M.2'}, compatibilityTags: ['nvme_m2']),
  const PcPartModel(id: 's2', name: 'Samsung 990 Pro 1TB NVMe', category: PcPartCategory.storage, brand: 'Samsung', price: 1500000, specs: {'Capacity': '1TB', 'Form Factor': 'M.2'}, compatibilityTags: ['nvme_m2']),
  const PcPartModel(id: 's3', name: 'WD Black SN850X 1TB NVMe', category: PcPartCategory.storage, brand: 'WD', price: 1400000, specs: {'Capacity': '1TB', 'Form Factor': 'M.2'}, compatibilityTags: ['nvme_m2']),
  const PcPartModel(id: 's4', name: 'Kingston NV2 1TB NVMe', category: PcPartCategory.storage, brand: 'Kingston', price: 800000, specs: {'Capacity': '1TB', 'Form Factor': 'M.2'}, compatibilityTags: ['nvme_m2']),
  const PcPartModel(id: 's5', name: 'Samsung 990 Pro 2TB NVMe', category: PcPartCategory.storage, brand: 'Samsung', price: 2500000, specs: {'Capacity': '2TB', 'Form Factor': 'M.2'}, compatibilityTags: ['nvme_m2']),
  const PcPartModel(id: 's6', name: 'WD Black SN850X 2TB NVMe', category: PcPartCategory.storage, brand: 'WD', price: 2200000, specs: {'Capacity': '2TB', 'Form Factor': 'M.2'}, compatibilityTags: ['nvme_m2']),

  // PSU (6)
  const PcPartModel(id: 'p1', name: 'Corsair CV550 550W 80+ Bronze', category: PcPartCategory.psu, brand: 'Corsair', price: 700000, specs: {'Wattage': '550W', 'Efficiency': '80+ Bronze'}, compatibilityTags: []),
  const PcPartModel(id: 'p2', name: 'SeaSonic Focus GX-650 80+ Gold', category: PcPartCategory.psu, brand: 'SeaSonic', price: 1100000, specs: {'Wattage': '650W', 'Efficiency': '80+ Gold'}, compatibilityTags: []),
  const PcPartModel(id: 'p3', name: 'Corsair RM750e 750W 80+ Gold', category: PcPartCategory.psu, brand: 'Corsair', price: 1400000, specs: {'Wattage': '750W', 'Efficiency': '80+ Gold'}, compatibilityTags: []),
  const PcPartModel(id: 'p4', name: 'SeaSonic Focus GX-850 80+ Gold', category: PcPartCategory.psu, brand: 'SeaSonic', price: 1800000, specs: {'Wattage': '850W', 'Efficiency': '80+ Gold'}, compatibilityTags: []),
  const PcPartModel(id: 'p5', name: 'Corsair RM1000e 1000W 80+ Gold', category: PcPartCategory.psu, brand: 'Corsair', price: 2200000, specs: {'Wattage': '1000W', 'Efficiency': '80+ Gold'}, compatibilityTags: []),
  const PcPartModel(id: 'p6', name: 'be quiet! Dark Power 13 1000W', category: PcPartCategory.psu, brand: 'be quiet!', price: 3200000, specs: {'Wattage': '1000W', 'Efficiency': '80+ Titanium'}, compatibilityTags: []),

  // Cases (6)
  const PcPartModel(id: 'ca1', name: 'Tecware Forge M2 mATX', category: PcPartCategory.pcCase, brand: 'Tecware', price: 450000, specs: {'Form Factor': 'mATX'}, compatibilityTags: []),
  const PcPartModel(id: 'ca2', name: 'NZXT H5 Flow ATX', category: PcPartCategory.pcCase, brand: 'NZXT', price: 1100000, specs: {'Form Factor': 'ATX'}, compatibilityTags: []),
  const PcPartModel(id: 'ca3', name: 'Corsair 4000D Airflow ATX', category: PcPartCategory.pcCase, brand: 'Corsair', price: 1200000, specs: {'Form Factor': 'ATX'}, compatibilityTags: []),
  const PcPartModel(id: 'ca4', name: 'Lian Li Lancool III ATX', category: PcPartCategory.pcCase, brand: 'Lian Li', price: 1800000, specs: {'Form Factor': 'ATX'}, compatibilityTags: []),
  const PcPartModel(id: 'ca5', name: 'NZXT H9 Flow ATX', category: PcPartCategory.pcCase, brand: 'NZXT', price: 2500000, specs: {'Form Factor': 'ATX'}, compatibilityTags: []),
  const PcPartModel(id: 'ca6', name: 'Lian Li O11 Dynamic EVO ATX', category: PcPartCategory.pcCase, brand: 'Lian Li', price: 2800000, specs: {'Form Factor': 'ATX'}, compatibilityTags: []),

  // Coolers (5)
  const PcPartModel(id: 'co1', name: 'ID-COOLING SE-214-XT Air Cooler', category: PcPartCategory.cooler, brand: 'ID-COOLING', price: 250000, specs: {'Type': 'Air Cooler'}, compatibilityTags: []),
  const PcPartModel(id: 'co2', name: 'DeepCool AK620 Air Cooler', category: PcPartCategory.cooler, brand: 'DeepCool', price: 550000, specs: {'Type': 'Air Cooler'}, compatibilityTags: []),
  const PcPartModel(id: 'co3', name: 'NZXT Kraken 240mm AIO', category: PcPartCategory.cooler, brand: 'NZXT', price: 1400000, specs: {'Type': 'Liquid AIO', 'Size': '240mm'}, compatibilityTags: []),
  const PcPartModel(id: 'co4', name: 'Corsair iCUE H150i Elite 360mm AIO', category: PcPartCategory.cooler, brand: 'Corsair', price: 2200000, specs: {'Type': 'Liquid AIO', 'Size': '360mm'}, compatibilityTags: []),
  const PcPartModel(id: 'co5', name: 'NZXT Kraken 360mm AIO', category: PcPartCategory.cooler, brand: 'NZXT', price: 2800000, specs: {'Type': 'Liquid AIO', 'Size': '360mm'}, compatibilityTags: []),
];

final List<ReviewModel> mockReviews = [
  ReviewModel(id: 'rv1', userId: 'u1', userName: 'Budi Santoso', productId: 'lap1', rating: 5, comment: 'Sangat kencang buat main game berat!', date: DateTime.now().subtract(const Duration(days: 2))),
  ReviewModel(id: 'rv2', userId: 'u2', userName: 'Andi M', productId: 'lap2', rating: 4, comment: 'Layar bagus tapi batre lumayan boros.', date: DateTime.now().subtract(const Duration(days: 5))),
  ReviewModel(id: 'rv3', userId: 'u3', userName: 'Siti R', productId: 'mon1', rating: 5, comment: 'Warna tajam, recommended!', date: DateTime.now().subtract(const Duration(days: 10))),
  ReviewModel(id: 'rv4', userId: 'u4', userName: 'Joko P', productId: 'ms1', rating: 4, comment: 'Mouse mantap, klik empuk.', date: DateTime.now().subtract(const Duration(days: 1))),
];

final List<OrderModel> mockOrders = [
  OrderModel(
    id: 'ORD-1001',
    items: [],
    totalPrice: 15500000,
    status: OrderStatus.processing,
    orderDate: DateTime.now(),
    shippingAddress: 'Jl. Merdeka No 1, Jakarta',
    paymentMethod: 'Transfer Bank BCA',
  ),
  OrderModel(
    id: 'ORD-1002',
    items: [],
    totalPrice: 4500000,
    status: OrderStatus.shipped,
    orderDate: DateTime.now().subtract(const Duration(days: 2)),
    shippingAddress: 'Jl. Sudirman No 10, Bandung',
    paymentMethod: 'GoPay',
  ),
];
