-- ============================================================================
-- Baladna (بلدنا) — Complete Supabase PostgreSQL Schema
-- Features: Profiles, 8 Categories + Subcategories, Ads, Compressed Images,
--           Favorites, Realtime Chat, Public Comments + Replies, Artisan
--           Reviews, Reports, Admin RLS, Arabic Full-Text Search & Seed Data
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 1. ENUMS
DO $$ BEGIN
  CREATE TYPE ad_currency AS ENUM ('SYP', 'USD');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE ad_condition AS ENUM ('new', 'used');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE ad_type AS ENUM ('sell', 'rent', 'service');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE ad_status AS ENUM ('pending', 'approved', 'rejected', 'sold', 'archived');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE report_status AS ENUM ('open', 'reviewed', 'resolved', 'dismissed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. PROFILES (Linked to auth.users via Phone OTP)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT 'مستخدم بلدنا',
  phone TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  governorate TEXT NOT NULL DEFAULT 'دمشق',
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_admin BOOLEAN NOT NULL DEFAULT FALSE,
  is_banned BOOLEAN NOT NULL DEFAULT FALSE,
  rating_avg NUMERIC(2,1) NOT NULL DEFAULT 0.0,
  reviews_count INTEGER NOT NULL DEFAULT 0,
  fcm_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. CATEGORIES & SUBCATEGORIES
CREATE TABLE IF NOT EXISTS public.categories (
  id TEXT PRIMARY KEY,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  icon_name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS public.subcategories (
  id SERIAL PRIMARY KEY,
  category_id TEXT NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);

-- 4. ADS (Listings & Services)
CREATE TABLE IF NOT EXISTS public.ads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category_id TEXT NOT NULL REFERENCES public.categories(id),
  subcategory_id INTEGER REFERENCES public.subcategories(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  price NUMERIC(14,2) NOT NULL DEFAULT 0,
  currency ad_currency NOT NULL DEFAULT 'SYP',
  is_negotiable BOOLEAN NOT NULL DEFAULT TRUE,
  condition ad_condition NOT NULL DEFAULT 'used',
  ad_type ad_type NOT NULL DEFAULT 'sell',
  governorate TEXT NOT NULL,
  area TEXT NOT NULL DEFAULT '',
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  status ad_status NOT NULL DEFAULT 'approved',
  is_featured BOOLEAN NOT NULL DEFAULT FALSE,
  views_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.ad_images (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ad_id UUID NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  thumbnail_url TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. FAVORITES
CREATE TABLE IF NOT EXISTS public.favorites (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  ad_id UUID NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, ad_id)
);

-- 6. PUBLIC COMMENTS & REPLIES
CREATE TABLE IF NOT EXISTS public.comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ad_id UUID NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. REALTIME PRIVATE CHAT
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ad_id UUID NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  buyer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  seller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_message TEXT,
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (ad_id, buyer_id, seller_id)
);

CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. ARTISAN / SELLER REVIEWS
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  ad_id UUID REFERENCES public.ads(id) ON DELETE SET NULL,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (seller_id, reviewer_id, ad_id)
);

-- 9. REPORTS (Moderation Queue)
CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  ad_id UUID REFERENCES public.ads(id) ON DELETE CASCADE,
  reported_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT,
  status report_status NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. PERFORMANCE INDEXES (Optimized for Weak Internet & Fast Filtering)
CREATE INDEX IF NOT EXISTS idx_ads_status_created ON public.ads (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ads_governorate ON public.ads (governorate);
CREATE INDEX IF NOT EXISTS idx_ads_category ON public.ads (category_id, subcategory_id);
CREATE INDEX IF NOT EXISTS idx_ads_featured ON public.ads (is_featured, created_at DESC) WHERE status = 'approved';
CREATE INDEX IF NOT EXISTS idx_ads_title_trgm ON public.ads USING GIN (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_messages_conv ON public.messages (conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_comments_ad ON public.comments (ad_id, created_at ASC);

-- 11. TRIGGERS: Update Seller Rating & Conversation Last Message
CREATE OR REPLACE FUNCTION public.update_seller_rating() RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles
  SET rating_avg = COALESCE((SELECT ROUND(AVG(rating)::numeric, 1) FROM public.reviews WHERE seller_id = NEW.seller_id), 0),
      reviews_count = (SELECT COUNT(*) FROM public.reviews WHERE seller_id = NEW.seller_id)
  WHERE id = NEW.seller_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_seller_rating ON public.reviews;
CREATE TRIGGER trg_update_seller_rating
AFTER INSERT OR UPDATE OR DELETE ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.update_seller_rating();

CREATE OR REPLACE FUNCTION public.update_conversation_last_msg() RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.conversations
  SET last_message = NEW.content,
      last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_conversation_last_msg ON public.messages;
CREATE TRIGGER trg_update_conversation_last_msg
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.update_conversation_last_msg();

-- 12. ROW LEVEL SECURITY (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subcategories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Guest-friendly public reads
CREATE POLICY "Public read profiles" ON public.profiles FOR SELECT USING (TRUE);
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Public read categories" ON public.categories FOR SELECT USING (TRUE);
CREATE POLICY "Public read subcategories" ON public.subcategories FOR SELECT USING (TRUE);

CREATE POLICY "Public read approved ads" ON public.ads FOR SELECT
  USING (status = 'approved' OR auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE));
CREATE POLICY "Authenticated insert ads" ON public.ads FOR INSERT
  WITH CHECK (auth.uid() = user_id AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_banned = TRUE));
CREATE POLICY "Owner or admin update ads" ON public.ads FOR UPDATE
  USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE));
CREATE POLICY "Owner or admin delete ads" ON public.ads FOR DELETE
  USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE));

