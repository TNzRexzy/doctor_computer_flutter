-- Flash sale berakhir -> produk kembali ke harga normal dan keluar dari flash sale.
-- Jalankan di Supabase Dashboard -> SQL Editor. Idempotent.
-- Membutuhkan tabel public.flash_sales (20261025_flash_sales_sync.sql) dan
-- fungsi order dari 20261024_harden_client_access.sql.
--
-- Ringkasan:
--  1. public.expire_flash_sales(): untuk setiap baris flash_sales yang
--     ends_at-nya sudah lewat, produk yang masih is_on_sale dikembalikan ke
--     harga normal (original_price), original_price dikosongkan,
--     is_on_sale = false, lalu baris flash_sales yang berakhir dihapus.
--     Mengembalikan jsonb [{product_id, price}, ...] produk yang diubah.
--     Aman dipanggil berulang kali dan oleh siapa saja: hanya flash sale yang
--     benar-benar sudah berakhir yang diproses.
--  2. public.create_order_internal(): isi fungsi sama persis dengan versi di
--     20261024_harden_client_access.sql, hanya ditambah satu baris
--     `PERFORM public.expire_flash_sales();` di awal sehingga checkout
--     (online maupun POS) tidak pernah memakai harga flash sale yang sudah
--     berakhir. Hak akses fungsi tidak berubah.

