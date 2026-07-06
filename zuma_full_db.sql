-- =====================================================================
-- ZUMA URBAN WEAR — Full database recreation script
-- Run this in the SQL Editor of a NEW empty Supabase project.
-- =====================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------
-- ENUM: app_role
-- ---------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE public.app_role AS ENUM ('admin','user');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------
-- Utility functions
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

-- ---------------------------------------------------------------------
-- Sequences for display_id
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.products_display_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.orders_display_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.orders_order_number_seq START 1;

-- =====================================================================
-- TABLE: user_roles (created early — referenced by has_role)
-- =====================================================================
CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE POLICY "Users can view own roles" ON public.user_roles
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Admins manage roles" ON public.user_roles
  TO authenticated
  USING (public.has_role(auth.uid(),'admin'))
  WITH CHECK (public.has_role(auth.uid(),'admin'));

-- =====================================================================
-- TABLE: products
-- =====================================================================
CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  price numeric(10,2) NOT NULL CHECK (price >= 0),
  category text NOT NULL DEFAULT 'T-Shirts',
  image_url text NOT NULL,
  stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
  is_visible boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  collection text,
  display_id text NOT NULL UNIQUE DEFAULT lpad(nextval('public.products_display_seq')::text, 5, '0'),
  material text,
  origin text,
  archive_ref text,
  badge text CHECK (badge IS NULL OR badge IN ('new','sold_out','few_left'))
);
GRANT SELECT ON public.products TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.products TO authenticated;
GRANT ALL ON public.products TO service_role;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone reads visible products" ON public.products
  FOR SELECT USING (is_visible = true);
CREATE POLICY "Admins read all products" ON public.products
  FOR SELECT TO authenticated USING (public.has_role(auth.uid(),'admin'));
CREATE POLICY "Admins insert products" ON public.products
  FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(),'admin'));
CREATE POLICY "Admins update products" ON public.products
  FOR UPDATE TO authenticated USING (public.has_role(auth.uid(),'admin'));
CREATE POLICY "Admins delete products" ON public.products
  FOR DELETE TO authenticated USING (public.has_role(auth.uid(),'admin'));

CREATE TRIGGER products_updated_at BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =====================================================================
-- TABLE: product_images
-- =====================================================================
CREATE TABLE public.product_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  url text NOT NULL,
  position integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  color text,
  side text DEFAULT 'front'
);
GRANT SELECT ON public.product_images TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.product_images TO authenticated;
GRANT ALL ON public.product_images TO service_role;
ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read images" ON public.product_images
  FOR SELECT USING (true);

-- =====================================================================
-- TABLE: orders
-- =====================================================================
CREATE TABLE public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name text NOT NULL,
  customer_email text NOT NULL,
  customer_phone text NOT NULL,
  customer_city text NOT NULL,
  customer_address text NOT NULL,
  total numeric(10,2) NOT NULL,
  payment_method text NOT NULL DEFAULT 'cash_on_delivery',
  status text NOT NULL DEFAULT 'pending',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  order_number integer NOT NULL DEFAULT nextval('public.orders_order_number_seq'),
  display_id text NOT NULL UNIQUE DEFAULT lpad(nextval('public.orders_display_seq')::text, 5, '0')
);
GRANT INSERT ON public.orders TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.orders TO authenticated;
GRANT ALL ON public.orders TO service_role;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Visitors create valid orders" ON public.orders
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    char_length(btrim(customer_name)) BETWEEN 2 AND 120
    AND char_length(btrim(customer_email)) BETWEEN 5 AND 255
    AND char_length(btrim(customer_phone)) BETWEEN 6 AND 30
    AND char_length(btrim(customer_address)) BETWEEN 5 AND 500
    AND char_length(btrim(customer_city)) BETWEEN 2 AND 80
    AND payment_method = 'cash_on_delivery'
    AND status = 'pending'
    AND total >= 0
  );
CREATE POLICY "admin_read_orders" ON public.orders
  FOR SELECT TO authenticated USING (public.has_role(auth.uid(),'admin'));

