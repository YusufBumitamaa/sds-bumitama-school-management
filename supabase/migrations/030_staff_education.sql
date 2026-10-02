/*
  Migration 030
  Staff Education History

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan riwayat pendidikan formal Guru/Tendik.
  - Data dipisahkan dari profil utama teachers_staff.
  - Mendukung lebih dari satu riwayat pendidikan untuk satu GTK.
*/


/* =========================================================
   1. ENUM JENJANG PENDIDIKAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'education_level'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.education_level as enum (
      'sd',
      'smp',
      'sma',
      'smk',
      'd1',
      'd2',
      'd3',
      'd4',
      's1',
      's2',
      's3'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE STAFF EDUCATION
   ========================================================= */

create table if not exists public.staff_education (
  id uuid primary key default gen_random_uuid(),

  staff_id uuid not null
    references public.teachers_staff(id)
    on delete restrict,

  education_level public.education_level not null,

  institution_name text not null,

  major text,

  city text,

  country text default 'Indonesia',

  enrollment_year integer,

  graduation_year integer,

  diploma_number text,

  degree_title text,

  is_highest_education boolean not null
    default false,

  notes text,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint staff_education_enrollment_year_check
    check (
      enrollment_year is null
      or (
        enrollment_year >= 1900
        and enrollment_year <= 2100
      )
    ),

  constraint staff_education_graduation_year_check
    check (
      graduation_year is null
      or (
        graduation_year >= 1900
        and graduation_year <= 2100
      )
    ),

  constraint staff_education_year_order_check
    check (
      enrollment_year is null
      or graduation_year is null
      or graduation_year >= enrollment_year
    ),

  constraint staff_education_institution_check
    check (
      length(trim(institution_name)) > 0
    )
);


/* =========================================================
   3. INDEXES
   ========================================================= */

create index if not exists
  idx_staff_education_staff
on public.staff_education(staff_id);

create index if not exists
  idx_staff_education_level
on public.staff_education(education_level);

create index if not exists
  idx_staff_education_graduation_year
on public.staff_education(graduation_year);

create index if not exists
  idx_staff_education_highest
on public.staff_education(is_highest_education);


/* =========================================================
   4. UNIQUE HIGHEST EDUCATION
   =========================================================

   Satu GTK hanya boleh memiliki satu pendidikan
   yang ditandai sebagai pendidikan tertinggi.
*/

create unique index if not exists
  uq_staff_education_highest
on public.staff_education(staff_id)
where is_highest_education = true;


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  staff_education_set_updated_at
on public.staff_education;

create trigger staff_education_set_updated_at
before update
on public.staff_education
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.staff_education enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  staff_education_select
on public.staff_education;

create policy staff_education_select
on public.staff_education
for select
to authenticated
using (
  public.has_permission('gtk', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  staff_education_insert
on public.staff_education;

create policy staff_education_insert
on public.staff_education
for insert
to authenticated
with check (
  public.has_permission('gtk', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  staff_education_update
on public.staff_education;

create policy staff_education_update
on public.staff_education
for update
to authenticated
using (
  public.has_permission('gtk', 'update')
)
with check (
  public.has_permission('gtk', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  staff_education_delete
on public.staff_education;

create policy staff_education_delete
on public.staff_education
for delete
to authenticated
using (
  public.has_permission('gtk', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.staff_education
to authenticated;


/* =========================================================
   12. COMMENTS
   ========================================================= */

comment on table public.staff_education is
  'Riwayat pendidikan formal Guru dan Tenaga Kependidikan.';

comment on column public.staff_education.staff_id is
  'GTK yang memiliki riwayat pendidikan.';

comment on column public.staff_education.education_level is
  'Jenjang pendidikan formal.';

comment on column public.staff_education.institution_name is
  'Nama sekolah, perguruan tinggi, atau institusi pendidikan.';

comment on column public.staff_education.major is
  'Program studi atau jurusan.';

comment on column public.staff_education.diploma_number is
  'Nomor ijazah atau dokumen kelulusan.';

comment on column public.staff_education.degree_title is
  'Gelar akademik yang diperoleh.';

comment on column public.staff_education.is_highest_education is
  'Menandai pendidikan tertinggi GTK.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */