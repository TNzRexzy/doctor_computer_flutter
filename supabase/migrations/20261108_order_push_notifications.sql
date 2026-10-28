-- Persist order-status notifications and FCM device tokens.
-- Run after 20261029_user_notifications.sql.

-- Remove the courier live-location objects from the earlier draft, if it was
-- applied before live location was removed from the requirement.
DROP TRIGGER IF EXISTS clear_order_live_location_when_not_shipped
  ON public.orders;
DROP FUNCTION IF EXISTS public.clear_order_live_location_when_not_shipped();
DROP TABLE IF EXISTS public.order_live_locations;

ALTER TABLE public.user_notifications
  ADD COLUMN IF NOT EXISTS order_id text,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.user_push_tokens (
  token      text PRIMARY KEY,
  user_id    varchar(50) NOT NULL
             REFERENCES public.users(id) ON DELETE CASCADE,
  platform   text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_push_tokens_select_own ON public.user_push_tokens;
CREATE POLICY user_push_tokens_select_own ON public.user_push_tokens
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_push_tokens_insert_own ON public.user_push_tokens;
CREATE POLICY user_push_tokens_insert_own ON public.user_push_tokens
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_push_tokens_update_own ON public.user_push_tokens;
CREATE POLICY user_push_tokens_update_own ON public.user_push_tokens
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS user_push_tokens_delete_own ON public.user_push_tokens;
CREATE POLICY user_push_tokens_delete_own ON public.user_push_tokens
  FOR DELETE TO authenticated
  USING (user_id = auth.uid()::text);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_push_tokens TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_notifications TO authenticated;

CREATE OR REPLACE FUNCTION public.notify_customer_order_status_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status_message text;
  v_display_order_id text;
BEGIN
  IF NEW.user_id IS NULL OR NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  v_display_order_id := CASE
    WHEN NEW.id LIKE 'DC-%' THEN left(NEW.id, 11) || '…'
    ELSE left(NEW.id, 12) || CASE WHEN length(NEW.id) > 12 THEN '…' ELSE '' END
  END;

  v_status_message := CASE NEW.status
    WHEN 'processing' THEN 'sedang diproses'
    WHEN 'shipped' THEN 'telah diserahkan ke kurir dan sedang dikirim'
    WHEN 'delivered' THEN 'telah diterima'
    WHEN 'cancelled' THEN 'telah dibatalkan'
    ELSE 'diperbarui ke status ' || NEW.status
  END;

  INSERT INTO public.user_notifications (
    id, user_id, title, message, type, action_route, action_label,
    is_read, created_at, order_id, metadata
  )
  VALUES (
    gen_random_uuid()::text,
    NEW.user_id,
    'Pembaruan pesanan #' || v_display_order_id,
    'Pesanan #' || v_display_order_id || ' ' || v_status_message || '.',
    'order',
    '/order-history',
    'Lihat pesanan',
    false,
    now(),
    NEW.id::text,
    jsonb_build_object('event_source', 'order_status', 'status', NEW.status)
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_customer_order_status_changed()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS notify_customer_order_status_changed ON public.orders;
CREATE TRIGGER notify_customer_order_status_changed
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.notify_customer_order_status_changed();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'user_notifications'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.user_notifications;
    END IF;
  END IF;
END;
$$;
