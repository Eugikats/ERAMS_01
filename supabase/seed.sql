-- ERAMS Demo Seed Data
-- Applies after migrations. Run via: supabase db reset
-- or manually: psql <connection_string> -f supabase/seed.sql

-- TODO(phase-1): add demo hospitals (Healthstone Banda + Mulago coordinates)
-- TODO(phase-1): add demo ambulances at varying positions around Kampala
-- TODO(phase-1): add one demo user account per role (dispatcher, driver, hospital, admin)

-- Example structure (fill in real data in Phase 1):
--
-- INSERT INTO public.hospitals (id, name, address, location, contact_phone) VALUES
--   ('...', 'Healthstone Hospital', 'Banda, Nakawa Division, Kampala',
--    ST_GeogFromText('POINT(32.6406 0.3476)'), '+256-xxx-xxx-xxx'),
--   ('...', 'Mulago National Referral Hospital', 'Upper Mulago Hill Road, Kampala',
--    ST_GeogFromText('POINT(32.5733 0.3350)'), '0800-100036');
