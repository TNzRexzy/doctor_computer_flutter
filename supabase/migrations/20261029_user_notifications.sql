-- Notifikasi per user, disinkronkan antar perangkat.
-- Jalankan di Supabase Dashboard -> SQL Editor.
-- users.id = auth.uid()::text (lihat 20261024_harden_client_access.sql).

CREATE TABLE IF NOT EXISTS public.user_notifications (
  id            text PRIMARY KEY,
  user_id       character varying NOT NULL
                REFERENCES public.users(id) ON DELETE CASCADE,
  title         text NOT NULL,
  message       text NOT NULL,
  type          text NOT NULL DEFAULT 'general',
  action_route  text,
  action_label  text,
  is_read       boolean NOT NULL DEFAULT false,
  created_at    timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_notifications_user_created
  ON public.user_notifications (user_id, created_at DESC);

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

-- Setiap user hanya boleh mengakses notifikasinya sendiri.
DROP POLICY IF EXISTS user_notifications_select_own ON public.user_notifications;
CREATE POLICY user_notifications_select_own ON public.user_notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_notifications_insert_own ON public.user_notifications;
CREATE POLICY user_notifications_insert_own ON public.user_notifications
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_notifications_update_own ON public.user_notifications;
CREATE POLICY user_notifications_update_own ON public.user_notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_notifications_delete_own ON public.user_notifications;
CREATE POLICY user_notifications_delete_own ON public.user_notifications
  FOR DELETE TO authenticated
  USING (user_id = auth.uid()::text);
