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

UPDATE public.user_notifications
SET
  title = 'Pembaruan pesanan #' ||
    CASE
      WHEN order_id LIKE 'DC-%' THEN left(order_id, 11) || '…'
      ELSE left(order_id, 12) ||
        CASE WHEN length(order_id) > 12 THEN '…' ELSE '' END
    END,
  message = 'Pesanan #' ||
    CASE
      WHEN order_id LIKE 'DC-%' THEN left(order_id, 11) || '…'
      ELSE left(order_id, 12) ||
        CASE WHEN length(order_id) > 12 THEN '…' ELSE '' END
    END ||
    CASE metadata->>'status'
      WHEN 'processing' THEN ' sedang diproses'
      WHEN 'shipped' THEN ' telah diserahkan ke kurir dan sedang dikirim'
      WHEN 'delivered' THEN ' telah diterima'
      WHEN 'cancelled' THEN ' telah dibatalkan'
      ELSE ' diperbarui ke status ' || COALESCE(metadata->>'status', 'unknown')
    END || '.'
WHERE metadata->>'event_source' = 'order_status'
  AND order_id IS NOT NULL;
