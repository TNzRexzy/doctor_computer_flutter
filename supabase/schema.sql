-- ============================================================
-- DOCTOR COMPUTER — SUPABASE SCHEMA
-- Sesuai dengan lib/data/models/ (user, product, cart, order,
-- pc_build, pc_part, review, membership) dan constants (fee, payment)
-- Tabel yang dibuat:
--   1. membership_tiers  — konfigurasi tiering (bronze/silver/gold/platinum)
--   2. categories        — kategori produk (laptop, desktop, monitor, dst)
--   3. products          — produk toko (laptop, desktop, monitor, keyboard, dst)
--   4. users             — akun + profil pengguna
--   5. cart_items        — keranjang belanja (user_id + product_id = unique)
--   6. orders            — riwayat pesanan
--   7. order_items       — detail item di dalam order
--   8. wishlist          — daftar produk yang disukai user
--   9. pc_parts          — komponen PC buatan (cpu/gpu/mobo/ram/storage/psu/case/cooler)
--  10. pc_builds         — custom PC build (pilihan bagian + service tier)
--  11. reviews           — ulasan produk
-- ============================================================

-- ---- helper trigger: auto-update updated_at ----
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- 1. MEMBERSHIP TIERS
-- ---------------------------------------------------------------------
CREATE TABLE membership_tiers (
  tier            varchar(20) PRIMARY KEY,
  name            varchar(50) NOT NULL,
  required_points integer NOT NULL DEFAULT 0,
  discount_percent numeric(4,2) NOT NULL DEFAULT 0.00,
  benefits        text[] NOT NULL DEFAULT '{}'
);

-- ---------------------------------------------------------------------
-- 2. CATEGORIES
-- ---------------------------------------------------------------------
CREATE TABLE categories (
  id          varchar(50) PRIMARY KEY,
  name        varchar(100) NOT NULL,
  name_id     varchar(50),            -- Indonesian display name
  icon        varchar(50) NOT NULL,   -- Material icon name (string)
  product_count integer NOT NULL DEFAULT 0
);

-- ---------------------------------------------------------------------
-- 3. PRODUCTS
-- ---------------------------------------------------------------------
CREATE TABLE products (
  id            varchar(50) PRIMARY KEY,
  name          varchar(100) NOT NULL,
  description   text NOT NULL,
  description_id text,
  price         numeric(14,2) NOT NULL,
  original_price numeric(14,2),        -- null jika tidak ada diskon
  category_id   varchar(50) REFERENCES categories(id) ON DELETE SET NULL,
  brand         varchar(50) NOT NULL,
  image_url     text[],                 -- List<String>
  specs         jsonb NOT NULL DEFAULT '{}',
  rating        numeric(3,2) NOT NULL DEFAULT 0.00,
  review_count  integer NOT NULL DEFAULT 0,
  stock         integer NOT NULL DEFAULT 0,
  is_new        boolean NOT NULL DEFAULT false,
  is_on_sale    boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz
);

-- ---------------------------------------------------------------------
-- 4. USERS
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id               varchar(50) PRIMARY KEY,
  full_name        varchar(100) NOT NULL,
  email            varchar(100) NOT NULL UNIQUE,
  phone            varchar(20),
  avatar_url       varchar(255),
  address          text,
  city             varchar(50),
  membership_tier  varchar(20) NOT NULL DEFAULT 'bronze',  -- refs membership_tiers
  points           integer NOT NULL DEFAULT 0,
  join_date        timestamptz NOT NULL DEFAULT now(),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz
);

-- ---------------------------------------------------------------------
-- 5. CART ITEMS
-- ---------------------------------------------------------------------
CREATE TABLE cart_items (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    varchar(50) REFERENCES users(id) ON DELETE CASCADE,
  product_id varchar(50) REFERENCES products(id) ON DELETE CASCADE,
  quantity   integer NOT NULL DEFAULT 1,
  added_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cart_unique_item UNIQUE (user_id, product_id)
);

-- ---------------------------------------------------------------------
-- 6. ORDERS
-- ---------------------------------------------------------------------
CREATE TABLE orders (
  id             varchar(50) PRIMARY KEY,
  user_id        varchar(50) REFERENCES users(id) ON DELETE CASCADE,
  total_price    numeric(14,2) NOT NULL,
  status         varchar(20) NOT NULL DEFAULT 'processing',  -- processing/shipped/delivered/cancelled
  order_date     timestamptz NOT NULL DEFAULT now(),
  shipping_address text NOT NULL,
  payment_method varchar(50) NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz
);

