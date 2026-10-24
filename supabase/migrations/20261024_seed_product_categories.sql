-- Seed the categories used by the product forms and mock catalog.
-- Product.category_id references categories.id, so category rows must exist
-- before a product can be created with one of these IDs.

INSERT INTO public.categories (id, name, name_id, icon)
VALUES
  ('laptop', 'Laptop', 'Laptop', 'laptop_mac'),
  ('desktop', 'Desktop PC', 'PC Desktop', 'desktop_windows'),
  ('monitor', 'Monitor', 'Monitor', 'monitor'),
  ('keyboard', 'Keyboard', 'Keyboard', 'keyboard'),
  ('mouse', 'Mouse', 'Mouse', 'mouse'),
  ('headset', 'Headset', 'Headset', 'headset'),
  ('storage', 'Storage', 'Penyimpanan', 'storage'),
  ('networking', 'Networking', 'Jaringan', 'router')
ON CONFLICT (id) DO NOTHING;
