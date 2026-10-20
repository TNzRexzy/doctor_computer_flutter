-- Seed Data for Doctor Computer App
-- Run this in Supabase SQL Editor

-- Insert Categories
INSERT INTO categories (id, name, slug, icon, created_at) VALUES
('cat_001', 'CPU', 'cpu', '⚡', NOW()),
('cat_002', 'GPU', 'gpu', '🎮', NOW()),
('cat_003', 'Motherboard', 'motherboard', '🧩', NOW()),
('cat_004', 'RAM', 'ram', '💾', NOW()),
('cat_005', 'Storage', 'storage', '💿', NOW()),
('cat_006', 'PSU', 'psu', '⚡', NOW()),
('cat_007', 'Cooling', 'cooling', '❄️', NOW()),
('cat_008', 'Case', 'case', '📦', NOW()),
('cat_009', 'Peripherals', 'peripherals', '🖥️', NOW()),
('cat_010', 'Laptop', 'laptop', '💻', NOW());

-- Insert Sample Products
INSERT INTO products (id, name, slug, category_id, description, price, discount_price, stock, rating, review_count, created_at, updated_at) VALUES
('prd_001', 'Intel Core i7-12700K', 'intel-core-i7-12700k', 'cat_001', '12 cores, 20 threads, 5.0GHz boost', 4500000, 4200000, 15, 4.8, 23, NOW(), NOW()),
('prd_002', 'NVIDIA RTX 4080', 'nvidia-rtx-4080', 'cat_002', '16GB GDDR6X, DLSS 3', 18000000, 17000000, 8, 4.9, 35, NOW(), NOW()),
('prd_003', 'MSI MAG B660 TOMAHAWK', 'msi-b660-tomahawk', 'cat_003', 'DDR5, PCIe 5.0, WiFi 6E', 3200000, 3000000, 20, 4.7, 18, NOW(), NOW()),
('prd_004', 'Corsair Vengeance DDR5 32GB', 'corsair-vengeance-ddr5', 'cat_004', '5600MHz, CL36', 1800000, 1650000, 50, 4.6, 42, NOW(), NOW()),
('prd_005', 'Samsung 980 Pro 1TB', 'samsung-980-pro-1tb', 'cat_005', 'NVMe SSD, 7000MB/s', 2200000, 2000000, 35, 4.9, 56, NOW(), NOW()),
('prd_006', 'Corsair RM850x', 'corsair-rm850x', 'cat_006', '850W, 80+ Gold, Fully Modular', 1500000, 1400000, 25, 4.8, 29, NOW(), NOW()),
('prd_007', 'Noctua NH-D15', 'noctua-nh-d15', 'cat_007', 'Dual-fan, 125W TDP', 900000, 850000, 40, 4.9, 67, NOW(), NOW()),
('prd_008', 'Fractal Design Define 7', 'fractal-define-7', 'cat_008', 'Mid Tower, Sound Damped', 1100000, 1000000, 30, 4.7, 31, NOW(), NOW());

-- Insert PC Parts
INSERT INTO pc_parts (id, name, slug, category, type, brand, price, stock, compatibility_notes, created_at) VALUES
('part_001', 'Intel Core i7-12700K', 'intel-i7-12700k', 'CPU', 'processor', 'Intel', 4500000, 15, 'LGA1700, DDR5', NOW()),
('part_002', 'NVIDIA RTX 4080', 'nvidia-rtx-4080', 'GPU', 'graphics_card', 'NVIDIA', 18000000, 8, '16GB, PCIe 4.0 x16', NOW()),
('part_003', 'MSI MAG B660 TOMAHAWK', 'msi-b660', 'Motherboard', 'motherboard', 'MSI', 3200000, 20, 'LGA1700, DDR5', NOW()),
('part_004', 'Corsair Vengeance 32GB DDR5', 'corsair-ddr5', 'RAM', 'ram', 'Corsair', 1800000, 50, '5600MHz, 2x16GB', NOW()),
('part_005', 'Samsung 980 Pro 1TB', 'samsung-980', 'Storage', 'storage', 'Samsung', 2200000, 35, 'M.2 NVMe, 7000MB/s', NOW()),
('part_006', 'Corsair RM850x', 'corsair-psu', 'PSU', 'power_supply', 'Corsair', 1500000, 25, '850W, 80+ Gold', NOW()),
('part_007', 'Noctua NH-D15', 'noctua-cooler', 'Cooling', 'cooler', 'Noctua', 900000, 40, 'Air Cooler, 125W TDP', NOW()),
('part_008', 'Fractal Define 7', 'fractal-case', 'Case', 'case', 'Fractal', 1100000, 30, 'Mid Tower, ATX', NOW());

-- Insert Sample Orders for Testing
INSERT INTO orders (id, user_id, total_amount, status, created_at, updated_at) VALUES
('ord_001', 'test_user_1', 55000000, 'completed', NOW(), NOW()),
('ord_002', 'test_user_1', 12000000, 'pending', NOW(), NOW());

-- Insert Order Items
INSERT INTO order_items (id, order_id, part_id, quantity, price, created_at) VALUES
('oi_001', 'ord_001', 'part_001', 1, 4500000, NOW()),
('oi_002', 'ord_001', 'part_002', 1, 18000000, NOW()),
('oi_003', 'ord_002', 'part_004', 2, 3600000, NOW());

-- Insert Sample Reviews
INSERT INTO reviews (id, product_id, user_id, rating, comment, created_at) VALUES
('rev_001', 'prd_001', 'test_user_1', 5, 'Proses sangat cepat dan stabil. Perfect untuk gaming!', NOW()),
('rev_002', 'prd_002', 'test_user_1', 5, 'Render 4K smooth banget. DLSS 3 keren!', NOW()),
('rev_003', 'prd_004', 'test_user_1', 4, 'RAM-nya gepok, tapi harganya agak mahal', NOW());

-- Insert Wishlist for test user
INSERT INTO wishlist (id, user_id, part_id, added_at) VALUES
('wish_001', 'test_user_1', 'part_002', NOW()),
('wish_002', 'test_user_1', 'part_005', NOW());