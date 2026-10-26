-- Ulasan produk per item pesanan (foto + video), rating produk dari data asli.
-- Jalankan di Supabase Dashboard -> SQL Editor. Idempotent.
-- users.id = auth.uid()::text (lihat 20261024_harden_client_access.sql).
--
-- Ringkasan:
--  1. reviews: kolom order_id, media_urls, updated_at + satu ulasan per
--     (pesanan, produk, user).
--  2. RPC submit_product_review: satu-satunya jalur menulis ulasan. Hanya
--     untuk pesanan milik user yang berstatus 'delivered' dan berisi produk
--     tersebut. Boleh diubah maksimal 7 hari sejak ulasan pertama.
--  3. Trigger: products.rating & products.review_count dihitung otomatis
--     dari tabel reviews (rata-rata 1 desimal), bukan angka karangan.
--  4. Bucket storage 'review-media' (foto & video) - user hanya bisa
--     upload/hapus di folder miliknya: <auth.uid()>/...
--  5. Backfill: rating & jumlah ulasan semua produk dihitung ulang dari
--     reviews (produk tanpa ulasan menjadi 0 / 0).

-- ---------------------------------------------------------------------
-- 1. Kolom & indeks
-- ---------------------------------------------------------------------
ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS order_id   character varying
    REFERENCES public.orders(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS media_urls text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone;

ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_rating_range;
ALTER TABLE public.reviews
  ADD CONSTRAINT reviews_rating_range CHECK (rating >= 1 AND rating <= 5);

CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_order_product_user
  ON public.reviews (order_id, product_id, user_id)
  WHERE order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reviews_product_date
  ON public.reviews (product_id, date DESC);

-- ---------------------------------------------------------------------
-- 2. RLS: ulasan bisa dibaca publik; penulisan hanya lewat RPC
-- ---------------------------------------------------------------------
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reviews_select_all ON public.reviews;
CREATE POLICY reviews_select_all ON public.reviews
  FOR SELECT TO anon, authenticated
  USING (true);

GRANT SELECT ON public.reviews TO anon, authenticated;
-- Balasan penjual tetap lewat policy staff_update_reviews (UPDATE).
REVOKE INSERT, DELETE ON public.reviews FROM anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Rating produk dihitung dari reviews
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalc_product_rating(p_product_id varchar)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  UPDATE public.products p
  SET rating = COALESCE((
        SELECT round(avg(r.rating)::numeric, 1)
        FROM public.reviews r WHERE r.product_id = p.id
      ), 0),
      review_count = (
        SELECT count(*)::integer
        FROM public.reviews r WHERE r.product_id = p.id
      )
  WHERE p.id = p_product_id;
$$;
REVOKE ALL ON FUNCTION public.recalc_product_rating(varchar) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.trg_reviews_recalc_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.product_id IS NOT NULL THEN
    PERFORM public.recalc_product_rating(NEW.product_id);
  END IF;
  IF TG_OP IN ('UPDATE', 'DELETE') AND OLD.product_id IS NOT NULL
     AND (TG_OP = 'DELETE' OR OLD.product_id IS DISTINCT FROM NEW.product_id) THEN
    PERFORM public.recalc_product_rating(OLD.product_id);
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS reviews_recalc_rating ON public.reviews;
CREATE TRIGGER reviews_recalc_rating
  AFTER INSERT OR UPDATE OF rating, product_id OR DELETE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.trg_reviews_recalc_rating();

-- ---------------------------------------------------------------------
-- 4. RPC: kirim / ubah ulasan satu item pesanan
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_product_review(
  p_order_id   varchar,
  p_product_id varchar,
  p_rating     numeric,
  p_comment    text,
  p_media_urls text[] DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    text := auth.uid()::text;
  v_review public.reviews%ROWTYPE;
  v_name   text;
  v_url    text;
  v_media  text[] := COALESCE(p_media_urls, '{}');
  v_prefix text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'Rating must be between 1 and 5';
  END IF;
  p_comment := btrim(COALESCE(p_comment, ''));
  IF length(p_comment) > 2000 THEN
    RAISE EXCEPTION 'Comment is too long';
  END IF;
  IF COALESCE(array_length(v_media, 1), 0) > 6 THEN
    RAISE EXCEPTION 'Too many media files';
  END IF;

  -- Media harus berasal dari folder milik user di bucket review-media.
  v_prefix := '/storage/v1/object/public/review-media/' || v_uid || '/';
  FOREACH v_url IN ARRAY v_media LOOP
    IF position(v_prefix IN v_url) = 0 THEN
      RAISE EXCEPTION 'Invalid media URL';
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.order_items oi ON oi.order_id = o.id
    WHERE o.id = p_order_id
      AND o.user_id = v_uid
      AND o.status = 'delivered'
      AND oi.product_id = p_product_id
  ) THEN
    RAISE EXCEPTION 'Product cannot be reviewed by this user' USING ERRCODE = '42501';
  END IF;

  SELECT full_name INTO v_name FROM public.users WHERE id = v_uid;

  SELECT * INTO v_review
  FROM public.reviews
  WHERE order_id = p_order_id AND product_id = p_product_id AND user_id = v_uid
  FOR UPDATE;

  IF FOUND THEN
    IF v_review.date < now() - interval '7 days' THEN
      RAISE EXCEPTION 'Review edit window has passed' USING ERRCODE = '42501';
    END IF;
    UPDATE public.reviews
    SET rating = p_rating,
        comment = p_comment,
        media_urls = v_media,
        updated_at = now()
    WHERE id = v_review.id
    RETURNING * INTO v_review;
  ELSE
    INSERT INTO public.reviews
      (id, user_id, product_id, order_id, rating, comment, media_urls, user_name)
    VALUES
      (gen_random_uuid()::text, v_uid, p_product_id, p_order_id, p_rating,
       p_comment, v_media, COALESCE(NULLIF(v_name, ''), 'Pelanggan'))
    RETURNING * INTO v_review;
  END IF;

  RETURN to_jsonb(v_review);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_product_review(varchar, varchar, numeric, text, text[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_product_review(varchar, varchar, numeric, text, text[])
  TO authenticated;

-- ---------------------------------------------------------------------
-- 5. Storage: bucket foto & video ulasan
-- ---------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'review-media',
  'review-media',
  true,
  52428800,
  ARRAY['image/jpeg', 'image/png', 'image/webp',
        'video/mp4', 'video/quicktime', 'video/webm']
)
ON CONFLICT (id) DO UPDATE
SET public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp',
                               'video/mp4', 'video/quicktime', 'video/webm'];

DROP POLICY IF EXISTS "Users upload own review media" ON storage.objects;
CREATE POLICY "Users upload own review media"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'review-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users delete own review media" ON storage.objects;
CREATE POLICY "Users delete own review media"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'review-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ---------------------------------------------------------------------
-- 6. Backfill: rating & jumlah ulasan semua produk dari data asli
-- ---------------------------------------------------------------------
UPDATE public.products p
SET rating = COALESCE((
      SELECT round(avg(r.rating)::numeric, 1)
      FROM public.reviews r WHERE r.product_id = p.id
    ), 0),
    review_count = (
      SELECT count(*)::integer
      FROM public.reviews r WHERE r.product_id = p.id
    );
