/*
# Add missing columns to orders + create get_client_orders and append_order_status functions
*/

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'transaction_id') THEN
    ALTER TABLE orders ADD COLUMN transaction_id text;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'paid_at') THEN
    ALTER TABLE orders ADD COLUMN paid_at timestamptz;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'visible_to_client') THEN
    ALTER TABLE orders ADD COLUMN visible_to_client boolean DEFAULT true;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'archived_at') THEN
    ALTER TABLE orders ADD COLUMN archived_at timestamptz;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'cancellation_reason') THEN
    ALTER TABLE orders ADD COLUMN cancellation_reason text;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_orders_visible_to_client ON orders(visible_to_client);
CREATE INDEX IF NOT EXISTS idx_orders_telegram_visible ON orders(telegram_user_id, visible_to_client);

-- get_client_orders function
CREATE OR REPLACE FUNCTION get_client_orders(p_telegram_user_id bigint)
RETURNS TABLE (
  id uuid,
  telegram_user_id bigint,
  items jsonb,
  total_amount numeric,
  status text,
  customer_info jsonb,
  delivery_type text,
  delivery_cost numeric,
  payment_method text,
  notes text,
  created_at timestamptz,
  updated_at timestamptz,
  status_history jsonb,
  deleted_at timestamptz,
  coupon_id uuid,
  discount_amount numeric,
  transaction_id text,
  paid_at timestamptz,
  visible_to_client boolean,
  archived_at timestamptz,
  cancellation_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT o.id, o.telegram_user_id, o.items, o.total_amount, o.status,
    o.customer_info, o.delivery_type, o.delivery_cost, o.payment_method,
    o.notes, o.created_at, o.updated_at, o.status_history, o.deleted_at,
    o.coupon_id, o.discount_amount, o.transaction_id, o.paid_at,
    o.visible_to_client, o.archived_at, o.cancellation_reason
  FROM orders o
  WHERE o.telegram_user_id = p_telegram_user_id
    AND o.visible_to_client = true
    AND o.deleted_at IS NULL
  ORDER BY o.created_at DESC
  LIMIT 50;
END;
$$;

-- append_order_status function
CREATE OR REPLACE FUNCTION append_order_status(
  p_order_id text,
  p_status text,
  p_changed_by text,
  p_note text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
  v_should_archive boolean := false;
BEGIN
  IF p_status IN ('cancelled', 'delivered', 'returned') THEN
    v_should_archive := true;
  END IF;

  UPDATE orders
  SET status = p_status,
      status_history = COALESCE(status_history, '[]'::jsonb) || jsonb_build_array(
        jsonb_build_object(
          'status', p_status,
          'changed_at', now()::text,
          'changed_by', p_changed_by,
          'note', p_note
        )
      ),
      updated_at = now(),
      visible_to_client = CASE WHEN v_should_archive THEN false ELSE visible_to_client END,
      archived_at = CASE WHEN v_should_archive THEN now() ELSE archived_at END,
      cancellation_reason = CASE
        WHEN p_status = 'cancelled' AND p_note IS NOT NULL THEN p_note
        ELSE cancellation_reason
      END
  WHERE id::text = p_order_id
  RETURNING jsonb_build_object(
    'id', id, 'status', status, 'total_amount', total_amount,
    'status_history', status_history, 'customer_info', customer_info,
    'delivery_type', delivery_type, 'delivery_cost', delivery_cost,
    'payment_method', payment_method, 'notes', notes,
    'created_at', created_at, 'updated_at', updated_at,
    'visible_to_client', visible_to_client, 'archived_at', archived_at,
    'cancellation_reason', cancellation_reason, 'telegram_user_id', telegram_user_id
  ) INTO v_result;

  RETURN v_result;
END;
$$;
