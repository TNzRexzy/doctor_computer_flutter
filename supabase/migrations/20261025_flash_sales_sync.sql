-- Flash sale sync: aplikasi membaca/menulis timer flash sale dari tabel public.flash_sales
-- (sebelumnya timer hanya disimpan lokal di SharedPreferences, default 8 jam).
-- Jalankan di Supabase SQL Editor. Aman dijalankan ulang.
-- Membutuhkan fungsi public.is_staff() dari 20261024_harden_client_access.sql.

-- 1. Satu baris per produk (dibutuhkan upsert onConflict: product_id).
--    Jika ada duplikat lama, simpan baris terbaru saja.
DELETE FROM public.flash_sales a
USING public.flash_sales b
WHERE a.product_id = b.product_id
  AND (a.created_at, a.id) < (b.created_at, b.id);

CREATE UNIQUE INDEX IF NOT EXISTS flash_sales_product_id_key
  ON public.flash_sales (product_id);

-- 2. RLS: semua orang boleh melihat, hanya admin/kasir yang boleh mengubah.
ALTER TABLE public.flash_sales ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS flash_sales_select_public ON public.flash_sales;
CREATE POLICY flash_sales_select_public ON public.flash_sales
  FOR SELECT TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS flash_sales_manage_staff ON public.flash_sales;
CREATE POLICY flash_sales_manage_staff ON public.flash_sales
  FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

GRANT SELECT ON public.flash_sales TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.flash_sales TO authenticated;

-- 3. Realtime: perubahan timer langsung sampai ke semua perangkat.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'flash_sales'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.flash_sales;
  END IF;
END;
$$;
