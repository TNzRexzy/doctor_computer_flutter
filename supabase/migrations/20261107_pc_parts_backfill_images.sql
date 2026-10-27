-- Rakit PC: isi gambar pc_parts yang masih kosong dari produk dengan nama yang
-- sama di tabel products (foto diunggah saat input produk). Aman dijalankan
-- berulang; hanya mengisi baris yang image_url-nya kosong.

UPDATE public.pc_parts pp
SET image_url = src.first_image
FROM (
  SELECT DISTINCT ON (lower(trim(p.name)))
         lower(trim(p.name)) AS name_key,
         p.image_url[1]      AS first_image
  FROM public.products p
  WHERE p.image_url IS NOT NULL
    AND array_length(p.image_url, 1) >= 1
    AND coalesce(trim(p.image_url[1]), '') <> ''
  ORDER BY lower(trim(p.name)), p.created_at DESC
) src
WHERE lower(trim(pp.name)) = src.name_key
  AND coalesce(trim(pp.image_url), '') = '';
