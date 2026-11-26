-- ============================================================================
-- JagaBersama - Skema Database PostgreSQL & RLS untuk Supabase (Free Tier)
-- Jalankan seluruh skrip ini di Supabase Dashboard -> SQL Editor -> New Query
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. TABEL UTAMA
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL CHECK (char_length(trim(name)) >= 2),
    invite_code TEXT NOT NULL UNIQUE,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.health_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    full_name TEXT NOT NULL CHECK (char_length(trim(full_name)) >= 2),
    relation_label TEXT NOT NULL DEFAULT 'Anggota',
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'caretaker', 'member')),
    access_permission TEXT NOT NULL DEFAULT 'view_only' CHECK (access_permission IN ('private', 'view_only', 'view_and_edit')),
    claim_code TEXT UNIQUE,
    birth_date DATE,
    gender TEXT CHECK (gender IN ('Laki-laki', 'Perempuan')),
    blood_type TEXT CHECK (blood_type IN ('A', 'B', 'AB', 'O', 'Tidak Tahu')),
    allergies TEXT,
    chronic_conditions TEXT,
    default_height_cm NUMERIC(5, 2) CHECK (default_height_cm IS NULL OR (default_height_cm > 20 AND default_height_cm < 260)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.health_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    recorded_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    recorded_by_name TEXT NOT NULL DEFAULT 'Pengguna',
    updated_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by_name TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    systolic INTEGER CHECK (systolic IS NULL OR (systolic BETWEEN 40 AND 300)),
    diastolic INTEGER CHECK (diastolic IS NULL OR (diastolic BETWEEN 20 AND 200)),
    temperature_c NUMERIC(4, 1) CHECK (temperature_c IS NULL OR (temperature_c BETWEEN 30.0 AND 45.0)),
    heart_rate INTEGER CHECK (heart_rate IS NULL OR (heart_rate BETWEEN 25 AND 250)),
    weight_kg NUMERIC(5, 2) CHECK (weight_kg IS NULL OR (weight_kg BETWEEN 1.0 AND 350.0)),
    height_cm NUMERIC(5, 2) CHECK (height_cm IS NULL OR (height_cm BETWEEN 20.0 AND 260.0)),
    blood_sugar NUMERIC(5, 1) CHECK (blood_sugar IS NULL OR (blood_sugar BETWEEN 15.0 AND 1200.0)),
    sugar_type TEXT CHECK (sugar_type IS NULL OR sugar_type IN ('fasting', 'random', 'post_meal')),
    symptoms TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.health_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    uploaded_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    uploaded_by_name TEXT NOT NULL DEFAULT 'Pengguna',
    title TEXT NOT NULL CHECK (char_length(trim(title)) >= 2),
    category TEXT NOT NULL DEFAULT 'other' CHECK (category IN ('lab_result', 'prescription', 'referral', 'other')),
    storage_path TEXT NOT NULL UNIQUE,
    mime_type TEXT NOT NULL,
    file_size_bytes INTEGER NOT NULL CHECK (file_size_bytes > 0 AND file_size_bytes <= 5242880),
    document_date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.health_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    created_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    created_by_name TEXT NOT NULL DEFAULT 'Pengguna',
    title TEXT NOT NULL CHECK (char_length(trim(title)) >= 2),
    schedule_type TEXT NOT NULL DEFAULT 'checkup' CHECK (schedule_type IN ('checkup', 'consultation', 'lab', 'medication', 'other')),
    scheduled_at TIMESTAMPTZ NOT NULL,
    location_or_doctor TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'completed', 'cancelled')),
    reminder_minutes_before INTEGER NOT NULL DEFAULT 60 CHECK (reminder_minutes_before >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    target_profile_id UUID REFERENCES public.health_profiles(id) ON DELETE SET NULL,
    actor_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    actor_name TEXT NOT NULL,
    action_type TEXT NOT NULL CHECK (action_type IN ('create', 'update', 'delete', 'permission_change', 'role_change', 'join', 'claim')),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('record', 'document', 'schedule', 'profile', 'family')),
    entity_id UUID,
    summary TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indeks untuk mempercepat query dashboard, grafik & riwayat
