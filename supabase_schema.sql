-- Phase 1: Database Structure

-- Note: Make sure to add the `role` to `auth.users` via `raw_user_meta_data`.
-- Example of setting a role during user creation (in a Supabase Function or server-side code):
-- const { data, error } = await supabase.auth.admin.createUser({
--   email: 'user@example.com',
--   password: 'password',
--   user_metadata: { role: 'school_admin' }
-- })

-- Extension for UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table: schools
CREATE TABLE public.schools (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
COMMENT ON TABLE public.schools IS 'Stores school information.';

-- Table: school_admins
CREATE TABLE public.school_admins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    UNIQUE(user_id)
);
COMMENT ON TABLE public.school_admins IS 'Links school admins from Supabase Auth to their respective schools.';

-- Table: drivers
CREATE TABLE public.drivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL
);
COMMENT ON TABLE public.drivers IS 'Stores driver information.';

-- Table: buses
CREATE TABLE public.buses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    plate_number TEXT NOT NULL,
    driver_id UUID REFERENCES public.drivers(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- For bus panel login
    UNIQUE(plate_number, school_id)
);
COMMENT ON TABLE public.buses IS 'Stores bus information, linking them to schools, drivers, and auth users.';

-- Table: students
CREATE TABLE public.students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    bus_id UUID REFERENCES public.buses(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    bus_stop TEXT, -- Legacy field, kept for backward compatibility
    bus_stop_area TEXT, -- e.g., "Kalimati", "Balaju"
    bus_stop_city TEXT, -- e.g., "Kathmandu"
    bus_stop_country TEXT, -- e.g., "Nepal"
    bus_stop_lat DOUBLE PRECISION,
    bus_stop_lng DOUBLE PRECISION,
    fingerprint_data BYTEA,
    parent1_email TEXT,
    parent2_email TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
COMMENT ON TABLE public.students IS 'Stores student information.';

-- Table: parents
CREATE TABLE public.parents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    relation TEXT CHECK (relation IN ('parent1', 'parent2')),
    UNIQUE(user_id, student_id)
);
COMMENT ON TABLE public.parents IS 'Links parents from Supabase Auth to their children.';

-- Table: bus_trips
CREATE TABLE public.bus_trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bus_id UUID NOT NULL REFERENCES public.buses(id) ON DELETE CASCADE,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE
);
COMMENT ON TABLE public.bus_trips IS 'Records each bus trip.';

-- Table: student_boarding
CREATE TABLE public.student_boarding (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID NOT NULL REFERENCES public.bus_trips(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('boarded', 'unboarded')),
    "timestamp" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
COMMENT ON TABLE public.student_boarding IS 'Tracks student boarding status for each trip.';

-- Table: bus_locations
CREATE TABLE public.bus_locations (
    id BIGSERIAL PRIMARY KEY,
    bus_id UUID NOT NULL REFERENCES public.buses(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    "timestamp" TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
COMMENT ON TABLE public.bus_locations IS 'Stores realtime bus location data.';


-- Phase 4: RLS (Row Level Security)

-- Helper function to get user role from auth.users metadata
CREATE OR REPLACE FUNCTION get_my_claim(claim TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN (auth.jwt() -> 'raw_user_meta_data' ->> claim);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get school_id for the current school_admin
CREATE OR REPLACE FUNCTION get_my_school_id()
RETURNS UUID AS $$
DECLARE
  school_uuid UUID;
BEGIN
  SELECT school_id INTO school_uuid FROM public.school_admins WHERE user_id = auth.uid();
  RETURN school_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Enable RLS for all tables
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.buses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bus_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_boarding ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bus_locations ENABLE ROW LEVEL SECURITY;


-- RLS Policies

-- 1. Superadmins can do anything
CREATE POLICY "Superadmins can manage all records" ON public.schools FOR ALL USING (get_my_claim('role') = 'superadmin') WITH CHECK (get_my_claim('role') = 'superadmin');
CREATE POLICY "Superadmins can manage all records" ON public.school_admins FOR ALL USING (get_my_claim('role') = 'superadmin') WITH CHECK (get_my_claim('role') = 'superadmin');
CREATE POLICY "Superadmins can manage all records" ON public.drivers FOR ALL USING (get_my_claim('role') = 'superadmin') WITH CHECK (get_my_claim('role') = 'superadmin');
CREATE POLICY "Superadmins can manage all records" ON public.buses FOR ALL USING (get_my_claim('role') = 'superadmin') WITH CHECK (get_my_claim('role') = 'superadmin');
CREATE POLICY "Superadmins can manage all records" ON public.students FOR ALL USING (get_my_claim('role') = 'superadmin') WITH CHECK (get_my_claim('role') = 'superadmin');
CREATE POLICY "Superadmins can manage all records" ON public.parents FOR ALL USING (get_my_claim('role') = 'superadmin') WITH CHECK (get_my_claim('role') = 'superadmin');
CREATE POLICY "Superadmins can manage all records" ON public.bus_trips FOR ALL USING (get_my_claim('role') = 'superadmin') WITH CHECK (get_my_claim('role') = 'superadmin');
CREATE POLICY "Superadmins can manage all records" ON public.student_boarding FOR ALL USING (get_my_claim('role') = 'superadmin') WITH CHECK (get_my_claim('role') = 'superadmin');
CREATE POLICY "Superadmins can manage all records" ON public.bus_locations FOR ALL USING (get_my_claim('role') = 'superadmin') WITH CHECK (get_my_claim('role') = 'superadmin');


-- 2. School Admins can manage data for their own school
DROP POLICY IF EXISTS "School admins can view their own school" ON public.schools;
DROP POLICY IF EXISTS "School admins can update their own school" ON public.schools;
CREATE POLICY "School admins can view their own school" ON public.schools FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.school_admins sa
    WHERE sa.user_id = auth.uid() AND sa.school_id = schools.id
  )
);
CREATE POLICY "School admins can update their own school" ON public.schools FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.school_admins sa
    WHERE sa.user_id = auth.uid() AND sa.school_id = schools.id
  )
);