-- ---------------------------------------------------------------------
-- 1. expire_flash_sales()
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expire_flash_sales()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result jsonb;
BEGIN
  WITH expired AS (
    SELECT fs.product_id, fs.original_price AS normal_price
    FROM public.flash_sales fs
    WHERE fs.ends_at <= now()
  ),
  reverted AS (
    UPDATE public.products p
    SET price = CASE
          WHEN p.original_price IS NOT NULL AND p.original_price > p.price
            THEN p.original_price
          WHEN e.normal_price > p.price
            THEN e.normal_price
          ELSE p.price
        END,
        original_price = NULL,
        is_on_sale = false,
        updated_at = now()
    FROM expired e
    WHERE p.id = e.product_id
      AND p.is_on_sale = true
    RETURNING p.id AS product_id, p.price AS price
  ),
  cleaned AS (
    DELETE FROM public.flash_sales fs
    USING expired e
    WHERE fs.product_id = e.product_id
    RETURNING fs.product_id
  )
  SELECT COALESCE(
           jsonb_agg(jsonb_build_object('product_id', r.product_id, 'price', r.price)),
           '[]'::jsonb
         )
  INTO v_result
  FROM reverted r;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_flash_sales() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.expire_flash_sales() TO anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. create_order_internal(): panggil expire_flash_sales() sebelum menghitung harga
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_order_internal(
  p_items jsonb,
  p_shipping_address text,
  p_payment_method text,
  p_shipping_method text,
  p_channel text,
  p_expected_total numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id text := auth.uid()::text;
  v_order_id varchar(50) := 'DC-' || replace(gen_random_uuid()::text, '-', '');
  v_item record;
  v_product public.products%ROWTYPE;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_subtotal numeric(14,2) := 0;
  v_shipping numeric(14,2) := 0;
  v_total numeric(14,2);
  v_order public.orders%ROWTYPE;
  v_result jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  -- Flash sale yang timer-nya sudah berakhir dikembalikan ke harga normal
  -- sebelum harga dihitung, supaya pesanan tidak memakai harga flash sale lama.
  PERFORM public.expire_flash_sales();
  IF p_channel NOT IN ('online', 'pos') THEN
    RAISE EXCEPTION 'Invalid order channel';
  END IF;
  IF p_channel = 'pos' AND NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_channel = 'online' AND public.is_staff() THEN
    RAISE EXCEPTION 'Staff must create POS orders through the cashier flow' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) = 0
     OR jsonb_array_length(p_items) > 100 THEN
    RAISE EXCEPTION 'Order must contain between 1 and 100 items';
  END IF;
  IF p_payment_method IS NULL OR length(trim(p_payment_method)) = 0
     OR length(p_payment_method) > 50 THEN
    RAISE EXCEPTION 'Invalid payment method';
  END IF;
  IF (p_channel = 'online' AND p_payment_method NOT IN (
        'Transfer Bank BCA', 'Transfer Bank Mandiri', 'Transfer Bank BNI',
        'GoPay', 'OVO', 'Dana', 'ShopeePay', 'COD'
      ))
     OR (p_channel = 'pos' AND p_payment_method NOT IN ('Cash', 'QRIS', 'Debit BCA')) THEN
    RAISE EXCEPTION 'Unsupported payment method';
  END IF;

  IF p_channel = 'online' THEN
    IF p_shipping_address IS NULL OR length(trim(p_shipping_address)) < 5
       OR length(p_shipping_address) > 1000 THEN
      RAISE EXCEPTION 'Invalid shipping address';
    END IF;
    v_shipping := CASE p_shipping_method
      WHEN 'Reguler' THEN 15000
      WHEN 'Ekspres' THEN 30000
      WHEN 'Hari Ini' THEN 50000
      ELSE NULL
    END;
    IF v_shipping IS NULL THEN
      RAISE EXCEPTION 'Invalid shipping method';
    END IF;
  ELSE
    v_shipping := 0;
  END IF;

  FOR v_item IN
    SELECT value ->> 'product_id' AS product_id,
           sum((value ->> 'quantity')::integer)::integer AS quantity
    FROM jsonb_array_elements(p_items) AS item(value)
    GROUP BY value ->> 'product_id'
    ORDER BY value ->> 'product_id'
  LOOP
    IF v_item.product_id IS NULL OR v_item.quantity IS NULL
       OR v_item.quantity < 1 OR v_item.quantity > 1000 THEN
      RAISE EXCEPTION 'Invalid order item';
    END IF;

    SELECT p.* INTO v_product
    FROM public.products p
    WHERE p.id = v_item.product_id
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product % is not available', v_item.product_id;
    END IF;
    IF v_product.stock < v_item.quantity THEN
      RAISE EXCEPTION 'Insufficient stock for product %', v_item.product_id;
    END IF;

    UPDATE public.products
    SET stock = stock - v_item.quantity
    WHERE id = v_item.product_id;
    v_subtotal := v_subtotal + (v_product.price * v_item.quantity);
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'product_id', v_product.id,
      'product_name', v_product.name,
      'product_price', v_product.price,
      'product_image', COALESCE(v_product.image_url[1], ''),
      'category_id', COALESCE(v_product.category_id, ''),
      'brand', v_product.brand,
      'unit_price', v_product.price,
      'quantity', v_item.quantity
    ));
  END LOOP;

  v_total := v_subtotal + v_shipping;
  IF p_expected_total IS NOT NULL AND p_expected_total <> v_total THEN
    RAISE EXCEPTION 'Cart prices changed. Refresh the cart and try again.';
  END IF;
  INSERT INTO public.orders (
    id, user_id, cashier_id, total_price, status, shipping_address,
    payment_method, channel, courier, serial_number, items_summary
  )
  VALUES (
    v_order_id,
    CASE WHEN p_channel = 'online' THEN v_user_id ELSE NULL END,
    CASE WHEN p_channel = 'pos' THEN v_user_id ELSE NULL END,
    v_total,
    CASE WHEN p_channel = 'pos' THEN 'delivered' ELSE 'processing' END,
    CASE WHEN p_channel = 'pos' THEN 'Ambil di Toko (POS Kasir)' ELSE trim(p_shipping_address) END,
    p_payment_method,
    p_channel,
    CASE WHEN p_channel = 'pos' THEN 'POS Kasir' ELSE p_shipping_method END,
    'SN-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
    v_lines
  )
  RETURNING * INTO v_order;

  FOR v_line IN SELECT value FROM jsonb_array_elements(v_lines)
  LOOP
    INSERT INTO public.order_items (order_id, product_id, quantity, unit_price)
    VALUES (
      v_order_id,
      v_line ->> 'product_id',
      (v_line ->> 'quantity')::integer,
      (v_line ->> 'unit_price')::numeric
    );
  END LOOP;

  IF p_channel = 'pos' THEN
    UPDATE public.cashier_shifts
    SET total_sales = total_sales + v_total,
        total_orders = total_orders + 1
    WHERE cashier_id = v_user_id AND status = 'open';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Open a cashier shift before processing a sale';
    END IF;
  END IF;

  v_result := to_jsonb(v_order) || jsonb_build_object('items', v_lines);
  RETURN v_result;
END;
$$;
