-- ============================================================
-- OAUTH SIGN-IN: referral capture for Google/Apple sign-ups
-- Run in the MARKETPLACE Supabase SQL Editor. Safe to re-run.
-- ============================================================
--
-- Email/password sign-up already attributes a referral by passing ?ref=<id>
-- into auth.signUp()'s user metadata, which the handle_new_user() trigger
-- reads. Supabase's OAuth sign-in (signInWithOAuth) has no equivalent way to
-- pass custom metadata through to the provider redirect, so a referral code
-- picked up on the sign-in page has to be "claimed" after the OAuth redirect
-- completes instead. This function does that claim, with the same safety
-- checks the trigger already applies (no self-referral, referrer must be a
-- real profile) plus one more: it will never overwrite an attribution that's
-- already set, so it can't be used to hijack an existing account's referral.
CREATE OR REPLACE FUNCTION public.claim_referral_code(p_ref uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR p_ref IS NULL OR p_ref = auth.uid() THEN RETURN; END IF;
  UPDATE profiles
  SET referred_by = p_ref
  WHERE id = auth.uid()
    AND referred_by IS NULL
    AND EXISTS (SELECT 1 FROM profiles WHERE id = p_ref);
END;
$$;

REVOKE ALL ON FUNCTION public.claim_referral_code(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_referral_code(uuid) TO authenticated;
