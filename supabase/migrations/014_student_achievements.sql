/*
  Migration 014
  Student Achievements

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan prestasi siswa.
  - Mendukung prestasi akademik dan non-akademik.
  - Satu siswa dapat memiliki banyak prestasi.
*/


/* =========================================================
   1. ENUM ACHIEVEMENT LEVEL
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'achievement_level'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.achievement_level as enum (
      'sekolah',
      'kecamatan',
      'kabupaten',
      'provinsi',
      'nasional',
      'internasional'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE: student_achievements
   ========================================================= */

create table if not exists public.student_achievements (
  id uuid primary key default gen_random_uuid(),

  student_id uuid not null
    references public.students(id)
    on delete restrict,

  achievement_date date not null,

  achievement_name text not null,

  category text,

  level public.achievement_level,

  rank text,

  organizer text,

  event_name text,

  document_number text,

  document_date date,

  certificate_url text,

  description text,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now()
);


/* =========================================================
   3. COMMENTS
   ========================================================= */

comment on table public.student_achievements is
  'Data prestasi akademik dan non-akademik siswa.';

comment on column public.student_achievements.achievement_name is
  'Nama atau bentuk prestasi yang diraih siswa.';

comment on column public.student_achievements.category is
  'Kategori prestasi, misalnya akademik, olahraga, seni, keagamaan, atau lainnya.';

comment on column public.student_achievements.level is
  'Tingkat prestasi dari sekolah sampai internasional.';

comment on column public.student_achievements.rank is
  'Peringkat atau hasil yang diperoleh siswa.';

comment on column public.student_achievements.certificate_url is
  'Lokasi dokumen sertifikat pada Supabase Storage atau penyimpanan dokumen.';


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  student_achievements_student_id_idx
on public.student_achievements(student_id);

create index if not exists
  student_achievements_date_idx
on public.student_achievements(achievement_date desc);

create index if not exists
  student_achievements_level_idx
on public.student_achievements(level);

create index if not exists
  student_achievements_category_idx
on public.student_achievements(category);

create index if not exists
  student_achievements_created_by_idx
on public.student_achievements(created_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  student_achievements_set_updated_at
on public.student_achievements;

create trigger student_achievements_set_updated_at
before update on public.student_achievements
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.student_achievements enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  student_achievements_select_with_permission
on public.student_achievements;

create policy student_achievements_select_with_permission
on public.student_achievements
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
  student_achievements_insert_with_permission
on public.student_achievements;

create policy student_achievements_insert_with_permission
on public.student_achievements
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
  student_achievements_update_with_permission
on public.student_achievements;

create policy student_achievements_update_with_permission
on public.student_achievements
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
  student_achievements_delete_with_permission
on public.student_achievements;

create policy student_achievements_delete_with_permission
on public.student_achievements
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
on public.student_achievements
to authenticated;