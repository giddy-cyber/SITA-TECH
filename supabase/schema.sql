create table if not exists public.sita_profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    full_name text not null,
    role text not null default 'student' check (role in ('student', 'staff')),
    created_at timestamptz not null default now()
);

create table if not exists public.sita_courses (
    course_code text primary key,
    title text not null,
    active boolean not null default true
);

create table if not exists public.sita_enrollment_applications (
    id uuid primary key default gen_random_uuid(),
    full_name text not null check (char_length(btrim(full_name)) between 2 and 120),
    email text not null check (char_length(email) between 3 and 254),
    phone text not null check (char_length(phone) between 7 and 32),
    course_name text not null check (char_length(course_name) between 1 and 120),
    topics text check (topics is null or char_length(topics) <= 2000),
    created_at timestamptz not null default now()
);

create table if not exists public.sita_enrollments (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null references public.sita_profiles (id) on delete cascade,
    course_code text not null references public.sita_courses (course_code),
    status text not null default 'pending' check (status in ('pending', 'active', 'suspended', 'completed')),
    created_at timestamptz not null default now(),
    unique (student_id, course_code)
);

create table if not exists public.sita_payments (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null references public.sita_profiles (id) on delete cascade,
    enrollment_id uuid not null references public.sita_enrollments (id) on delete cascade,
    amount numeric(12, 2) not null check (amount > 0),
    currency text not null default 'KES' check (currency = 'KES'),
    provider text not null default 'mpesa' check (provider = 'mpesa'),
    transaction_ref text unique,
    status text not null default 'pending' check (status in ('pending', 'confirmed', 'failed')),
    paid_at timestamptz,
    created_at timestamptz not null default now()
);

create table if not exists public.sita_module_progress (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null references public.sita_profiles (id) on delete cascade,
    course_code text not null references public.sita_courses (course_code),
    module_key text not null check (char_length(module_key) between 1 and 100),
    completed_at timestamptz not null default now(),
    unique (student_id, course_code, module_key)
);

create table if not exists public.sita_class_sessions (
    id uuid primary key default gen_random_uuid(),
    title text not null check (char_length(title) between 1 and 160),
    course_code text not null,
    starts_at timestamptz not null,
    meeting_url text not null check (meeting_url like 'https://%'),
    created_at timestamptz not null default now()
);

create table if not exists public.sita_certificates (
    id uuid primary key default gen_random_uuid(),
    student_id uuid not null references public.sita_profiles (id) on delete cascade,
    enrollment_id uuid not null references public.sita_enrollments (id) on delete cascade,
    certificate_number text not null unique,
    issued_at timestamptz not null default now(),
    issued_by uuid not null references public.sita_profiles (id)
);

create or replace function public.sita_create_student_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.sita_profiles (id, full_name)
    values (
        new.id,
        coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), new.email)
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists sita_create_student_profile_after_signup on auth.users;
create trigger sita_create_student_profile_after_signup
after insert on auth.users
for each row execute function public.sita_create_student_profile();
revoke all on function public.sita_create_student_profile() from public, anon, authenticated;

create or replace function public.sita_is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.sita_profiles
        where id = (select auth.uid())
          and role = 'staff'
    );
$$;

revoke all on function public.sita_is_staff() from public, anon;
grant execute on function public.sita_is_staff() to authenticated;

insert into public.sita_courses (course_code, title) values
    ('comp', 'Computer Packages'),
    ('web', 'Web Design'),
    ('gfx', 'Graphic Design'),
    ('hw', 'Computer Hardware & Repair'),
    ('por', 'Digital Portal Skills'),
    ('vid', 'Video Editing & Content'),
    ('cyb', 'Cyber Safety & Security')
on conflict (course_code) do update set title = excluded.title;

alter table public.sita_profiles enable row level security;
alter table public.sita_courses enable row level security;
alter table public.sita_enrollment_applications enable row level security;
alter table public.sita_enrollments enable row level security;
alter table public.sita_payments enable row level security;
alter table public.sita_module_progress enable row level security;
alter table public.sita_class_sessions enable row level security;
alter table public.sita_certificates enable row level security;

revoke all on table public.sita_profiles, public.sita_courses, public.sita_enrollment_applications,
    public.sita_enrollments, public.sita_payments, public.sita_module_progress,
    public.sita_class_sessions, public.sita_certificates from anon, authenticated;

grant select on table public.sita_profiles, public.sita_courses, public.sita_enrollments,
    public.sita_payments, public.sita_module_progress, public.sita_class_sessions,
    public.sita_certificates to authenticated;
grant insert on table public.sita_enrollment_applications to anon, authenticated;
grant select on table public.sita_enrollment_applications to authenticated;
grant insert, update, delete on table public.sita_courses, public.sita_enrollments,
    public.sita_payments, public.sita_module_progress, public.sita_class_sessions,
    public.sita_certificates to authenticated;

drop policy if exists "SITA profiles visible to owner and staff" on public.sita_profiles;
create policy "SITA profiles visible to owner and staff"
on public.sita_profiles for select to authenticated
using (id = (select auth.uid()) or (select public.sita_is_staff()));

