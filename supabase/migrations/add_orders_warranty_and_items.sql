-- ============================================================
-- DOCTOR COMPUTER — ORDERS & WARRANTY SCHEMA EXTENSION
-- Jalankan skrip ini di SQL Editor Supabase untuk melengkapi
-- kolom resi, kurir, garansi, rating, dan ringkasan item pesanan.
-- ============================================================

-- 1. Tambah kolom pelengkap ke tabel orders jika belum ada
ALTER TABLE orders 
  ADD COLUMN IF NOT EXISTS tracking_number VARCHAR(100) DEFAULT 'JNE-DC98124982',
  ADD COLUMN IF NOT EXISTS courier VARCHAR(100) DEFAULT 'JNE Reguler',
  ADD COLUMN IF NOT EXISTS serial_number VARCHAR(100) DEFAULT 'SN-DC2026-00918',
  ADD COLUMN IF NOT EXISTS warranty_months INTEGER DEFAULT 24,
  ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2),
  ADD COLUMN IF NOT EXISTS review_comment TEXT,
  ADD COLUMN IF NOT EXISTS rated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS items_summary JSONB DEFAULT '[]'::jsonb;

-- 2. Pastikan tabel order_items ada untuk menyimpan detail barang
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id VARCHAR(50) REFERENCES orders(id) ON DELETE CASCADE,
  product_id VARCHAR(50) REFERENCES products(id) ON DELETE SET NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC(14,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Enable RLS. The hardened policies are installed by
-- 20261024_harden_client_access.sql after staff role helpers exist.
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