-- Replace recursive policy on school_admins with user_id-based rules to avoid recursion
DROP POLICY IF EXISTS "School admins can manage their school data" ON public.school_admins;
CREATE POLICY "School admins can view their link row" ON public.school_admins FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "School admins can update their link row" ON public.school_admins FOR UPDATE USING (user_id = auth.uid());
DROP POLICY IF EXISTS "School admins can manage their school data" ON public.drivers;
DROP POLICY IF EXISTS "School admins can manage their school data" ON public.buses;
DROP POLICY IF EXISTS "School admins can manage their school data" ON public.students;
DROP POLICY IF EXISTS "School admins can manage their drivers" ON public.drivers;
CREATE POLICY "School admins can manage their drivers" ON public.drivers FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.school_admins sa
    WHERE sa.user_id = auth.uid() AND sa.school_id = drivers.school_id
  )
);
DROP POLICY IF EXISTS "School admins can manage their buses" ON public.buses;
CREATE POLICY "School admins can manage their buses" ON public.buses FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.school_admins sa
    WHERE sa.user_id = auth.uid() AND sa.school_id = buses.school_id
  )
);
DROP POLICY IF EXISTS "School admins can manage their students" ON public.students;
CREATE POLICY "School admins can manage their students" ON public.students FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.school_admins sa
    WHERE sa.user_id = auth.uid() AND sa.school_id = students.school_id
  )
);

-- 3. Parents can only see data related to their own child
DROP POLICY IF EXISTS "Parents can view their own child's student record" ON public.students;
CREATE POLICY "Parents can view their own child's student record" ON public.students FOR SELECT USING (
  fn_is_my_child(id)
);

DROP POLICY IF EXISTS "Parents can view their own parent record" ON public.parents;
CREATE POLICY "Parents can view their own parent record" ON public.parents FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Parents can view their child's bus" ON public.buses;
CREATE POLICY "Parents can view their child's bus" ON public.buses FOR SELECT USING (
  id IN (SELECT * FROM public.fn_my_bus_ids())
);

DROP POLICY IF EXISTS "Parents can view their child's bus location" ON public.bus_locations;
CREATE POLICY "Parents can view their child's bus location" ON public.bus_locations FOR SELECT USING (
  bus_id IN (SELECT * FROM public.fn_my_bus_ids())
);

-- Allow school admins to view bus locations for their school (needed for Map screen)
DROP POLICY IF EXISTS "School admins can view bus locations for their school" ON public.bus_locations;
CREATE POLICY "School admins can view bus locations for their school" ON public.bus_locations FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.buses b
    JOIN public.school_admins sa ON sa.school_id = b.school_id
    WHERE sa.user_id = auth.uid() AND b.id = bus_locations.bus_id
  )
);
CREATE POLICY "Parents can view their child's boarding status" ON public.student_boarding FOR SELECT USING (student_id IN (SELECT student_id FROM public.parents WHERE user_id = auth.uid()));

-- 4. Bus accounts can only see their own data and assigned students
CREATE POLICY "Bus can see its own record" ON public.buses FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Bus can update its own location" ON public.bus_locations FOR INSERT WITH CHECK (bus_id = (SELECT id FROM public.buses WHERE user_id = auth.uid()));
CREATE POLICY "Bus can manage its own trips" ON public.bus_trips FOR ALL USING (bus_id = (SELECT id FROM public.buses WHERE user_id = auth.uid()));
CREATE POLICY "Bus can see assigned students" ON public.students FOR SELECT USING (
  bus_id IN (SELECT id FROM public.buses WHERE user_id = auth.uid())
);
CREATE POLICY "Bus can update boarding status for assigned students" ON public.student_boarding FOR INSERT WITH CHECK (student_id IN (SELECT id FROM public.students WHERE bus_id = (SELECT id FROM public.buses WHERE user_id = auth.uid())));
CREATE POLICY "Bus can view boarding for its trips" ON public.student_boarding FOR SELECT USING (
  trip_id IN (
    SELECT id FROM public.bus_trips WHERE bus_id IN (
      SELECT id FROM public.buses WHERE user_id = auth.uid()
    )
  )
);

