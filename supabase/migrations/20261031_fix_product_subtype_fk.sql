-- Fix: "Produk gagal disimpan ... violates foreign key constraint fk_products_subtype"
--
-- Penyebab: aplikasi Flutter tidak pernah mengirim subtype / brand_code / sku.
-- Nilai subtype yang ditolak FK berasal dari sisi database (trigger/default
-- manual di Supabase), dan tidak ada di product_subtypes.
--
-- Migration ini membuat trigger pengaman yang berjalan TERAKHIR ("zz_"):
--  * products: subtype tidak valid -> diisi dari category_id, fallback 'GEN'
--  * brand_code tidak valid -> NULL
--  * pc_parts: subtype/brand_code tidak valid -> NULL
-- Idempotent: aman dijalankan ulang. Kode aplikasi tidak diubah.

-- ---------- products ----------
CREATE OR REPLACE FUNCTION public.trg_products_normalize_codes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.subtype IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.product_subtypes s WHERE s.code = NEW.subtype) THEN
    NEW.subtype := CASE
      WHEN NEW.category_id = 'laptop'   THEN 'LTP'
      WHEN NEW.category_id = 'monitor'  THEN 'MON'
      WHEN NEW.category_id = 'keyboard' THEN 'KBD'
      WHEN NEW.category_id = 'mouse'    THEN 'MOU'
      WHEN NEW.category_id = 'headset'  THEN 'HDS'
      WHEN NEW.category_id = 'storage'  AND NEW.name ILIKE '%ssd%' THEN 'SSD'
      WHEN NEW.category_id = 'storage'  AND (NEW.name ILIKE '%hdd%' OR NEW.name ILIKE '%hard disk%') THEN 'HDD'
      ELSE 'GEN'
    END;
  END IF;

  IF NEW.brand_code IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.brands b WHERE b.code = NEW.brand_code) THEN
    NEW.brand_code := NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS zz_products_normalize_codes ON public.products;
CREATE TRIGGER zz_products_normalize_codes
  BEFORE INSERT OR UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.trg_products_normalize_codes();

-- ---------- pc_parts ----------
CREATE OR REPLACE FUNCTION public.trg_pc_parts_normalize_codes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.subtype IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.product_subtypes s WHERE s.code = NEW.subtype) THEN
    NEW.subtype := NULL;
  END IF;

  IF NEW.brand_code IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.brands b WHERE b.code = NEW.brand_code) THEN
    NEW.brand_code := NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS zz_pc_parts_normalize_codes ON public.pc_parts;
CREATE TRIGGER zz_pc_parts_normalize_codes
  BEFORE INSERT OR UPDATE ON public.pc_parts
  FOR EACH ROW EXECUTE FUNCTION public.trg_pc_parts_normalize_codes();

-- Fungsi lama dari versi sebelumnya tidak dipakai lagi.
DROP FUNCTION IF EXISTS public.trg_normalize_catalog_codes();
