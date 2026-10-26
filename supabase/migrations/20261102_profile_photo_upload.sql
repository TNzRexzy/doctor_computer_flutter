-- Upload foto profil (JPG/PNG/GIF) + foto pembeli di ulasan produk.
-- Jalankan di Supabase Dashboard -> SQL Editor. Idempotent.
-- users.id = auth.uid()::text (lihat 20261024_harden_client_access.sql).
--
-- Ringkasan:
--  1. Bucket storage 'profile-photos' (publik untuk dibaca, maks. 5 MB,
--     hanya image/jpeg, image/png, image/gif). Setiap user (client, cashier,
--     admin) hanya bisa upload/hapus di folder miliknya: <auth.uid()>/...
--  2. View 'review_author_avatars': memetakan id ulasan ke foto profil
--     pembeli supaya halaman produk bisa menampilkan foto pembeli tanpa
--     membuka akses baca ke tabel users.

-- ---------------------------------------------------------------------
-- 1. Storage: bucket foto profil
-- ---------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-photos',
  'profile-photos',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif'];

DROP POLICY IF EXISTS "Users upload own profile photo" ON storage.objects;
CREATE POLICY "Users upload own profile photo"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users delete own profile photo" ON storage.objects;
CREATE POLICY "Users delete own profile photo"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ---------------------------------------------------------------------
-- 2. Foto pembeli untuk ulasan (hanya review_id + URL foto)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW public.review_author_avatars AS
SELECT r.id AS review_id,
       u.profile_image_url
FROM public.reviews r
JOIN public.users u ON u.id = r.user_id
WHERE u.profile_image_url IS NOT NULL
  AND btrim(u.profile_image_url) <> '';

GRANT SELECT ON public.review_author_avatars TO anon, authenticated;