-- =====================================================================
-- TABLE: order_items
-- =====================================================================
CREATE TABLE public.order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  product_name text NOT NULL,
  unit_price numeric(10,2) NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  size text,
  color text
);
GRANT INSERT ON public.order_items TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.order_items TO authenticated;
GRANT ALL ON public.order_items TO service_role;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Visitors create valid order items" ON public.order_items
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    quantity > 0 AND unit_price >= 0
    AND size IS NOT NULL AND btrim(size) <> ''
    AND color IS NOT NULL AND btrim(color) <> ''
  );
CREATE POLICY "Admins read order items" ON public.order_items
  FOR SELECT TO authenticated USING (public.has_role(auth.uid(),'admin'));

-- Triggers on order_items
CREATE OR REPLACE FUNCTION public.validate_order_item_price()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE v_price numeric;
BEGIN
  SELECT price INTO v_price FROM public.products WHERE id = NEW.product_id;
  IF v_price IS NULL THEN RAISE EXCEPTION 'Invalid product'; END IF;
  IF NEW.unit_price IS NULL OR NEW.unit_price <> v_price THEN
    RAISE EXCEPTION 'unit_price does not match product price';
  END IF;
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION public.validate_order_item_variant()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.size IS NULL OR btrim(NEW.size) = '' THEN
    RAISE EXCEPTION 'Please select a size before ordering.';
  END IF;
  IF NEW.color IS NULL OR btrim(NEW.color) = '' THEN
    RAISE EXCEPTION 'Please select a color before ordering.';
  END IF;
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION public.recompute_order_total()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_order_id uuid; v_total numeric;
BEGIN
  v_order_id := COALESCE(NEW.order_id, OLD.order_id);
  SELECT COALESCE(SUM(unit_price * quantity), 0) INTO v_total
    FROM public.order_items WHERE order_id = v_order_id;
  UPDATE public.orders SET total = v_total WHERE id = v_order_id;
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_validate_order_item_price
  BEFORE INSERT OR UPDATE ON public.order_items
  FOR EACH ROW EXECUTE FUNCTION public.validate_order_item_price();
CREATE TRIGGER trg_validate_order_item_variant
  BEFORE INSERT OR UPDATE ON public.order_items
  FOR EACH ROW EXECUTE FUNCTION public.validate_order_item_variant();
CREATE TRIGGER trg_recompute_order_total_ins
  AFTER INSERT OR UPDATE OR DELETE ON public.order_items
  FOR EACH ROW EXECUTE FUNCTION public.recompute_order_total();

CREATE OR REPLACE FUNCTION public.get_order_display_id(_order_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT display_id FROM public.orders WHERE id = _order_id
$$;

-- =====================================================================
-- TABLE: newsletters
-- =====================================================================
CREATE TABLE public.newsletters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT INSERT ON public.newsletters TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.newsletters TO authenticated;
GRANT ALL ON public.newsletters TO service_role;
ALTER TABLE public.newsletters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can subscribe" ON public.newsletters
  FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "Admins can read newsletters" ON public.newsletters
  FOR SELECT TO authenticated USING (public.has_role(auth.uid(),'admin'));

-- =====================================================================
-- TABLE: waitlist
-- =====================================================================
CREATE TABLE public.waitlist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now()
);
GRANT INSERT ON public.waitlist TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.waitlist TO authenticated;
GRANT ALL ON public.waitlist TO service_role;
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can join waitlist" ON public.waitlist
  FOR INSERT TO anon, authenticated WITH CHECK (true);

-- =====================================================================
-- STORAGE: bucket 'product-images' (public)
-- =====================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public read product-images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');
CREATE POLICY "Authenticated upload product-images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'product-images');
CREATE POLICY "Authenticated update product-images"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'product-images');
CREATE POLICY "Authenticated delete product-images"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'product-images');