-- Allow bus accounts to enroll fingerprints for their assigned students
DROP POLICY IF EXISTS "Bus can update assigned students (fingerprint)" ON public.students;
CREATE POLICY "Bus can update assigned students (fingerprint)" ON public.students
FOR UPDATE
USING (
  -- Only rows for students on the current bus account
  bus_id IN (SELECT id FROM public.buses WHERE user_id = auth.uid())
)
WITH CHECK (
  -- Ensure the new row still belongs to the same bus
  bus_id IN (SELECT id FROM public.buses WHERE user_id = auth.uid())
);


-- Enable realtime for bus_locations and student_boarding
BEGIN;
  -- remove the realtime publication
  DROP PUBLICATION IF EXISTS supabase_realtime;

  -- re-create the publication but don't enable it for any tables
  CREATE PUBLICATION supabase_realtime;
COMMIT;

-- add tables to the publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.bus_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.student_boarding;

-- Parent notifications (persistent in-app feed)
-- Table to persist notifications per parent user
CREATE TABLE IF NOT EXISTS public.parent_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('boarding','unboarding','arrival','home_reached','drop','info')),
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);
COMMENT ON TABLE public.parent_notifications IS 'Persistent notification feed for Parent Panel (in-app only).';

-- Enable RLS
ALTER TABLE public.parent_notifications ENABLE ROW LEVEL SECURITY;

-- RLS: parents can read only their own notifications
DROP POLICY IF EXISTS "Parents can read their own notifications" ON public.parent_notifications;
CREATE POLICY "Parents can read their own notifications"
  ON public.parent_notifications FOR SELECT
  USING (parent_user_id = auth.uid());

-- RLS: service/authorized roles can insert (frontends insert as the authenticated parent)
DROP POLICY IF EXISTS "Parents can insert their notifications" ON public.parent_notifications;
CREATE POLICY "Parents can insert their notifications"
  ON public.parent_notifications FOR INSERT
  WITH CHECK (parent_user_id = auth.uid());

-- Optional: allow deletes by the same parent (clean up)
DROP POLICY IF EXISTS "Parents can delete their notifications" ON public.parent_notifications;
CREATE POLICY "Parents can delete their notifications"
  ON public.parent_notifications FOR DELETE
  USING (parent_user_id = auth.uid());

-- Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.parent_notifications;

-- Parent OTPs table for single-use one-time passwords
CREATE TABLE IF NOT EXISTS public.parent_otps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  otp_code TEXT NOT NULL,
  is_used BOOLEAN NOT NULL DEFAULT false,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now())
);
COMMENT ON TABLE public.parent_otps IS 'Stores one-time passwords for parent first-time login.';

-- Enable RLS
ALTER TABLE public.parent_otps ENABLE ROW LEVEL SECURITY;

-- RLS: parents can read their own OTP records
DROP POLICY IF EXISTS "Parents can read their own OTPs" ON public.parent_otps;
CREATE POLICY "Parents can read their own OTPs"
  ON public.parent_otps FOR SELECT
  USING (user_id = auth.uid());

-- RLS: parents can update their own OTP records (to mark as used)
DROP POLICY IF EXISTS "Parents can update their own OTPs" ON public.parent_otps;
CREATE POLICY "Parents can update their own OTPs"
  ON public.parent_otps FOR UPDATE
  USING (user_id = auth.uid());

-- Trigger: persist notifications for boarding/unboarding
CREATE OR REPLACE FUNCTION public.fn_notify_parent_on_boarding()
RETURNS TRIGGER AS $$
DECLARE
  msg TEXT;
BEGIN
  IF NEW.status = 'boarded' THEN
    msg := 'Your child has boarded the bus';
  ELSIF NEW.status = 'unboarded' THEN
    msg := 'Your child has unboarded the bus';
  ELSE
    RETURN NEW; -- ignore unknown
  END IF;

  INSERT INTO public.parent_notifications (parent_user_id, type, message)
  SELECT p.user_id, 'boarding', msg
  FROM public.parents p
  WHERE p.student_id = NEW.student_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_parent_on_boarding ON public.student_boarding;
CREATE TRIGGER trg_notify_parent_on_boarding
AFTER INSERT ON public.student_boarding
FOR EACH ROW EXECUTE FUNCTION public.fn_notify_parent_on_boarding();
