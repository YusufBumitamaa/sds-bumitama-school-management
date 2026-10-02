/*
  Migration 016
  Student Activities

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan kegiatan kesiswaan.
  - Mendukung kegiatan yang melibatkan banyak siswa.
  - Menyimpan informasi jadwal, lokasi, penanggung jawab,
    dan dokumentasi kegiatan.
*/


/* =========================================================
   1. ENUM ACTIVITY STATUS
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'student_activity_status'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.student_activity_status as enum (
      'rencana',
      'berlangsung',
      'selesai',
      'dibatalkan'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE: student_activities
   ========================================================= */

create table if not exists public.student_activities (
  id uuid primary key default gen_random_uuid(),

  activity_name text not null,

  category text,

  description text,

  activity_date date,

  start_time time,

  end_time time,

  location text,

  organizer text,

  person_in_charge text,

  target_participants text,

  budget numeric(15,2),

  status public.student_activity_status not null default 'rencana',

  document_number text,

  document_date date,

  documentation_url text,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint student_activities_time_check
    check (
      end_time is null
      or start_time is null
      or end_time >= start_time
    ),

  constraint student_activities_budget_check
    check (
      budget is null
      or budget >= 0
    )
);


/* =========================================================
   3. COMMENTS
   ========================================================= */

comment on table public.student_activities is
  'Data kegiatan kesiswaan sekolah.';

comment on column public.student_activities.activity_name is
  'Nama kegiatan kesiswaan.';

comment on column public.student_activities.category is
  'Kategori kegiatan, misalnya pramuka, olahraga, seni, sosial, keagamaan, dan lainnya.';

comment on column public.student_activities.person_in_charge is
  'Nama penanggung jawab kegiatan.';

comment on column public.student_activities.target_participants is
  'Target atau kelompok peserta kegiatan.';

comment on column public.student_activities.documentation_url is
  'Lokasi dokumentasi kegiatan pada Supabase Storage atau penyimpanan dokumen.';


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  student_activities_name_idx
on public.student_activities(activity_name);

create index if not exists
  student_activities_date_idx
on public.student_activities(activity_date desc);

create index if not exists
  student_activities_category_idx
on public.student_activities(category);

create index if not exists
  student_activities_status_idx
on public.student_activities(status);

create index if not exists
  student_activities_created_by_idx
on public.student_activities(created_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  student_activities_set_updated_at
on public.student_activities;

create trigger student_activities_set_updated_at
before update on public.student_activities
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.student_activities enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  student_activities_select_with_permission
on public.student_activities;

create policy student_activities_select_with_permission
on public.student_activities
for select
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  student_activities_insert_with_permission
on public.student_activities;

create policy student_activities_insert_with_permission
on public.student_activities
for insert
to authenticated
with check (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  student_activities_update_with_permission
on public.student_activities;

create policy student_activities_update_with_permission
on public.student_activities
for update
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'update')
)
with check (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  student_activities_delete_with_permission
on public.student_activities;

create policy student_activities_delete_with_permission
on public.student_activities
for delete
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kesiswaan', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.student_activities
to authenticated;