-- ---------------------------------------------------------------------
-- 7. ORDER ITEMS
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    varchar(50) REFERENCES orders(id) ON DELETE CASCADE,
  product_id  varchar(50) REFERENCES products(id) ON DELETE SET NULL,
  quantity    integer NOT NULL DEFAULT 1,
  unit_price  numeric(14,2) NOT NULL
);

-- ---------------------------------------------------------------------
-- 8. WISHLIST
-- ---------------------------------------------------------------------
CREATE TABLE wishlist (
  user_id    varchar(50) REFERENCES users(id) ON DELETE CASCADE,
  product_id varchar(50) REFERENCES products(id) ON DELETE CASCADE,
  added_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, product_id)
);

-- ---------------------------------------------------------------------
-- 9. PC PARTS (komponen custom build)
-- ---------------------------------------------------------------------
CREATE TABLE pc_parts (
  id                varchar(50) PRIMARY KEY,
  name              varchar(100) NOT NULL,
  category          varchar(20) NOT NULL,   -- cpu/gpu/motherboard/ram/storage/psu/pc_case/cooler
  brand             varchar(50) NOT NULL,
  price             numeric(14,2) NOT NULL,
  specs             jsonb NOT NULL DEFAULT '{}',
  image_url         varchar(255),
  compatibility_tags text[] NOT NULL DEFAULT '{}',
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 10. PC BUILDS (custom PC)
-- ---------------------------------------------------------------------
CREATE TABLE pc_builds (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            varchar(50) REFERENCES users(id) ON DELETE SET NULL,  -- null = guest
  cpu_id             varchar(50) REFERENCES pc_parts(id) ON DELETE SET NULL,
  gpu_id             varchar(50) REFERENCES pc_parts(id) ON DELETE SET NULL,
  motherboard_id     varchar(50) REFERENCES pc_parts(id) ON DELETE SET NULL,
  ram_id             varchar(50) REFERENCES pc_parts(id) ON DELETE SET NULL,
  storage_id         varchar(50) REFERENCES pc_parts(id) ON DELETE SET NULL,
  psu_id             varchar(50) REFERENCES pc_parts(id) ON DELETE SET NULL,
  case_id            varchar(50) REFERENCES pc_parts(id) ON DELETE SET NULL,
  cooler_id          varchar(50) REFERENCES pc_parts(id) ON DELETE SET NULL,
  service_tier       varchar(20) NOT NULL DEFAULT 'standard',  -- standard/premium
  total_parts_price  numeric(14,2) NOT NULL DEFAULT 0.00,
  build_fee          numeric(14,2) NOT NULL DEFAULT 0.00,      -- standard=Rp250k / premium=Rp500k
  grand_total        numeric(14,2) NOT NULL DEFAULT 0.00,
  is_complete        boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz
);

-- ---------------------------------------------------------------------
-- 11. REVIEWS
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
  id         varchar(50) PRIMARY KEY,
  user_id    varchar(50) REFERENCES users(id) ON DELETE SET NULL,
  product_id varchar(50) REFERENCES products(id) ON DELETE CASCADE,
  rating     numeric(2,1) NOT NULL,
  comment    text NOT NULL,
  date       timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- INDEXES (percepatan query umum)
-- ---------------------------------------------------------------------
CREATE INDEX idx_products_category_id   ON products(category_id);
CREATE INDEX idx_products_brand         ON products(brand);
CREATE INDEX idx_products_price         ON products(price);
CREATE INDEX idx_products_on_sale       ON products(is_on_sale);
CREATE INDEX idx_products_new           ON products(is_new);
CREATE INDEX idx_cart_user_id           ON cart_items(user_id);
CREATE INDEX idx_cart_product_id        ON cart_items(product_id);
CREATE INDEX idx_orders_user_id         ON orders(user_id);
CREATE INDEX idx_orders_status          ON orders(status);
CREATE INDEX idx_wishlist_user_id       ON wishlist(user_id);
CREATE INDEX idx_wishlist_product_id    ON wishlist(product_id);
CREATE INDEX idx_pc_parts_category      ON pc_parts(category);
CREATE INDEX idx_reviews_product_id     ON reviews(product_id);
CREATE INDEX idx_reviews_user_id        ON reviews(user_id);
CREATE INDEX idx_pc_builds_user_id      ON pc_builds(user_id);

-- ---------------------------------------------------------------------
-- TRIGGERS updated_at
-- ---------------------------------------------------------------------
CREATE TRIGGER users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER pc_parts_updated_at  BEFORE UPDATE ON pc_parts  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER pc_builds_updated_at BEFORE UPDATE ON pc_builds FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