CREATE INDEX IF NOT EXISTS idx_health_profiles_family ON public.health_profiles(family_id);
CREATE INDEX IF NOT EXISTS idx_health_profiles_user ON public.health_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_health_records_profile_date ON public.health_records(profile_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_health_records_family_date ON public.health_records(family_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_health_documents_profile_date ON public.health_documents(profile_id, document_date DESC);
CREATE INDEX IF NOT EXISTS idx_health_schedules_family_date ON public.health_schedules(family_id, scheduled_at ASC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_family_date ON public.activity_logs(family_id, created_at DESC);

-- Trigger updated_at otomatis
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_health_records_updated_at ON public.health_records;
CREATE TRIGGER trg_health_records_updated_at
    BEFORE UPDATE ON public.health_records
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_health_schedules_updated_at ON public.health_schedules;
CREATE TRIGGER trg_health_schedules_updated_at
    BEFORE UPDATE ON public.health_schedules
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 2. FUNGSI HELPER KEAMANAN & RLS (SECURITY DEFINER ANTI-REKURSI)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.generate_short_code(p_prefix TEXT, p_len INTEGER DEFAULT 6)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    result TEXT := '';
    i INTEGER;
    idx INTEGER;
BEGIN
    FOR i IN 1..p_len LOOP
        idx := 1 + (get_byte(gen_random_bytes(1), 0) % length(chars));
        result := result || substr(chars, idx, 1);
    END LOOP;
    RETURN p_prefix || '-' || result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_family_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT family_id FROM public.health_profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_my_profile_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT id FROM public.health_profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_my_family_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role FROM public.health_profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.can_view_profile(p_profile_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_my_family UUID;
    v_my_role TEXT;
    v_target RECORD;
BEGIN
    SELECT family_id, role INTO v_my_family, v_my_role
    FROM public.health_profiles
    WHERE user_id = auth.uid()
    LIMIT 1;

    IF v_my_family IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT id, family_id, user_id, access_permission INTO v_target
    FROM public.health_profiles
    WHERE id = p_profile_id
    LIMIT 1;

    IF v_target.id IS NULL OR v_target.family_id <> v_my_family THEN
        RETURN FALSE;
    END IF;

    -- Pemilik profil selalu boleh melihat datanya sendiri
    IF v_target.user_id = auth.uid() THEN
        RETURN TRUE;
    END IF;

    -- Owner & Pengelola dapat melihat profil tanpa akun, atau profil dewasa yang mengizinkan
    IF v_my_role IN ('owner', 'caretaker') THEN
        IF v_target.user_id IS NULL OR v_target.access_permission IN ('view_only', 'view_and_edit') THEN
            RETURN TRUE;
        END IF;
    END IF;

    RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION public.can_edit_profile(p_profile_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_my_family UUID;
    v_my_role TEXT;
    v_target RECORD;
BEGIN
    SELECT family_id, role INTO v_my_family, v_my_role
    FROM public.health_profiles
    WHERE user_id = auth.uid()
    LIMIT 1;

    IF v_my_family IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT id, family_id, user_id, access_permission INTO v_target
    FROM public.health_profiles
    WHERE id = p_profile_id
    LIMIT 1;

    IF v_target.id IS NULL OR v_target.family_id <> v_my_family THEN
        RETURN FALSE;
    END IF;

    IF v_target.user_id = auth.uid() THEN
        RETURN TRUE;
    END IF;

    IF v_my_role IN ('owner', 'caretaker') THEN
        IF v_target.user_id IS NULL OR v_target.access_permission = 'view_and_edit' THEN
            RETURN TRUE;
        END IF;
    END IF;

    RETURN FALSE;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. AKTIFKAN RLS & KEBIJAKAN SETIAP TABEL
-- ----------------------------------------------------------------------------

ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- FAMILIES
DROP POLICY IF EXISTS "families_select_member" ON public.families;
CREATE POLICY "families_select_member" ON public.families
    FOR SELECT USING (id = public.get_my_family_id());

DROP POLICY IF EXISTS "families_update_owner" ON public.families;
CREATE POLICY "families_update_owner" ON public.families
    FOR UPDATE USING (id = public.get_my_family_id() AND public.get_my_family_role() = 'owner');

-- HEALTH_PROFILES
DROP POLICY IF EXISTS "profiles_select_authorized" ON public.health_profiles;
CREATE POLICY "profiles_select_authorized" ON public.health_profiles
    FOR SELECT USING (user_id = auth.uid() OR public.can_view_profile(id));

DROP POLICY IF EXISTS "profiles_update_authorized" ON public.health_profiles;
CREATE POLICY "profiles_update_authorized" ON public.health_profiles
    FOR UPDATE USING (
        user_id = auth.uid()
        OR (family_id = public.get_my_family_id() AND public.get_my_family_role() IN ('owner', 'caretaker') AND user_id IS NULL)
        OR (family_id = public.get_my_family_id() AND public.get_my_family_role() = 'owner')
    );

-- Cegah eskalasi peran atau pemindahan keluarga melalui UPDATE langsung
CREATE OR REPLACE FUNCTION public.guard_profile_sensitive_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF current_setting('role', TRUE) = 'authenticated' THEN
        IF NEW.family_id IS DISTINCT FROM OLD.family_id THEN
            RAISE EXCEPTION 'family_id tidak dapat diubah langsung';
        END IF;
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'Gunakan RPC update_member_role untuk mengubah peran';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_profile_sensitive ON public.health_profiles;
CREATE TRIGGER trg_guard_profile_sensitive
    BEFORE UPDATE ON public.health_profiles
    FOR EACH ROW EXECUTE FUNCTION public.guard_profile_sensitive_columns();

DROP POLICY IF EXISTS "profiles_delete_owner" ON public.health_profiles;
CREATE POLICY "profiles_delete_owner" ON public.health_profiles
    FOR DELETE USING (
        family_id = public.get_my_family_id()
        AND public.get_my_family_role() = 'owner'
        AND user_id IS DISTINCT FROM auth.uid()
    );

-- HEALTH_RECORDS
DROP POLICY IF EXISTS "records_select_authorized" ON public.health_records;
CREATE POLICY "records_select_authorized" ON public.health_records
    FOR SELECT USING (public.can_view_profile(profile_id));

DROP POLICY IF EXISTS "records_insert_authorized" ON public.health_records;
CREATE POLICY "records_insert_authorized" ON public.health_records
    FOR INSERT WITH CHECK (
        family_id = public.get_my_family_id()
        AND recorded_by_user_id = auth.uid()
        AND public.can_edit_profile(profile_id)
    );

DROP POLICY IF EXISTS "records_update_authorized" ON public.health_records;
CREATE POLICY "records_update_authorized" ON public.health_records
    FOR UPDATE USING (public.can_edit_profile(profile_id));

DROP POLICY IF EXISTS "records_delete_authorized" ON public.health_records;
CREATE POLICY "records_delete_authorized" ON public.health_records
    FOR DELETE USING (public.can_edit_profile(profile_id));

-- HEALTH_DOCUMENTS
DROP POLICY IF EXISTS "documents_select_authorized" ON public.health_documents;
CREATE POLICY "documents_select_authorized" ON public.health_documents
    FOR SELECT USING (public.can_view_profile(profile_id));

DROP POLICY IF EXISTS "documents_insert_authorized" ON public.health_documents;
CREATE POLICY "documents_insert_authorized" ON public.health_documents
    FOR INSERT WITH CHECK (
        family_id = public.get_my_family_id()
        AND uploaded_by_user_id = auth.uid()
        AND public.can_edit_profile(profile_id)
    );

DROP POLICY IF EXISTS "documents_delete_authorized" ON public.health_documents;
CREATE POLICY "documents_delete_authorized" ON public.health_documents
    FOR DELETE USING (public.can_edit_profile(profile_id));

-- HEALTH_SCHEDULES
DROP POLICY IF EXISTS "schedules_select_authorized" ON public.health_schedules;
CREATE POLICY "schedules_select_authorized" ON public.health_schedules
    FOR SELECT USING (public.can_view_profile(profile_id));

DROP POLICY IF EXISTS "schedules_insert_authorized" ON public.health_schedules;
CREATE POLICY "schedules_insert_authorized" ON public.health_schedules
    FOR INSERT WITH CHECK (
        family_id = public.get_my_family_id()
        AND created_by_user_id = auth.uid()
        AND public.can_edit_profile(profile_id)
    );

DROP POLICY IF EXISTS "schedules_update_authorized" ON public.health_schedules;
CREATE POLICY "schedules_update_authorized" ON public.health_schedules
    FOR UPDATE USING (public.can_edit_profile(profile_id));

DROP POLICY IF EXISTS "schedules_delete_authorized" ON public.health_schedules;
CREATE POLICY "schedules_delete_authorized" ON public.health_schedules
    FOR DELETE USING (public.can_edit_profile(profile_id));

-- ACTIVITY_LOGS (Hanya dapat dilihat pemilik data, owner, dan caretaker)
DROP POLICY IF EXISTS "logs_select_authorized" ON public.activity_logs;
CREATE POLICY "logs_select_authorized" ON public.activity_logs
    FOR SELECT USING (
        family_id = public.get_my_family_id()
        AND (
            public.get_my_family_role() IN ('owner', 'caretaker')
            OR target_profile_id = public.get_my_profile_id()
            OR actor_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "logs_insert_member" ON public.activity_logs;
CREATE POLICY "logs_insert_member" ON public.activity_logs
    FOR INSERT WITH CHECK (
        family_id = public.get_my_family_id()
        AND actor_user_id = auth.uid()
    );

-- ----------------------------------------------------------------------------
-- 4. RPC FUNGSI BISNIS & ONBOARDING
-- ----------------------------------------------------------------------------

-- Daftar anggota keluarga ringkas (menghormati privasi data medis profil privat)
CREATE OR REPLACE FUNCTION public.get_family_directory()
RETURNS TABLE (
    id UUID,
    family_id UUID,
    user_id UUID,
    full_name TEXT,
    relation_label TEXT,
    role TEXT,
    access_permission TEXT,
    claim_code TEXT,
    birth_date DATE,
    gender TEXT,
    blood_type TEXT,
    allergies TEXT,
    chronic_conditions TEXT,
    default_height_cm NUMERIC,
    created_at TIMESTAMPTZ,
    can_view BOOLEAN,
    can_edit BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_family_id UUID;
    v_my_role TEXT;
BEGIN
    SELECT hp.family_id, hp.role INTO v_family_id, v_my_role
    FROM public.health_profiles hp
    WHERE hp.user_id = auth.uid()
    LIMIT 1;

    IF v_family_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.family_id,
        p.user_id,
        p.full_name,
        p.relation_label,
        p.role,
        p.access_permission,
        CASE WHEN v_my_role IN ('owner', 'caretaker') THEN p.claim_code ELSE NULL END AS claim_code,
        CASE WHEN public.can_view_profile(p.id) THEN p.birth_date ELSE NULL END AS birth_date,
        p.gender,
        CASE WHEN public.can_view_profile(p.id) THEN p.blood_type ELSE NULL END AS blood_type,
        CASE WHEN public.can_view_profile(p.id) THEN p.allergies ELSE NULL END AS allergies,
        CASE WHEN public.can_view_profile(p.id) THEN p.chronic_conditions ELSE NULL END AS chronic_conditions,
        CASE WHEN public.can_view_profile(p.id) THEN p.default_height_cm ELSE NULL END AS default_height_cm,
        p.created_at,
        public.can_view_profile(p.id) AS can_view,
        public.can_edit_profile(p.id) AS can_edit
    FROM public.health_profiles p
    WHERE p.family_id = v_family_id
    ORDER BY
        CASE WHEN p.user_id = auth.uid() THEN 0 ELSE 1 END,
        CASE p.role WHEN 'owner' THEN 0 WHEN 'caretaker' THEN 1 ELSE 2 END,
        p.created_at ASC;
END;
$$;

-- Buat grup keluarga baru dan jadikan pembuat sebagai owner
CREATE OR REPLACE FUNCTION public.create_family_with_owner(
    p_family_name TEXT,
    p_full_name TEXT,
    p_relation_label TEXT DEFAULT 'Admin Keluarga',
    p_birth_date DATE DEFAULT NULL,
    p_gender TEXT DEFAULT NULL
)
RETURNS public.health_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_family_id UUID;
    v_invite_code TEXT;
    v_profile public.health_profiles;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autentikasi diperlukan';
    END IF;

    IF EXISTS (SELECT 1 FROM public.health_profiles WHERE user_id = v_uid) THEN
        RAISE EXCEPTION 'Akun Anda sudah tergabung dalam sebuah keluarga';
    END IF;

    LOOP
        v_invite_code := public.generate_short_code('JB', 6);
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.families WHERE invite_code = v_invite_code);
    END LOOP;

    INSERT INTO public.families (name, invite_code, created_by)
    VALUES (trim(p_family_name), v_invite_code, v_uid)
    RETURNING id INTO v_family_id;

    INSERT INTO public.health_profiles (
        family_id, user_id, full_name, relation_label, role,
        access_permission, birth_date, gender
    ) VALUES (
        v_family_id, v_uid, trim(p_full_name), COALESCE(NULLIF(trim(p_relation_label), ''), 'Admin Keluarga'),
        'owner', 'view_and_edit', p_birth_date, p_gender
    ) RETURNING * INTO v_profile;

    INSERT INTO public.activity_logs (
        family_id, target_profile_id, actor_user_id, actor_name,
        action_type, entity_type, entity_id, summary
    ) VALUES (
        v_family_id, v_profile.id, v_uid, v_profile.full_name,
        'create', 'family', v_family_id,
        'Membuat grup keluarga "' || trim(p_family_name) || '"'
    );

    RETURN v_profile;
END;
$$;

-- Gabung ke keluarga dengan kode undangan
CREATE OR REPLACE FUNCTION public.join_family_by_invite_code(
    p_invite_code TEXT,
    p_full_name TEXT,
    p_relation_label TEXT DEFAULT 'Anggota',
    p_access_permission TEXT DEFAULT 'view_only',
    p_birth_date DATE DEFAULT NULL,
    p_gender TEXT DEFAULT NULL
)
RETURNS public.health_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_family public.families;
    v_profile public.health_profiles;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autentikasi diperlukan';
    END IF;

    IF EXISTS (SELECT 1 FROM public.health_profiles WHERE user_id = v_uid) THEN
        RAISE EXCEPTION 'Akun Anda sudah tergabung dalam sebuah keluarga';
    END IF;

    SELECT * INTO v_family
    FROM public.families
    WHERE upper(invite_code) = upper(trim(p_invite_code))
    LIMIT 1;

    IF v_family.id IS NULL THEN
        RAISE EXCEPTION 'Kode undangan keluarga tidak ditemukan';
    END IF;

    INSERT INTO public.health_profiles (
        family_id, user_id, full_name, relation_label, role,
        access_permission, birth_date, gender
    ) VALUES (
        v_family.id, v_uid, trim(p_full_name), COALESCE(NULLIF(trim(p_relation_label), ''), 'Anggota'),
        'member', p_access_permission, p_birth_date, p_gender
    ) RETURNING * INTO v_profile;

    INSERT INTO public.activity_logs (
        family_id, target_profile_id, actor_user_id, actor_name,
        action_type, entity_type, entity_id, summary
    ) VALUES (
        v_family.id, v_profile.id, v_uid, v_profile.full_name,
        'join', 'family', v_family.id,
        v_profile.full_name || ' bergabung ke keluarga melalui kode undangan'
    );

    RETURN v_profile;
END;
$$;

-- Klaim profil tanpa akun menggunakan kode klaim khusus
CREATE OR REPLACE FUNCTION public.claim_profile_by_code(p_claim_code TEXT)
RETURNS public.health_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_profile public.health_profiles;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autentikasi diperlukan';
    END IF;

    IF EXISTS (SELECT 1 FROM public.health_profiles WHERE user_id = v_uid) THEN
        RAISE EXCEPTION 'Akun Anda sudah terhubung dengan sebuah profil keluarga';
    END IF;

    SELECT * INTO v_profile
    FROM public.health_profiles
    WHERE upper(claim_code) = upper(trim(p_claim_code))
      AND user_id IS NULL
    LIMIT 1;

    IF v_profile.id IS NULL THEN
        RAISE EXCEPTION 'Kode klaim profil tidak valid atau sudah digunakan';
    END IF;

    UPDATE public.health_profiles
    SET user_id = v_uid,
        claim_code = NULL,
        access_permission = 'view_and_edit'
    WHERE id = v_profile.id
    RETURNING * INTO v_profile;

    INSERT INTO public.activity_logs (
        family_id, target_profile_id, actor_user_id, actor_name,
        action_type, entity_type, entity_id, summary
    ) VALUES (
        v_profile.family_id, v_profile.id, v_uid, v_profile.full_name,
        'claim', 'profile', v_profile.id,
        'Mengklaim profil "' || v_profile.full_name || '" ke akun pribadi'
    );

    RETURN v_profile;
END;
$$;

-- Tambah profil tanpa akun (untuk anak/lansia tanpa HP)
CREATE OR REPLACE FUNCTION public.create_managed_profile(
    p_full_name TEXT,
    p_relation_label TEXT,
    p_birth_date DATE DEFAULT NULL,
    p_gender TEXT DEFAULT NULL,
    p_blood_type TEXT DEFAULT 'Tidak Tahu',
    p_allergies TEXT DEFAULT NULL,
    p_chronic_conditions TEXT DEFAULT NULL,
    p_default_height_cm NUMERIC DEFAULT NULL
)
RETURNS public.health_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_actor public.health_profiles;
    v_claim_code TEXT;
    v_created public.health_profiles;
BEGIN
    SELECT * INTO v_actor FROM public.health_profiles WHERE user_id = v_uid LIMIT 1;
    IF v_actor.id IS NULL OR v_actor.role NOT IN ('owner', 'caretaker') THEN
        RAISE EXCEPTION 'Hanya Admin Utama atau Pengelola yang dapat menambahkan profil tanpa akun';
    END IF;

    LOOP
        v_claim_code := public.generate_short_code('KL', 6);
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.health_profiles WHERE claim_code = v_claim_code);
    END LOOP;

    INSERT INTO public.health_profiles (
        family_id, user_id, full_name, relation_label, role,
        access_permission, claim_code, birth_date, gender,
        blood_type, allergies, chronic_conditions, default_height_cm
    ) VALUES (
        v_actor.family_id, NULL, trim(p_full_name), trim(p_relation_label), 'member',
        'view_and_edit', v_claim_code, p_birth_date, p_gender,
        p_blood_type, NULLIF(trim(p_allergies), ''), NULLIF(trim(p_chronic_conditions), ''), p_default_height_cm
    ) RETURNING * INTO v_created;

    INSERT INTO public.activity_logs (
        family_id, target_profile_id, actor_user_id, actor_name,
        action_type, entity_type, entity_id, summary
    ) VALUES (
        v_actor.family_id, v_created.id, v_uid, v_actor.full_name,
        'create', 'profile', v_created.id,
        'Menambahkan profil anggota "' || v_created.full_name || '" (' || v_created.relation_label || ')'
    );

    RETURN v_created;
END;
$$;

-- Ubah peran anggota (khusus owner)
CREATE OR REPLACE FUNCTION public.update_member_role(p_profile_id UUID, p_new_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_actor public.health_profiles;
    v_target public.health_profiles;
BEGIN
    IF p_new_role NOT IN ('caretaker', 'member') THEN
        RAISE EXCEPTION 'Peran hanya boleh diubah menjadi Pengelola (caretaker) atau Anggota (member)';
    END IF;

    SELECT * INTO v_actor FROM public.health_profiles WHERE user_id = auth.uid() LIMIT 1;
    IF v_actor.id IS NULL OR v_actor.role <> 'owner' THEN
        RAISE EXCEPTION 'Hanya Admin Utama yang dapat mengubah peran anggota';
    END IF;

    SELECT * INTO v_target FROM public.health_profiles WHERE id = p_profile_id AND family_id = v_actor.family_id LIMIT 1;
    IF v_target.id IS NULL THEN
        RAISE EXCEPTION 'Anggota tidak ditemukan';
    END IF;
    IF v_target.user_id IS NULL THEN
        RAISE EXCEPTION 'Profil tanpa akun tidak dapat dijadikan Pengelola';
    END IF;
    IF v_target.id = v_actor.id THEN
        RAISE EXCEPTION 'Peran Admin Utama tidak dapat diturunkan sendiri';
    END IF;

    UPDATE public.health_profiles SET role = p_new_role WHERE id = v_target.id;

    INSERT INTO public.activity_logs (
        family_id, target_profile_id, actor_user_id, actor_name,
        action_type, entity_type, entity_id, summary
    ) VALUES (
        v_actor.family_id, v_target.id, auth.uid(), v_actor.full_name,
        'role_change', 'profile', v_target.id,
        'Mengubah peran ' || v_target.full_name || ' menjadi ' || CASE WHEN p_new_role = 'caretaker' THEN 'Pengelola' ELSE 'Anggota' END
    );
END;
$$;

-- Perbarui kode undangan keluarga (khusus owner)
CREATE OR REPLACE FUNCTION public.regenerate_family_invite_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_actor public.health_profiles;
    v_new_code TEXT;
BEGIN
    SELECT * INTO v_actor FROM public.health_profiles WHERE user_id = auth.uid() LIMIT 1;
    IF v_actor.id IS NULL OR v_actor.role <> 'owner' THEN
        RAISE EXCEPTION 'Hanya Admin Utama yang dapat memperbarui kode undangan';
    END IF;

    LOOP
        v_new_code := public.generate_short_code('JB', 6);
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.families WHERE invite_code = v_new_code);
    END LOOP;

    UPDATE public.families SET invite_code = v_new_code WHERE id = v_actor.family_id;

    INSERT INTO public.activity_logs (
        family_id, target_profile_id, actor_user_id, actor_name,
        action_type, entity_type, entity_id, summary
    ) VALUES (
        v_actor.family_id, NULL, auth.uid(), v_actor.full_name,
        'update', 'family', v_actor.family_id,
        'Memperbarui kode undangan keluarga'
    );

    RETURN v_new_code;
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. SUPABASE STORAGE BUCKET & KEBIJAKAN DOKUMEN PRIVAT
-- ----------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'health-documents',
    'health-documents',
    FALSE,
    5242880, -- Maks 5 MB per file
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "storage_health_docs_select" ON storage.objects;
CREATE POLICY "storage_health_docs_select" ON storage.objects
    FOR SELECT USING (
        CASE
            WHEN bucket_id = 'health-documents'
             AND (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
             AND (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            THEN (storage.foldername(name))[1] = public.get_my_family_id()::TEXT
                 AND public.can_view_profile(((storage.foldername(name))[2])::UUID)
            ELSE FALSE
        END
    );

DROP POLICY IF EXISTS "storage_health_docs_insert" ON storage.objects;
CREATE POLICY "storage_health_docs_insert" ON storage.objects
    FOR INSERT WITH CHECK (
        CASE
            WHEN bucket_id = 'health-documents'
             AND (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
             AND (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            THEN (storage.foldername(name))[1] = public.get_my_family_id()::TEXT
                 AND public.can_edit_profile(((storage.foldername(name))[2])::UUID)
            ELSE FALSE
        END
    );

DROP POLICY IF EXISTS "storage_health_docs_delete" ON storage.objects;
CREATE POLICY "storage_health_docs_delete" ON storage.objects
    FOR DELETE USING (
        CASE
            WHEN bucket_id = 'health-documents'
             AND (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
             AND (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            THEN (storage.foldername(name))[1] = public.get_my_family_id()::TEXT
                 AND public.can_edit_profile(((storage.foldername(name))[2])::UUID)
            ELSE FALSE
        END
    );