-- =====================================================================
-- DATA
-- Triggers that validate unit_price against products and recompute
-- totals are temporarily disabled during the seed so historical data
-- loads faithfully.
-- =====================================================================
ALTER TABLE public.order_items DISABLE TRIGGER trg_validate_order_item_price;
ALTER TABLE public.order_items DISABLE TRIGGER trg_validate_order_item_variant;
ALTER TABLE public.order_items DISABLE TRIGGER trg_recompute_order_total_ins;

-- products --
INSERT INTO public.products (id,slug,name,description,price,category,image_url,stock,is_visible,sort_order,created_at,updated_at,collection,display_id,material,origin,archive_ref,badge) VALUES ('8916308c-2016-42a3-9d30-f28b7bbc263f', 'muerted-zephyr', 'MUERTED ZEPHYR', 'death doesn''t disappear. it drifts.
this piece holds the self that remains after everything else has been stripped — not a ghost, not a memory. a zephyr. the lightest possible proof that something was here.
wear it like a trace.', '250.00', 'T-Shirts', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-main.jpg', '50', 'true', '6', '2026-05-02 17:08:00.475121+00', '2026-07-06 01:49:17.022434+00', 'IPSEITY 001', '00001', '250 gsm cotton', 'Morocco', 'A-001', 'new');
INSERT INTO public.products (id,slug,name,description,price,category,image_url,stock,is_visible,sort_order,created_at,updated_at,collection,display_id,material,origin,archive_ref,badge) VALUES ('b21321e8-de20-4350-b4a5-ea5ef7e37844', 'the-gaze', 'THE GAZE', 'you are always being seen. the question is whether you''re the one doing it. eyes as motif, eyes as confrontation — this piece puts you inside the surveillance and makes you the source of it. the watcher and the watched, collapsed into a single silhouette.
look back.', '250.00', 'T-Shirts', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-main.jpg', '50', 'true', '5', '2026-05-02 17:08:00.475121+00', '2026-07-06 01:49:05.844304+00', 'IPSEITY 002', '00002', '250 gsm cotton', 'Morocco', 'A-002', 'new');
-- orders --
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('0fadd02d-7802-4108-811f-1f2e5451cf09', 'Marouane bourguignon', 'marwanbourguignon29@gmail.com', '+212 650420263', 'Casablanca', 'Résidence abraj c', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-07 19:25:52.628362+00', '22', '00009');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('3715afe0-520e-44cf-b504-18131be2d101', 'Hamid', 'hamid.hamid@gmail.com', '0661789056', 'hamid', 'hamidhamidhamid', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-08 10:41:13.883668+00', '25', '00012');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('5412e1f8-6712-4805-b708-38e06fa1bfe5', 'Example 4', 'zxample@gmail.com', '0563828289', 'casa', 'example 2794 jajis', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-11 20:58:20.176426+00', '27', '00014');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('7aa90466-ba48-4331-8167-cde6e48cbde6', 'Leyla', 'zuma.urbanwear@gmail.com', '+212640350558', 'Casablanca', '27182hafaiahudiau', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-03 01:11:35.468414+00', '2', '00002');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('7f886838-584f-4a5a-aa2b-12d627d27e23', 'Zouitina Taha ', 'tahazouizoui@gmail.com', '0612183496', 'Casa', 'Jardin de l’océan 2', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-08 16:52:17.186977+00', '26', '00013');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('81e2f623-c650-4a45-9ead-374669e42f0f', 'leyla', 'leyla.lo@gmail.com', '06403505558', 'casablanca', 'jeuzhsjaj hajsja', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-07 19:21:11.265451+00', '19', '00007');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('84b5eff2-8624-4658-9376-be4efddf2521', 'Rayan Belmejdoub', 'cafc.belmejdoub.rayan@gmail.com', '+212696831134', 'Casablanca', 'Rue Ibnou Katir résidence Mawlid 2, Escalier b', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-07 21:10:58.441885+00', '24', '00011');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('8939335e-f034-4f58-8ae2-aa36d5ffeccf', 'Example 2', 'example2@gmail.com', '0647282619', 'casa', 'example2 hajshajorp', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-11 21:17:18.10083+00', '33', '00020');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('8c7550fa-880b-4152-9d87-ccecfa57a994', 'Zuma', 'zuma.urbanwear@gmail.com', '+212640350558', 'Casablanca', '27182 haiefa', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-03 20:48:02.302299+00', '5', '00005');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('9057a82d-3f02-4623-9d62-c0321689ee67', 'example', 'leyla.ue@gmail.com', '+212666663882', 'Casablanca', '102 hajsuzuja leuhehz', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-03 20:55:41.754196+00', '6', '00006');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('a78286ec-7bac-48f0-b0e9-8a6fdc089598', 'Louai Leyla Sara', 'leyla.louai@gmail.com', '0640350558', 'Casablanca', 'Bouskoura V18 TR 12', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-07-03 13:07:50.220002+00', '52', '00039');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('b97e0fb0-03b4-433e-ab67-76027e34dd54', 'Zuma', 'zuma.urbanwear@gmail.com', '+212640350558', 'Casablanca', '27182hafaiahudiau', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-03 01:08:13.16344+00', '1', '00001');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('c52defbc-f033-400a-9eb3-8cc8f6f88e5a', 'leyla', 'leyla.lo@gmail.com', '06403505558', 'casablanca', 'jeuzhsjaj hajsja', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-07 19:24:14.019993+00', '20', '00008');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('cfa47fc5-3ffe-4f5a-bfd7-05a6893bee24', 'Test User', 'test@test.com', '+212600000000', 'Casablanca', 'Test Address 123', '0.00', 'cash_on_delivery', 'pending', NULL, '2026-05-11 21:34:04.516615+00', '41', '00028');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('d557263c-549a-4415-b715-31521c29d778', 'leyla', 'l.louai@icloud.com', '+212640350558', 'Casablanca', 'jajdhaj 103 jzjdh', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-03 13:38:50.425368+00', '4', '00004');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('e9f1febb-40f6-4b3b-891e-ddee18761193', 'Riyane', 'R.012kanbou@gmail.com', '0649163282', 'Casablanca ', '364 mazola', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-07 19:35:38.63163+00', '23', '00010');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('f499b14f-ba8f-4037-bb76-8d4f48adfa06', 'leyla', 'leyla.louai@gmail.com', '0640350058', 'Casablanca', 'Bouskoura V17', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-07-06 12:13:30.205708+00', '53', '00040');
INSERT INTO public.orders (id,customer_name,customer_email,customer_phone,customer_city,customer_address,total,payment_method,status,notes,created_at,order_number,display_id) VALUES ('fc7e4199-9ba8-49ee-a8fa-016565e84095', 'charlotte la fraise ', 'yasminaguessous17@gmail.com', '0664416559', 'casa', 'domaine de darb villa 101 ', '250.00', 'cash_on_delivery', 'pending', NULL, '2026-05-03 07:34:13.767951+00', '3', '00003');
-- order_items --
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('1039671f-43d4-4bb8-a46b-f707001c3890', 'a78286ec-7bac-48f0-b0e9-8a6fdc089598', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'MUERTED ZEPHYR', '250.00', '1', 'L', 'GREY');
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('105ceb66-4bfa-4080-8414-0261786fb8c0', '8939335e-f034-4f58-8ae2-aa36d5ffeccf', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'MUERTED ZEPHYR', '250.00', '1', 'M', 'GREY');
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('29b307a6-c54c-4bdc-9f5d-4f49c815c97e', '5412e1f8-6712-4805-b708-38e06fa1bfe5', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'MUERTED ZEPHYR', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('2e1639f9-bc5c-4db7-9355-ffec3e2f2d02', '81e2f623-c650-4a45-9ead-374669e42f0f', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'THE GAZE', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('4b092cb5-89d5-43f6-93a9-46b0bd0b7378', 'fc7e4199-9ba8-49ee-a8fa-016565e84095', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'THE GAZE', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('4b29f594-8656-4b6b-b533-87930fbd611d', 'e9f1febb-40f6-4b3b-891e-ddee18761193', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'MUERTED ZEPHYR', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('836b05d4-db69-4489-bf19-ab1bd4d05854', '3715afe0-520e-44cf-b504-18131be2d101', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'THE GAZE', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('865aee2a-6ef7-4e78-b7b7-3be7471eac7f', 'b97e0fb0-03b4-433e-ab67-76027e34dd54', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'MUERTED ZEPHYR', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('977c21d9-3fa8-42a5-9633-79031d6fa83e', 'd557263c-549a-4415-b715-31521c29d778', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'THE GAZE', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('d40237b2-e575-4dc0-b055-648b14678b30', '7aa90466-ba48-4331-8167-cde6e48cbde6', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'MUERTED ZEPHYR', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('d6108b41-8634-4813-8a68-5c10a6995be1', 'c52defbc-f033-400a-9eb3-8cc8f6f88e5a', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'THE GAZE', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('e4f077bd-08f1-4204-a1e7-92fa18f522c2', '8c7550fa-880b-4152-9d87-ccecfa57a994', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'THE GAZE', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('e7b42d93-4981-426e-9018-5d8d79810353', '9057a82d-3f02-4623-9d62-c0321689ee67', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'THE GAZE', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('ed4a006d-6336-4854-bec6-b06e7d8786e9', 'f499b14f-ba8f-4037-bb76-8d4f48adfa06', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'MUERTED ZEPHYR', '250.00', '1', 'M', 'GREY');
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('efde8146-c93d-45f3-aaf4-2ff7f44d9b65', '84b5eff2-8624-4658-9376-be4efddf2521', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'THE GAZE', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('f195c3bd-ca3d-4255-9359-233b43050352', '7f886838-584f-4a5a-aa2b-12d627d27e23', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'MUERTED ZEPHYR', '250.00', '1', NULL, NULL);
INSERT INTO public.order_items (id,order_id,product_id,product_name,unit_price,quantity,size,color) VALUES ('fae4b186-22b6-407c-b0f9-8c5bdfc6f3bc', '0fadd02d-7802-4108-811f-1f2e5451cf09', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'THE GAZE', '250.00', '1', NULL, NULL);
-- product_images --
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('078c3e44-6dd5-4d9c-98fe-3291c3881516', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-grey.jpg', '2', '2026-05-03 12:03:46.369155+00', 'GREY', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('08485f2b-b368-46d1-b97d-e5dd5faa3fb9', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-white.jpg', '1', '2026-05-03 12:03:49.130526+00', 'WHITE', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('1e196614-1dbf-4bc8-87fa-c1addd7327df', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-black.jpg', '3', '2026-05-03 12:03:46.369155+00', 'BLACK', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('3d2aab5a-9cb9-465a-a51f-a201f8cfa09a', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-white.jpg', '1', '2026-05-03 12:04:00.271476+00', 'WHITE', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('42809006-6548-4406-b5fb-c8213b903d83', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-white.jpg', '1', '2026-05-03 12:03:49.130526+00', 'WHITE', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('43bb20e0-a6c6-4896-95ab-6b9f3688cbd6', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-black.jpg', '3', '2026-05-03 12:03:49.130526+00', 'BLACK', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('447b947e-cb41-4d7b-948b-034861550fa1', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-black.jpg', '3', '2026-05-03 12:03:46.369155+00', 'BLACK', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('44ca925c-796b-4465-8e49-4543d1f3b870', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-grey-front.jpg', '5', '2026-05-03 12:24:40.498931+00', 'GREY', 'front');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('5408498e-405a-4baf-a143-726158a3bf01', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-black.jpg', '3', '2026-05-03 12:04:00.271476+00', 'BLACK', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('6fd9efa4-8694-4007-aea3-de416db37b85', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-grey.jpg', '2', '2026-05-03 12:04:00.271476+00', 'GREY', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('7f9221fe-c441-4082-981a-8b0d6abf02b7', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-black-front.jpg', '6', '2026-05-03 12:24:40.498931+00', 'BLACK', 'front');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('844e73ff-221c-4b4e-84d5-00f443b1ed64', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-white-front.jpg', '4', '2026-05-03 12:24:40.498931+00', 'WHITE', 'front');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('84c4a287-9e4d-4090-a934-428475a2d562', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-grey.jpg', '2', '2026-05-03 12:04:00.271476+00', 'GREY', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('8e864d00-e525-4442-a580-77bbb3b9d8c6', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-grey.jpg', '2', '2026-05-03 12:03:49.130526+00', 'GREY', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('9c0573cf-f2af-4607-a170-8332198ec0b0', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-grey.jpg', '2', '2026-05-03 12:03:46.369155+00', 'GREY', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('a4f75107-4936-487f-85f2-acca1f4e9653', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-white.jpg', '1', '2026-05-03 12:04:00.271476+00', 'WHITE', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('a606cc06-242f-49e7-9a03-d62b72eceb5b', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-black-front.jpg', '6', '2026-05-03 12:24:40.498931+00', 'BLACK', 'front');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('b3a364f7-10aa-4dc1-a78f-7843d59456ac', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-white-front.jpg', '4', '2026-05-03 12:24:40.498931+00', 'WHITE', 'front');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('be096bf2-05f7-46e0-a5e0-84b2a3af2f03', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-grey-front.jpg', '5', '2026-05-03 12:24:40.498931+00', 'GREY', 'front');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('ca330e40-2da6-4043-a40a-5ced6f91609e', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-grey.jpg', '2', '2026-05-03 12:03:49.130526+00', 'GREY', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('d1699530-f705-4586-a620-8d9ce532feca', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-white.jpg', '1', '2026-05-03 12:03:46.369155+00', 'WHITE', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('e91ae02b-2b05-4c0e-a927-0bd706393536', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-white.jpg', '1', '2026-05-03 12:03:46.369155+00', 'WHITE', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('f44023b4-2f43-4580-9d3d-e93e18c07612', 'b21321e8-de20-4350-b4a5-ea5ef7e37844', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/the-gaze-black.jpg', '3', '2026-05-03 12:03:49.130526+00', 'BLACK', 'back');
INSERT INTO public.product_images (id,product_id,url,position,created_at,color,side) VALUES ('f9cf4d65-e260-4e62-b268-8a5ad9084a1a', '8916308c-2016-42a3-9d30-f28b7bbc263f', 'https://bsiyhxositjcvlaswttk.supabase.co/storage/v1/object/public/product-images/muerted-zephyr-black.jpg', '3', '2026-05-03 12:04:00.271476+00', 'BLACK', 'back');
-- user_roles --
INSERT INTO public.user_roles (id,user_id,role,created_at) VALUES ('5a874d01-2e89-4b80-8de3-645165b0f735', '7c54309b-4d59-4494-a5b0-0461d86e42b6', 'admin', '2026-05-07 19:46:47.424219+00');

-- Re-enable triggers
ALTER TABLE public.order_items ENABLE TRIGGER trg_validate_order_item_price;
ALTER TABLE public.order_items ENABLE TRIGGER trg_validate_order_item_variant;
ALTER TABLE public.order_items ENABLE TRIGGER trg_recompute_order_total_ins;

-- Sync sequences with existing data
SELECT setval('public.products_display_seq', COALESCE((SELECT MAX(display_id::int) FROM public.products), 1));
SELECT setval('public.orders_display_seq',   COALESCE((SELECT MAX(display_id::int) FROM public.orders), 1));
SELECT setval('public.orders_order_number_seq', COALESCE((SELECT MAX(order_number) FROM public.orders), 1));

-- =====================================================================
-- NOTE: user_roles references auth.users(id). The included row(s) will
-- only be valid if you first create the matching auth user with the
-- same UUID in the new project (Authentication → Users).
-- =====================================================================
