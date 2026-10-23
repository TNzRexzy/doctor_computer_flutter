-- ============================================================
-- SUPABASE MIGRATION: Flash Sales (admin & kasir)
-- Jalankan di Supabase SQL Editor SETELAH 20261022_schema_sync_latest.sql
-- Aman dijalankan ulang (idempotent).
--
-- Konsep:
--   * products.price  = harga normal (TIDAK diubah oleh flash sale)
--   * flash_sales     = produk yang dipilih admin/kasir + harga flash,
--                       kuota, dan jadwal mulai/selesai
-- ============================================================

CREATE TABLE IF NOT EXISTS public.flash_sales (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id character varying NOT NULL,
  original_price numeric NOT NULL,
  flash_price numeric NOT NULL,
  discount_percent numeric GENERATED ALWAYS AS (
    round((original_price - flash_price) / NULLIF(original_price, 0) * 100, 2)
  ) STORED,
  flash_stock integer NOT NULL,
  sold_count integer NOT NULL DEFAULT 0,
  starts_at timestamp with time zone NOT NULL DEFAULT now(),
  ends_at timestamp with time zone NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_by character varying,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT flash_sales_pkey PRIMARY KEY (id),
  CONSTRAINT flash_sales_product_id_fkey FOREIGN KEY (product_id)
    REFERENCES public.products(id) ON DELETE CASCADE,
  CONSTRAINT flash_sales_price_chk CHECK (flash_price > 0 AND original_price > 0 AND flash_price < original_price),
  CONSTRAINT flash_sales_stock_chk CHECK (flash_stock > 0 AND sold_count >= 0 AND sold_count <= flash_stock),
  CONSTRAINT flash_sales_time_chk CHECK (ends_at > starts_at)
);

-- Satu produk hanya boleh punya satu flash sale aktif pada satu waktu
CREATE UNIQUE INDEX IF NOT EXISTS uq_flash_sales_one_active_per_product
  ON public.flash_sales (product_id) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_flash_sales_window ON public.flash_sales (is_active, starts_at, ends_at);

-- updated_at otomatis
CREATE OR REPLACE FUNCTION public.flash_sales_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_flash_sales_touch ON public.flash_sales;
CREATE TRIGGER trg_flash_sales_touch BEFORE UPDATE ON public.flash_sales
  FOR EACH ROW EXECUTE FUNCTION public.flash_sales_touch_updated_at();

-- RLS: semua orang boleh melihat, hanya admin & kasir boleh mengelola
ALTER TABLE public.flash_sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read flash sales" ON public.flash_sales;
CREATE POLICY "Public read flash sales" ON public.flash_sales FOR SELECT USING (true);
DROP POLICY IF EXISTS "Staff manage flash sales" ON public.flash_sales;
CREATE POLICY "Staff manage flash sales" ON public.flash_sales
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.users u
                 WHERE u.id = auth.uid()::varchar AND u.role IN ('admin', 'cashier')))
  WITH CHECK (EXISTS (SELECT 1 FROM public.users u
                      WHERE u.id = auth.uid()::varchar AND u.role IN ('admin', 'cashier')));

-- Dipanggil saat checkout (pembeli tidak punya hak tulis langsung ke tabel).
-- Menambah sold_count hanya untuk flash sale yang sedang berjalan.
CREATE OR REPLACE FUNCTION public.increment_flash_sale_sold(p_product_id character varying, p_qty integer)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.flash_sales
     SET sold_count = LEAST(flash_stock, sold_count + GREATEST(p_qty, 0))
   WHERE product_id = p_product_id
     AND is_active
     AND starts_at <= now()
     AND ends_at > now();
$$;
GRANT EXECUTE ON FUNCTION public.increment_flash_sale_sold(character varying, integer) TO anon, authenticated;

-- ------------------------------------------------------------
-- Migrasi data lama: sebelumnya flash sale "dibakar" ke products
-- (is_on_sale = true, price = harga promo, original_price = harga normal).
-- Pindahkan ke flash_sales (7 hari dari sekarang) lalu kembalikan harga normal.
-- Hanya memproses baris yang belum punya flash sale, jadi aman diulang.
-- ------------------------------------------------------------
WITH legacy AS (
  SELECT p.id, p.price AS promo_price, p.original_price AS normal_price, GREATEST(p.stock, 1) AS qty
  FROM public.products p
  WHERE p.is_on_sale = true
    AND p.original_price IS NOT NULL AND p.original_price > p.price
    AND NOT EXISTS (SELECT 1 FROM public.flash_sales f WHERE f.product_id = p.id AND f.is_active)
), ins AS (
  INSERT INTO public.flash_sales (product_id, original_price, flash_price, flash_stock, starts_at, ends_at)
  SELECT id, normal_price, promo_price, qty, now(), now() + interval '7 days' FROM legacy
  RETURNING product_id
)
UPDATE public.products p
   SET price = l.normal_price, original_price = NULL, is_on_sale = false
  FROM legacy l
 WHERE p.id = l.id;
-- Sisa produk dengan is_on_sale = true tanpa harga coret hanya dimatikan flag-nya
UPDATE public.products SET is_on_sale = false WHERE is_on_sale = true;
