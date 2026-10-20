-- =====================================================
-- SUPABASE SEED DATA FOR DOCTOR COMPUTER APP
-- Run this in: Supabase Dashboard → SQL Editor → Run
-- =====================================================

-- =====================================================
-- 1. INSERT CATEGORIES
-- Columns: id, name, name_id, icon, product_count (product_count has default 0)
-- =====================================================
INSERT INTO categories (id, name, icon, product_count) VALUES
('cat-001', 'CPU', '⚡', 8),
('cat-002', 'GPU', '🎮', 12),
('cat-003', 'Motherboard', '🧩', 15),
('cat-004', 'RAM', '💾', 20),
('cat-005', 'Storage', '💿', 18),
('cat-006', 'PSU', '⚡', 10),
('cat-007', 'CPU Cooler', '❄️', 14),
('cat-008', 'Case', '📦', 16),
('cat-009', 'Peripherals', '🖥️', 25),
('cat-010', 'Laptop', '💻', 8)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 2. INSERT PRODUCTS with Images
-- image_url is ARRAY type - placeholder images from picsum.photos
-- =====================================================
INSERT INTO products (id, name, description, price, original_price, category_id, brand, image_url, rating, review_count, stock) VALUES
('prd-001', 'Intel Core i7-12700K', '12 cores, 20 threads, 5.0GHz boost, 20MB cache', 4500000, 4200000, 'cat-001', 'Intel', ARRAY['https://picsum.photos/seed/intel-cpu/400/300', 'https://picsum.photos/seed/intel-cpu-2/400/300'], 4.8, 23, 15),
('prd-002', 'NVIDIA RTX 4080', '16GB GDDR6X, DLSS 3, Ray Tracing, 2x HDMI 2.1', 18000000, 17000000, 'cat-002', 'NVIDIA', ARRAY['https://picsum.photos/seed/nvidia-gpu/400/300', 'https://picsum.photos/seed/nvidia-gpu-2/400/300'], 4.9, 35, 8),
('prd-003', 'MSI MAG B660 TOMAHAWK', 'DDR5, PCIe 5.0, WiFi 6E, ATX, 12+1+1 phases', 3200000, 3000000, 'cat-003', 'MSI', ARRAY['https://picsum.photos/seed/msi-motherboard/400/300'], 4.7, 18, 20),
('prd-004', 'Corsair Vengeance DDR5 32GB', '5600MHz, CL36, 2x16GB Kit, XMP 3.0', 1800000, 1650000, 'cat-004', 'Corsair', ARRAY['https://picsum.photos/seed/corsair-ram/400/300', 'https://picsum.photos/seed/corsair-ram-2/400/300'], 4.6, 42, 50),
('prd-005', 'Samsung 980 Pro 1TB', 'NVMe SSD, 7000MB/s read, 5100MB/s write', 2200000, 2000000, 'cat-005', 'Samsung', ARRAY['https://picsum.photos/seed/samsung-ssd/400/300'], 4.9, 56, 35),
('prd-006', 'Corsair RM850x 850W', '850W, 80+ Gold, Fully Modular, 10-year warranty', 1500000, 1400000, 'cat-006', 'Corsair', ARRAY['https://picsum.photos/seed/corsair-psu/400/300'], 4.8, 29, 25),
('prd-007', 'Noctua NH-D15', 'Dual-fan Air Cooler, 125W TDP, 2x NF-A15', 900000, 850000, 'cat-007', 'Noctua', ARRAY['https://picsum.photos/seed/noctua-cooler/400/300'], 4.9, 67, 40),
('prd-008', 'Fractal Design Define 7', 'Mid Tower Case, Sound Damped, Tempered Glass', 1100000, 1000000, 'cat-008', 'Fractal', ARRAY['https://picsum.photos/seed/fractal-case/400/300'], 4.7, 31, 30),
('prd-009', 'ASUS VivoBook 15 OLED', 'Intel i5-12450H, 8GB RAM, 512GB SSD, 15.6"', 8500000, 7800000, 'cat-010', 'ASUS', ARRAY['https://picsum.photos/seed/asus-laptop/400/300', 'https://picsum.photos/seed/asus-laptop-2/400/300'], 4.5, 28, 12),
('prd-010', 'Logitech G502 Hero', 'RGB Gaming Mouse, 16000 DPI, 11 Buttons', 750000, 650000, 'cat-009', 'Logitech', ARRAY['https://picsum.photos/seed/logitech-mouse/400/300'], 4.6, 52, 60)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 3. INSERT PC PARTS (for PC Builder)
-- Columns: id, name, category, brand, price, specs
-- =====================================================
INSERT INTO pc_parts (id, name, category, brand, price, specs) VALUES
('part-001', 'Intel Core i7-12700K', 'cat-001', 'Intel', 4500000, '{"socket":"LGA1700","cores":12,"threads":20,"boost":"5.0GHz"}'),
('part-002', 'NVIDIA GeForce RTX 4080', 'cat-002', 'NVIDIA', 18000000, '{"vram":"16GB GDDR6X","cores":9728,"boost":"2.51GHz"}'),
('part-003', 'MSI MAG B660 TOMAHAWK', 'cat-003', 'MSI', 3200000, '{"socket":"LGA1700","chipset":"B660","form":"ATX"}'),
('part-004', 'Corsair Vengeance DDR5 32GB', 'cat-004', 'Corsair', 1800000, '{"type":"DDR5","speed":"5600MHz","capacity":32}'),
('part-005', 'Samsung 980 Pro 1TB', 'cat-005', 'Samsung', 2200000, '{"interface":"PCIe 4.0","read":"7000MB/s","write":"5100MB/s"}'),
('part-006', 'Corsair RM850x 850W', 'cat-006', 'Corsair', 1500000, '{"wattage":850,"certification":"80+ Gold","modular":true}'),
('part-007', 'Noctua NH-D15', 'cat-007', 'Noctua', 900000, '{"sockets":["AM4","LGA1700"],"tdp":125,"noise":"24.6dB"}'),
('part-008', 'Fractal Design Define 7', 'cat-008', 'Fractal', 1100000, '{"form":"Mid Tower","motherboard":["ATX","mATX"],"psu":"ATX"}'),
('part-009', 'Logitech G502 Hero', 'cat-009', 'Logitech', 750000, '{"dpi":16000,"buttons":11,"weight":121}'),
('part-010', 'ASUS VivoBook 15 OLED', 'cat-010', 'ASUS', 8500000, '{"cpu":"Intel i5-12450H","ram":8,"storage":512}')
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 4. INSERT MEMBERSHIP TIERS
-- =====================================================
INSERT INTO membership_tiers (tier, name, required_points, discount_percent, benefits) VALUES
('bronze', 'Bronze', 0, 5, ARRAY['Basic support', 'Standard warranty']),
('silver', 'Silver', 500, 10, ARRAY['Priority support', 'Extended warranty', 'Special offers']),
('gold', 'Gold', 1000, 15, ARRAY['VIP support', '2-year warranty', 'Early access sales', 'Free shipping']),
('platinum', 'Platinum', 2000, 20, ARRAY['24/7 VVIP support', '3-year warranty', 'Exclusive events', 'Free accessories'])
ON CONFLICT (tier) DO NOTHING;

-- =====================================================
-- 5. VERIFY DATA
-- =====================================================
SELECT 'SUCCESS: Seed data inserted with images!' as status
UNION ALL
SELECT 'Categories: ' || COUNT(*) || ' rows' FROM categories
UNION ALL  
SELECT 'Products: ' || COUNT(*) || ' rows (with images)' FROM products
UNION ALL
SELECT 'PC Parts: ' || COUNT(*) || ' rows' FROM pc_parts
UNION ALL
SELECT 'Tiers: ' || COUNT(*) || ' rows' FROM membership_tiers;