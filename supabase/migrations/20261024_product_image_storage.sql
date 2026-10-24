-- Public product image delivery with writes restricted to authenticated staff.
-- Run after add_admin_features.sql and 20261024_harden_client_access.sql.

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'assets',
  'assets',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DROP POLICY IF EXISTS "Staff upload product images" ON storage.objects;
CREATE POLICY "Staff upload product images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'assets'
  AND (storage.foldername(name))[1] = 'product-images'
  AND public.is_staff()
);

DROP POLICY IF EXISTS "Staff update product images" ON storage.objects;
CREATE POLICY "Staff update product images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'assets'
  AND (storage.foldername(name))[1] = 'product-images'
  AND public.is_staff()
)
WITH CHECK (
  bucket_id = 'assets'
  AND (storage.foldername(name))[1] = 'product-images'
  AND public.is_staff()
);

DROP POLICY IF EXISTS "Staff delete product images" ON storage.objects;
CREATE POLICY "Staff delete product images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'assets'
  AND (storage.foldername(name))[1] = 'product-images'
  AND public.is_staff()
);
