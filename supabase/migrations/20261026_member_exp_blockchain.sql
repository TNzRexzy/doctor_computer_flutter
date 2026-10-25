-- Member EXP + blockchain ledger, written by the SERVER only.
-- Background: 20261024_harden_client_access.sql revoked every client write on
-- users.points and blockchain_blocks (clients could mint EXP). The app therefore
-- had no way left to add EXP or save blocks. This migration restores that through
-- SECURITY DEFINER functions the client can only call, never bypass:
--   * award_member_points()  internal helper: updates points/tier + appends a block
--   * award_minigame_exp()   RPC for minigames (fixed EXP per game, cooldown, daily cap)
--   * update_order_status()  now also writes a 'shopping' block when an order is delivered
-- Safe to re-run. Requires 20261024_harden_client_access.sql (is_staff etc).

CREATE INDEX IF NOT EXISTS idx_blockchain_blocks_user_index
  ON public.blockchain_blocks (user_id, block_index);

-- ------------------------------------------------------------
-- 1. Internal helper (not callable by clients)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.award_member_points(
  p_user_id text,
  p_exp integer,
  p_block_type text,
  p_title text,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_last public.blockchain_blocks%ROWTYPE;
  v_new_points integer;
  v_new_tier text;
  v_index integer;
  v_prev text;
  v_now bigint := (extract(epoch FROM clock_timestamp()) * 1000)::bigint;
  v_payload jsonb;
  v_hash text;
BEGIN
  IF p_exp IS NULL OR p_exp <= 0 THEN
    RAISE EXCEPTION 'EXP must be positive';
  END IF;

  -- Row lock serialises concurrent awards for the same user (block order + points).
  SELECT * INTO v_user FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Genesis block (index 0, hash A1B2) so the chain matches what the app expects.
  IF NOT EXISTS (
    SELECT 1 FROM public.blockchain_blocks WHERE user_id = p_user_id
  ) THEN
    INSERT INTO public.blockchain_blocks (
      user_id, block_index, block_type, title, data, previous_hash, hash,
      exp_earned, upgrade_tier, "timestamp"
    )
    VALUES (
      p_user_id, 0, 'genesis', 'Blok 0: Genesis Block',
      jsonb_build_object(
        'User', v_user.full_name, 'Exp', 0, 'Tier', 'Bronze',
        'Note', 'Genesis Block (Akun Baru Terdaftar)'
      ),
      '0000000000000000', 'A1B2', 0, 'Bronze', v_now
    );
  END IF;

  SELECT * INTO v_last
  FROM public.blockchain_blocks
  WHERE user_id = p_user_id
  ORDER BY block_index DESC
  LIMIT 1;

  v_index := v_last.block_index + 1;
  v_prev := v_last.hash;
  v_new_points := v_user.points + p_exp;
  v_new_tier := CASE
    WHEN v_new_points >= 1200 THEN 'platinum'
    WHEN v_new_points >= 600 THEN 'gold'
    WHEN v_new_points >= 300 THEN 'silver'
    ELSE 'bronze'
  END;

  v_payload := jsonb_build_object(
    'User', v_user.full_name,
    'Exp', v_new_points,
    'Tier', initcap(v_new_tier),
    'Tambahan Exp', '+' || p_exp || ' EXP',
    'Previous Hash', v_prev,
    'Timestamp', to_char(clock_timestamp() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
  ) || COALESCE(p_details, '{}'::jsonb);

  v_hash := encode(
    sha256(convert_to(v_index::text || v_now::text || v_payload::text || v_prev, 'UTF8')),
    'hex'
  );
  v_payload := v_payload || jsonb_build_object('New Hash', v_hash);

  INSERT INTO public.blockchain_blocks (
    user_id, block_index, block_type, title, data, previous_hash, hash,
    exp_earned, upgrade_tier, "timestamp"
  )
  VALUES (
    p_user_id, v_index, p_block_type, 'Blok ' || v_index || ': ' || p_title,
    v_payload, v_prev, v_hash, p_exp, initcap(v_new_tier), v_now
  );

  UPDATE public.users
  SET points = v_new_points,
      membership_tier = v_new_tier,
      updated_at = now()
  WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'awarded_exp', p_exp,
    'total_points', v_new_points,
    'tier', v_new_tier,
    'tier_upgraded', v_new_tier IS DISTINCT FROM v_user.membership_tier,
    'block_index', v_index
  );
END;
$$;

REVOKE ALL ON FUNCTION public.award_member_points(text, integer, text, text, jsonb)
  FROM PUBLIC, anon, authenticated;

-- ------------------------------------------------------------
-- 2. Minigame RPC
--    The server cannot watch a game being played, so it does not trust the
--    client for the amount: EXP per game is fixed here, repeats are rate
--    limited and the total per day is capped. Tune the numbers below.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.award_minigame_exp(
  p_game text,
  p_result jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := auth.uid()::text;
  v_exp integer;
  v_title text;
  v_score integer;
  v_last_play timestamptz;
  v_today_exp integer;
  v_day_start timestamptz;
  v_daily_cap constant integer := 300;                    -- max minigame EXP per day
  v_cooldown constant interval := interval '30 seconds';  -- min gap between plays of one game
  v_points integer;
  v_tier text;
  v_award jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  IF p_game = 'memory_match' THEN
    v_exp := 50;  v_title := 'Minigame (Memory Match)';
  ELSIF p_game = 'speed_repair' THEN
    v_exp := 40;  v_title := 'Minigame (Speed PC Repair)';
  ELSIF p_game = 'pc_quiz' THEN
    v_title := 'Minigame (Kuis PC)';
    v_score := COALESCE((p_result ->> 'score')::integer, 0);
    IF v_score < 0 OR v_score > 5 THEN
      RAISE EXCEPTION 'Invalid quiz score';
    END IF;
    v_exp := CASE WHEN v_score >= 2 THEN v_score * 20 ELSE 0 END;
  ELSE
    RAISE EXCEPTION 'Unknown minigame';
  END IF;

  SELECT points, membership_tier INTO v_points, v_tier
  FROM public.users WHERE id = v_uid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF v_exp <= 0 THEN
    RETURN jsonb_build_object('awarded_exp', 0, 'reason', 'not_passed',
      'total_points', v_points, 'tier', v_tier);
  END IF;

  SELECT max(created_at) INTO v_last_play
  FROM public.blockchain_blocks
  WHERE user_id = v_uid AND block_type = 'minigame' AND data ->> 'Game Key' = p_game;
  IF v_last_play IS NOT NULL AND now() - v_last_play < v_cooldown THEN
    RETURN jsonb_build_object('awarded_exp', 0, 'reason', 'cooldown',
      'total_points', v_points, 'tier', v_tier);
  END IF;

  v_day_start := date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta';
  SELECT COALESCE(sum(exp_earned), 0) INTO v_today_exp
  FROM public.blockchain_blocks
  WHERE user_id = v_uid AND block_type = 'minigame' AND created_at >= v_day_start;
  IF v_today_exp >= v_daily_cap THEN
    RETURN jsonb_build_object('awarded_exp', 0, 'reason', 'daily_cap',
      'total_points', v_points, 'tier', v_tier);
  END IF;
  v_exp := LEAST(v_exp, v_daily_cap - v_today_exp);

  v_award := public.award_member_points(
    v_uid, v_exp, 'minigame', v_title,
    jsonb_build_object('Game', v_title, 'Game Key', p_game)
  );
  RETURN v_award;
END;
$$;

REVOKE ALL ON FUNCTION public.award_minigame_exp(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.award_minigame_exp(text, jsonb) TO authenticated;

-- ------------------------------------------------------------
-- 3. Shopping EXP: same 500 points as before, now also written to the ledger.
--    Replaces update_order_status from 20261024_harden_client_access.sql
--    (same signature, so existing grants are kept).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_order_status(
  p_order_id varchar,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_item_name text;
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('processing', 'shipped', 'delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid order status';
  END IF;
  UPDATE public.orders SET status = p_status WHERE id = p_order_id
  RETURNING * INTO v_order;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.status = 'delivered'
     AND v_order.user_id IS NOT NULL
     AND v_order.points_awarded = 0 THEN
    v_item_name := COALESCE(v_order.items_summary -> 0 ->> 'product_name', 'Pesanan ' || v_order.id);
    PERFORM public.award_member_points(
      v_order.user_id, 500, 'shopping', 'Belanja (' || v_item_name || ')',
      jsonb_build_object('Item', v_item_name, 'Order', v_order.id)
    );
    UPDATE public.orders SET points_awarded = 500 WHERE id = p_order_id
    RETURNING * INTO v_order;
  END IF;
  RETURN to_jsonb(v_order);
END;
$$;
