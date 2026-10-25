-- Konfigurasi aplikasi di database (mis. Gemini API key), bukan hardcode di kode.
-- Jalankan di Supabase Dashboard -> SQL Editor.
-- Setelah dijalankan, isi key lewat:
--   UPDATE public.app_config SET value = 'ISI_API_KEY_BARU' WHERE key = 'GEMINI_API_KEY';

CREATE TABLE IF NOT EXISTS public.app_config (
  key         text PRIMARY KEY,
  value       text NOT NULL DEFAULT '',
  description text,
  updated_at  timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Hanya user yang sudah login yang boleh membaca konfigurasi.
DROP POLICY IF EXISTS app_config_select_authenticated ON public.app_config;
CREATE POLICY app_config_select_authenticated ON public.app_config
  FOR SELECT TO authenticated
  USING (true);

-- Hanya admin yang boleh menambah/mengubah/menghapus.
DROP POLICY IF EXISTS app_config_admin_write ON public.app_config;
CREATE POLICY app_config_admin_write ON public.app_config
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

REVOKE ALL ON public.app_config FROM anon;
GRANT SELECT ON public.app_config TO authenticated;

INSERT INTO public.app_config (key, value, description)
VALUES (
  'GEMINI_API_KEY',
  '',
  'Google Gemini API key untuk Doctor AI & AI Smart Search'
)
ON CONFLICT (key) DO NOTHING;
