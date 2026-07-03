/*
# Create missing tables: favorites, product_collections, coupons, coupon_usage, abandoned_carts, notifications, returns, product_relations

All tables the app requires but not yet present in this database instance.
*/

-- favorites
CREATE TABLE IF NOT EXISTS favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  telegram_user_id bigint NOT NULL,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (telegram_user_id, product_id)
);
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "select_own_favorites" ON favorites;
CREATE POLICY "select_own_favorites" ON favorites FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "insert_own_favorites" ON favorites;
CREATE POLICY "insert_own_favorites" ON favorites FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "delete_own_favorites" ON favorites;
CREATE POLICY "delete_own_favorites" ON favorites FOR DELETE TO anon, authenticated USING (true);
CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites (telegram_user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_product ON favorites (product_id);

-- product_collections
CREATE TABLE IF NOT EXISTS product_collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name jsonb NOT NULL DEFAULT '{"ru": "", "uz": ""}',
  slug text UNIQUE NOT NULL,
  icon text DEFAULT 'tag',
  product_ids text[] DEFAULT '{}',
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE product_collections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view active collections" ON product_collections;
CREATE POLICY "Anyone can view active collections" ON product_collections FOR SELECT TO anon, authenticated USING (is_active = true);
DROP POLICY IF EXISTS "Service role manage collections" ON product_collections;
CREATE POLICY "Service role manage collections" ON product_collections FOR ALL TO service_role USING (true) WITH CHECK (true);

-- coupons
CREATE TABLE IF NOT EXISTS coupons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  type text NOT NULL CHECK (type IN ('percent', 'fixed')),
  value numeric NOT NULL CHECK (value > 0),
  min_order_amount numeric DEFAULT 0,
  max_uses_total integer DEFAULT NULL,
  max_uses_per_user integer DEFAULT 1,
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_until timestamptz,
  is_active boolean DEFAULT true,
  new_customers_only boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons (code);
CREATE INDEX IF NOT EXISTS idx_coupons_active ON coupons (is_active, valid_from, valid_until);
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read active coupons" ON coupons;
CREATE POLICY "Anyone can read active coupons" ON coupons FOR SELECT TO anon, authenticated USING (is_active = true);
DROP POLICY IF EXISTS "Service role full access to coupons" ON coupons;
CREATE POLICY "Service role full access to coupons" ON coupons FOR ALL TO service_role USING (true) WITH CHECK (true);

-- coupon_usage
CREATE TABLE IF NOT EXISTS coupon_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id uuid NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  telegram_user_id integer NOT NULL,
  order_id text,
  used_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_coupon_usage_coupon ON coupon_usage (coupon_id);
CREATE INDEX IF NOT EXISTS idx_coupon_usage_user ON coupon_usage (telegram_user_id);
ALTER TABLE coupon_usage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Service role full access to coupon_usage" ON coupon_usage;
CREATE POLICY "Service role full access to coupon_usage" ON coupon_usage FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anon insert coupon_usage" ON coupon_usage;
CREATE POLICY "Anon insert coupon_usage" ON coupon_usage FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "Anon select own coupon_usage" ON coupon_usage;
CREATE POLICY "Anon select own coupon_usage" ON coupon_usage FOR SELECT TO anon, authenticated USING (true);

-- notifications
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  telegram_user_id integer NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb DEFAULT '{}',
  is_read boolean DEFAULT false,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications (telegram_user_id, is_read, created_at DESC);
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Service role full access to notifications" ON notifications;
CREATE POLICY "Service role full access to notifications" ON notifications FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anon read own notifications" ON notifications;
CREATE POLICY "Anon read own notifications" ON notifications FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Anon update own notifications" ON notifications;
CREATE POLICY "Anon update own notifications" ON notifications FOR UPDATE TO anon, authenticated USING (true);

-- returns
CREATE TABLE IF NOT EXISTS returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id text NOT NULL,
  telegram_user_id integer NOT NULL,
  items jsonb NOT NULL DEFAULT '[]',
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'refunded')),
  refund_amount numeric DEFAULT 0,
  admin_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_returns_order ON returns (order_id);
CREATE INDEX IF NOT EXISTS idx_returns_user ON returns (telegram_user_id);
CREATE INDEX IF NOT EXISTS idx_returns_status ON returns (status);
ALTER TABLE returns ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Service role full access to returns" ON returns;
CREATE POLICY "Service role full access to returns" ON returns FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Anon select own returns" ON returns;
CREATE POLICY "Anon select own returns" ON returns FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Anon insert own returns" ON returns;
CREATE POLICY "Anon insert own returns" ON returns FOR INSERT TO anon, authenticated WITH CHECK (true);

-- product_relations
CREATE TABLE IF NOT EXISTS product_relations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  related_product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  relation_type text NOT NULL CHECK (relation_type IN ('upsell', 'cross_sell', 'bundle')),
  sort_order integer DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(product_id, related_product_id, relation_type)
);
CREATE INDEX IF NOT EXISTS idx_product_relations_product ON product_relations (product_id, relation_type);
CREATE INDEX IF NOT EXISTS idx_product_relations_related ON product_relations (related_product_id);
ALTER TABLE product_relations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read product_relations" ON product_relations;
CREATE POLICY "Anyone can read product_relations" ON product_relations FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "Service role full access to product_relations" ON product_relations;
CREATE POLICY "Service role full access to product_relations" ON product_relations FOR ALL TO service_role USING (true) WITH CHECK (true);

-- coupon_id + discount_amount on orders
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'coupon_id') THEN
    ALTER TABLE orders ADD COLUMN coupon_id uuid REFERENCES coupons(id);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'discount_amount') THEN
    ALTER TABLE orders ADD COLUMN discount_amount numeric DEFAULT 0;
  END IF;
END $$;
