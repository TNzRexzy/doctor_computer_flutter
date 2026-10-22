-- ============================================================
-- SUPABASE MIGRATION: Schema Synchronization & RLS Policies
-- Compatible with the latest Doctor Computer Database Schema
-- ============================================================

-- 1. Ensure Brands table exists and has RLS enabled
CREATE TABLE IF NOT EXISTS public.brands (
  code character varying NOT NULL,
  name character varying NOT NULL,
  CONSTRAINT brands_pkey PRIMARY KEY (code)
);
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read brands" ON public.brands FOR SELECT USING (true);

-- 2. Ensure Product Subtypes table exists and has RLS enabled
CREATE TABLE IF NOT EXISTS public.product_subtypes (
  code character varying NOT NULL,
  name character varying NOT NULL,
  CONSTRAINT product_subtypes_pkey PRIMARY KEY (code)
);
ALTER TABLE public.product_subtypes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read product subtypes" ON public.product_subtypes FOR SELECT USING (true);

-- 3. Ensure Membership Tiers table exists and has RLS enabled
CREATE TABLE IF NOT EXISTS public.membership_tiers (
  tier character varying NOT NULL,
  name character varying NOT NULL,
  required_points integer NOT NULL DEFAULT 0,
  discount_percent numeric NOT NULL DEFAULT 0.00,
  benefits text[] NOT NULL DEFAULT '{}'::text[],
  CONSTRAINT membership_tiers_pkey PRIMARY KEY (tier)
);
ALTER TABLE public.membership_tiers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read membership tiers" ON public.membership_tiers FOR SELECT USING (true);

-- Seed default membership tiers if empty
INSERT INTO public.membership_tiers (tier, name, required_points, discount_percent, benefits)
VALUES
  ('bronze', 'Bronze Member', 0, 0.00, ARRAY['Cashback poin belanja untuk setiap transaksi', 'Layanan bantuan konsultasi teknisi', 'Bonus voucher ulang tahun']),
  ('silver', 'Silver Member', 100, 5.00, ARRAY['Cashback poin belanja 1.5x', 'Gratis ongkir belanja > Rp 1.000.000', 'Prioritas antrian customer service']),
  ('gold', 'Gold Member', 500, 10.00, ARRAY['Diskon khusus 10% perakitan PC', 'Gratis ongkir belanja > Rp 500.000', 'Prioritas garansi & perbaikan ekspres']),
  ('platinum', 'Platinum Member', 1000, 20.00, ARRAY['Diskon maksimal 20% all transaksi', 'Gratis konsultasi teknisi pribadi 24/7', 'Akses awal rilis komponen langka'])
ON CONFLICT (tier) DO NOTHING;

-- 4. Ensure PC Builds table RLS policies
ALTER TABLE public.pc_builds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can create their own PC builds" ON public.pc_builds FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can view their own PC builds" ON public.pc_builds FOR SELECT USING (true);

-- 5. Helpful index for cart_items lookups
CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON public.cart_items (user_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_user_product ON public.cart_items (user_id, product_id);
