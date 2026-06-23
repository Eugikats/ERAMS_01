-- Migration 011: Fix patient self-registration
--
-- Previously the auth trigger defaulted new users to role='driver' when no
-- role was supplied in the signup metadata.  Self-registered patients never
-- appeared in the trigger metadata, so they ended up as drivers.
--
-- Also removed the Flutter-side profiles upsert: it required an INSERT RLS
-- policy that didn't exist, causing a 403 on every self-registration and a
-- 429 (rate-limit) when the user retried.  The trigger (SECURITY DEFINER)
-- creates the complete profile row — the client never needs to INSERT.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, role, phone, email)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'role', 'patient'),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        COALESCE(NEW.email, '')
    );
    RETURN NEW;
END;
$$;