CREATE POLICY "Public read ad_images" ON public.ad_images FOR SELECT USING (TRUE);
CREATE POLICY "Authenticated insert ad_images" ON public.ad_images FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users manage own favorites" ON public.favorites FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Public read comments" ON public.comments FOR SELECT USING (TRUE);
CREATE POLICY "Authenticated insert comments" ON public.comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Owner delete comments" ON public.comments FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Participants view conversations" ON public.conversations FOR SELECT
  USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Buyer create conversation" ON public.conversations FOR INSERT
  WITH CHECK (auth.uid() = buyer_id);

CREATE POLICY "Participants view messages" ON public.messages FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = conversation_id AND (c.buyer_id = auth.uid() OR c.seller_id = auth.uid())));
CREATE POLICY "Participants send messages" ON public.messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id AND EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = conversation_id AND (c.buyer_id = auth.uid() OR c.seller_id = auth.uid())));

CREATE POLICY "Public read reviews" ON public.reviews FOR SELECT USING (TRUE);
CREATE POLICY "Authenticated insert reviews" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

CREATE POLICY "Authenticated insert reports" ON public.reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Admins manage reports" ON public.reports FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE));

-- 13. REALTIME PUBLICATION
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.comments;

-- 14. STORAGE BUCKET FOR COMPRESSED AD IMAGES
INSERT INTO storage.buckets (id, name, public)
VALUES ('ad-images', 'ad-images', TRUE)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public view ad images" ON storage.objects FOR SELECT USING (bucket_id = 'ad-images');
CREATE POLICY "Authenticated upload ad images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'ad-images' AND auth.role() = 'authenticated');

-- 15. SEED DATA: 8 CATEGORIES & ALL SUBCATEGORIES
INSERT INTO public.categories (id, name_ar, name_en, icon_name, sort_order) VALUES
  ('services',    'الخدمات والحرفيين',    'Services & Artisans', 'build', 1),
  ('used',        'المستعمل',             'Used Items',          'weekend', 2),
  ('new_tools',   'الأدوات الجديدة',      'New Tools',           'handyman', 3),
  ('appliances',  'الكهربائيات',          'Home Appliances',     'kitchen', 4),
  ('electronics', 'الإلكترونيات والجوالات','Electronics & Phones','smartphone', 5),
  ('real_estate', 'إيجار البيوت',         'Home Rentals',        'apartment', 6),
  ('cars',        'السيارات',             'Cars',                'directions_car', 7),
  ('other',       'أخرى',                 'Other',               'category', 8)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.subcategories (category_id, name_ar, name_en, sort_order) VALUES
  -- 1. Services & Artisans
  ('services', 'سباك', 'Plumber', 1),
  ('services', 'كهربائي', 'Electrician', 2),
  ('services', 'ميكانيكي سيارات', 'Car Mechanic', 3),
  ('services', 'نقليات', 'Moving & Transport', 4),
  ('services', 'نجار', 'Carpenter', 5),
  ('services', 'حداد', 'Blacksmith', 6),
  ('services', 'دهان', 'Painter', 7),
  ('services', 'تكييف وتبريد', 'AC & Cooling', 8),
  ('services', 'ألمنيوم', 'Aluminum', 9),
  ('services', 'بلاط', 'Tiling', 10),
  ('services', 'تنظيف', 'Cleaning', 11),
  ('services', 'أخرى', 'Other', 12),
  -- 2. Used
  ('used', 'أثاث', 'Furniture', 1),
  ('used', 'أدوات منزلية', 'Household Items', 2),
  ('used', 'أخرى', 'Other', 3),
  -- 3. New Tools
  ('new_tools', 'عدد يدوية', 'Hand Tools', 1),
  ('new_tools', 'كهربائية', 'Power Tools', 2),
  ('new_tools', 'مواد بناء', 'Building Materials', 3),
  -- 4. Appliances
  ('appliances', 'براد', 'Refrigerator', 1),
  ('appliances', 'غسالة', 'Washing Machine', 2),
  ('appliances', 'مكيف', 'Air Conditioner', 3),
  ('appliances', 'تلفاز', 'TV', 4),
  ('appliances', 'أخرى', 'Other', 5),
  -- 5. Electronics & Phones
  ('electronics', 'جوالات', 'Mobile Phones', 1),
  ('electronics', 'لابتوبات', 'Laptops', 2),
  ('electronics', 'إكسسوارات', 'Accessories', 3),
  -- 6. Real Estate Rentals
  ('real_estate', 'شقق', 'Apartments', 1),
  ('real_estate', 'محلات', 'Shops', 2),
  ('real_estate', 'مكاتب', 'Offices', 3),
  -- 7. Cars
  ('cars', 'بيع', 'For Sale', 1),
  ('cars', 'إيجار', 'For Rent', 2),
  -- 8. Other
  ('other', 'أخرى', 'Other', 1);
