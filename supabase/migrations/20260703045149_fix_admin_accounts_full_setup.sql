/*
# Fix admin_accounts: add password_hash, session_token, verify_admin_password function

1. Changes to admin_accounts
   - Add password_hash (text) for bcrypt hashes
   - Add session_token (text) for session management
2. New function
   - verify_admin_password(p_email, p_password) — checks bcrypt hash, falls back to plain text
3. Set bcrypt hashes for existing accounts
*/

-- Add missing columns
ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS password_hash text;
ALTER TABLE admin_accounts ADD COLUMN IF NOT EXISTS session_token text;

-- Enable pgcrypto if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Set bcrypt hashes from plain text passwords
UPDATE admin_accounts
SET password_hash = crypt(password_plain, gen_salt('bf', 10))
WHERE password_plain IS NOT NULL AND password_hash IS NULL;

-- Create verify_admin_password function
CREATE OR REPLACE FUNCTION verify_admin_password(p_email text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_valid boolean := false;
BEGIN
  SELECT id, email, first_name, role, password_hash, password_plain, is_active
  INTO v_admin
  FROM admin_accounts
  WHERE email = lower(trim(p_email))
    AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'error', 'Admin not found');
  END IF;

  -- Check bcrypt hash
  IF v_admin.password_hash IS NOT NULL AND v_admin.password_hash LIKE '$2%' THEN
    IF crypt(p_password, v_admin.password_hash) = v_admin.password_hash THEN
      v_valid := true;
    END IF;
  ELSIF v_admin.password_plain IS NOT NULL AND v_admin.password_plain = p_password THEN
    v_valid := true;
  END IF;

  IF NOT v_valid THEN
    RETURN jsonb_build_object('valid', false, 'error', 'Invalid password');
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'id', v_admin.id,
    'email', v_admin.email,
    'first_name', v_admin.first_name,
    'role', v_admin.role
  );
END;
$$;
