-- Limit each completed membership minigame to one reward every three days.
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
  v_daily_cap constant integer := 300;
  v_cooldown constant interval := interval '3 days';
  v_points integer;
  v_tier text;
  v_award jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  IF p_game = 'memory_match' THEN
    v_exp := 50;
    v_title := 'Minigame (Tilt Control: Ambil Komponen)';
  ELSIF p_game = 'speed_repair' THEN
    v_exp := 40;
    v_title := 'Minigame (Shake It: Bersihkan Debu)';
  ELSIF p_game = 'pc_quiz' THEN
    v_title := 'Minigame (Gyro Spin: Kalibrasi Kipas)';
    v_score := COALESCE((p_result ->> 'score')::integer, 0);
    IF v_score < 0 OR v_score > 5 THEN
      RAISE EXCEPTION 'Invalid quiz score';
    END IF;
    v_exp := CASE WHEN v_score >= 2 THEN v_score * 20 ELSE 0 END;
  ELSE
    RAISE EXCEPTION 'Unknown minigame';
  END IF;

  -- Serialize awards for a user so simultaneous requests cannot bypass cooldown.
  SELECT points, membership_tier INTO v_points, v_tier
  FROM public.users
  WHERE id = v_uid
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF v_exp <= 0 THEN
    RETURN jsonb_build_object('awarded_exp', 0, 'reason', 'not_passed',
      'total_points', v_points, 'tier', v_tier);
  END IF;

  SELECT max(created_at) INTO v_last_play
  FROM public.blockchain_blocks
  WHERE user_id = v_uid
    AND block_type = 'minigame'
    AND data ->> 'Game Key' = p_game;

  IF v_last_play IS NOT NULL AND now() < v_last_play + v_cooldown THEN
    RETURN jsonb_build_object(
      'awarded_exp', 0,
      'reason', 'cooldown',
      'next_available_at', v_last_play + v_cooldown,
      'total_points', v_points,
      'tier', v_tier
    );
  END IF;

  v_day_start := date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta')
    AT TIME ZONE 'Asia/Jakarta';
  SELECT COALESCE(sum(exp_earned), 0) INTO v_today_exp
  FROM public.blockchain_blocks
  WHERE user_id = v_uid
    AND block_type = 'minigame'
    AND created_at >= v_day_start;
  IF v_today_exp >= v_daily_cap THEN
    RETURN jsonb_build_object('awarded_exp', 0, 'reason', 'daily_cap',
      'total_points', v_points, 'tier', v_tier);
  END IF;
  v_exp := LEAST(v_exp, v_daily_cap - v_today_exp);

  v_award := public.award_member_points(
    v_uid, v_exp, 'minigame', v_title,
    jsonb_build_object('Game', v_title, 'Game Key', p_game)
  );
  RETURN v_award || jsonb_build_object(
    'next_available_at', now() + v_cooldown
  );
END;
$$;

REVOKE ALL ON FUNCTION public.award_minigame_exp(text, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.award_minigame_exp(text, jsonb)
  TO authenticated;

-- Only expose the authenticated user's own next-available timestamp.
CREATE OR REPLACE FUNCTION public.get_minigame_cooldown(p_game text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := auth.uid()::text;
  v_last_play timestamptz;
  v_cooldown constant interval := interval '3 days';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_game NOT IN ('memory_match', 'speed_repair', 'pc_quiz') THEN
    RAISE EXCEPTION 'Unknown minigame';
  END IF;

  SELECT max(created_at) INTO v_last_play
  FROM public.blockchain_blocks
  WHERE user_id = v_uid
    AND block_type = 'minigame'
    AND data ->> 'Game Key' = p_game;

  RETURN jsonb_build_object(
    'game', p_game,
    'server_now', now(),
    'next_available_at', CASE
      WHEN v_last_play IS NULL THEN NULL
      ELSE v_last_play + v_cooldown
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_minigame_cooldown(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_minigame_cooldown(text)
  TO authenticated;
