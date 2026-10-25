-- Login dengan sidik jari (user, kasir, admin).
-- Jalankan di Supabase Dashboard -> SQL Editor. Idempotent.
-- users.id = auth.uid()::text (lihat 20261024_harden_client_access.sql).
--
-- Tabel user_biometrics & user_security_settings sudah ada di database;
-- CREATE TABLE IF NOT EXISTS di bawah hanya agar repo bisa mereproduksinya.
-- Kredensial TIDAK disimpan di database: email+password disimpan terenkripsi
-- (Android Keystore) di perangkat. Database hanya mencatat pendaftaran
-- sidik jari per perangkat (biometric_token = ID acak, bukan rahasia login).

CREATE TABLE IF NOT EXISTS public.user_biometrics (
  id              character varying NOT NULL DEFAULT (gen_random_uuid())::text,
  user_id         character varying NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  biometric_type  character varying NOT NULL,
  credential_name character varying NOT NULL,
  device_model    character varying,
  biometric_token character varying NOT NULL,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  last_used_at    timestamp with time zone,
  CONSTRAINT user_biometrics_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.user_security_settings (
  user_id               character varying NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  biometric_enabled     boolean NOT NULL DEFAULT false,
  biometric_for_payment boolean NOT NULL DEFAULT false,
  pin_enabled           boolean NOT NULL DEFAULT false,
  pin_hash              character varying,
  pin_for_payment       boolean NOT NULL DEFAULT false,
  two_factor_enabled    boolean NOT NULL DEFAULT false,
  two_factor_method     character varying NOT NULL DEFAULT 'email',
  auto_lock_minutes     integer NOT NULL DEFAULT 0,
  login_notification    boolean NOT NULL DEFAULT true,
  created_at            timestamp with time zone NOT NULL DEFAULT now(),
  updated_at            timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_security_settings_pkey PRIMARY KEY (user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_biometrics_token
  ON public.user_biometrics (biometric_token);
CREATE INDEX IF NOT EXISTS idx_user_biometrics_user
  ON public.user_biometrics (user_id, is_active);

-- ---------- user_biometrics: hanya milik sendiri ----------
ALTER TABLE public.user_biometrics ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_biometrics FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_biometrics TO authenticated;

DROP POLICY IF EXISTS user_biometrics_select_own ON public.user_biometrics;
CREATE POLICY user_biometrics_select_own ON public.user_biometrics
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_biometrics_insert_own ON public.user_biometrics;
CREATE POLICY user_biometrics_insert_own ON public.user_biometrics
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_biometrics_update_own ON public.user_biometrics;
CREATE POLICY user_biometrics_update_own ON public.user_biometrics
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_biometrics_delete_own ON public.user_biometrics;
CREATE POLICY user_biometrics_delete_own ON public.user_biometrics
  FOR DELETE TO authenticated
  USING (user_id = auth.uid()::text);

-- ---------- user_security_settings: hanya milik sendiri ----------
ALTER TABLE public.user_security_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_security_settings FROM anon;
GRANT SELECT, INSERT, UPDATE ON public.user_security_settings TO authenticated;

DROP POLICY IF EXISTS user_security_settings_select_own ON public.user_security_settings;
CREATE POLICY user_security_settings_select_own ON public.user_security_settings
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_security_settings_insert_own ON public.user_security_settings;
CREATE POLICY user_security_settings_insert_own ON public.user_security_settings
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_security_settings_update_own ON public.user_security_settings;
CREATE POLICY user_security_settings_update_own ON public.user_security_settings
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);
