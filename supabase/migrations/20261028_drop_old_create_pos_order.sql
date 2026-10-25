-- Fix PGRST203 "Could not choose the best candidate function" on POS checkout.
-- The database has two overloads of create_pos_order:
--   (character varying, numeric, character varying, jsonb)  <- old, created outside the repo migrations
--   (text, numeric, text, jsonb)                             <- current, from 20261024_harden_client_access.sql
-- PostgREST cannot choose between them, so drop the old one and keep the current one.

DROP FUNCTION IF EXISTS public.create_pos_order(character varying, numeric, character varying, jsonb);

-- Verify: should return exactly ONE row (text, numeric, text, jsonb).
-- SELECT oid::regprocedure FROM pg_proc
-- WHERE pronamespace = 'public'::regnamespace AND proname = 'create_pos_order';
