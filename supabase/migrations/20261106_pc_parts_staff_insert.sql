-- Admin & kasir menambah produk komponen PC (CPU, GPU, SSD/NVMe, cooler, case, dst)
-- -> aplikasi otomatis menambah baris di pc_parts (ID: cpu-001, gpu-001, ...).
-- Migration ini memastikan staff boleh menulis ke pc_parts dan semua orang tetap
-- bisa membacanya (dipakai halaman Rakit PC). Aman dijalankan berulang.

ALTER TABLE public.pc_parts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pc_parts_select_public ON public.pc_parts;
CREATE POLICY pc_parts_select_public ON public.pc_parts
  FOR SELECT TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS pc_parts_manage_staff ON public.pc_parts;
CREATE POLICY pc_parts_manage_staff ON public.pc_parts
  FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());