drop policy if exists "SITA active courses visible to signed-in users" on public.sita_courses;
create policy "SITA active courses visible to signed-in users"
on public.sita_courses for select to authenticated
using (active or (select public.sita_is_staff()));

drop policy if exists "SITA staff manage courses" on public.sita_courses;
create policy "SITA staff manage courses"
on public.sita_courses for all to authenticated
using ((select public.sita_is_staff()))
with check ((select public.sita_is_staff()));

drop policy if exists "SITA public enrollment application submission" on public.sita_enrollment_applications;
create policy "SITA public enrollment application submission"
on public.sita_enrollment_applications for insert to anon, authenticated
with check (
    char_length(btrim(full_name)) between 2 and 120
    and char_length(email) between 3 and 254
    and char_length(phone) between 7 and 32
    and char_length(course_name) between 1 and 120
    and (topics is null or char_length(topics) <= 2000)
);

drop policy if exists "SITA staff read enrollment applications" on public.sita_enrollment_applications;
create policy "SITA staff read enrollment applications"
on public.sita_enrollment_applications for select to authenticated
using ((select public.sita_is_staff()));

drop policy if exists "SITA students and staff read enrollments" on public.sita_enrollments;
create policy "SITA students and staff read enrollments"
on public.sita_enrollments for select to authenticated
using (student_id = (select auth.uid()) or (select public.sita_is_staff()));

drop policy if exists "SITA staff manage enrollments" on public.sita_enrollments;
create policy "SITA staff manage enrollments"
on public.sita_enrollments for all to authenticated
using ((select public.sita_is_staff()))
with check ((select public.sita_is_staff()));

drop policy if exists "SITA students and staff read payments" on public.sita_payments;
create policy "SITA students and staff read payments"
on public.sita_payments for select to authenticated
using (student_id = (select auth.uid()) or (select public.sita_is_staff()));

drop policy if exists "SITA staff manage payments" on public.sita_payments;
create policy "SITA staff manage payments"
on public.sita_payments for all to authenticated
using ((select public.sita_is_staff()))
with check (
    (select public.sita_is_staff())
    and exists (
        select 1 from public.sita_enrollments
        where id = enrollment_id and student_id = sita_payments.student_id
    )
);

drop policy if exists "SITA students and staff read module progress" on public.sita_module_progress;
create policy "SITA students and staff read module progress"
on public.sita_module_progress for select to authenticated
using (student_id = (select auth.uid()) or (select public.sita_is_staff()));

drop policy if exists "SITA students save own enrolled course progress" on public.sita_module_progress;
create policy "SITA students save own enrolled course progress"
on public.sita_module_progress for insert to authenticated
with check (
    student_id = (select auth.uid())
    and exists (
        select 1 from public.sita_enrollments
        where student_id = (select auth.uid())
          and course_code = sita_module_progress.course_code
          and status = 'active'
    )
);

drop policy if exists "SITA students update own enrolled course progress" on public.sita_module_progress;
create policy "SITA students update own enrolled course progress"
on public.sita_module_progress for update to authenticated
using (
    student_id = (select auth.uid())
    and exists (
        select 1 from public.sita_enrollments
        where student_id = (select auth.uid())
          and course_code = sita_module_progress.course_code
          and status = 'active'
    )
)
with check (
    student_id = (select auth.uid())
    and exists (
        select 1 from public.sita_enrollments
        where student_id = (select auth.uid())
          and course_code = sita_module_progress.course_code
          and status = 'active'
    )
);

drop policy if exists "SITA staff manage module progress" on public.sita_module_progress;
create policy "SITA staff manage module progress"
on public.sita_module_progress for all to authenticated
using ((select public.sita_is_staff()))
with check ((select public.sita_is_staff()));

drop policy if exists "SITA enrolled students read class sessions" on public.sita_class_sessions;
create policy "SITA enrolled students read class sessions"
on public.sita_class_sessions for select to authenticated
using (
    (select public.sita_is_staff())
    or exists (
        select 1 from public.sita_enrollments
        where student_id = (select auth.uid())
          and status = 'active'
          and (course_code = sita_class_sessions.course_code or sita_class_sessions.course_code = 'all')
    )
);

drop policy if exists "SITA staff manage class sessions" on public.sita_class_sessions;
create policy "SITA staff manage class sessions"
on public.sita_class_sessions for all to authenticated
using ((select public.sita_is_staff()))
with check ((select public.sita_is_staff()));

drop policy if exists "SITA students and staff read certificates" on public.sita_certificates;
create policy "SITA students and staff read certificates"
on public.sita_certificates for select to authenticated
using (student_id = (select auth.uid()) or (select public.sita_is_staff()));

drop policy if exists "SITA staff manage certificates" on public.sita_certificates;
create policy "SITA staff manage certificates"
on public.sita_certificates for all to authenticated
using ((select public.sita_is_staff()))
with check (
    (select public.sita_is_staff())
    and exists (
        select 1 from public.sita_enrollments
        where id = enrollment_id and student_id = sita_certificates.student_id
    )
);
