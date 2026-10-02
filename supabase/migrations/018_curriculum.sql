/*
  Migration 018
  Curriculum Structure

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan struktur kurikulum per tahun ajaran.
  - Menghubungkan tahun ajaran dengan mata pelajaran.
  - Menentukan tingkat kelas yang menggunakan mata pelajaran.
  - Menyimpan alokasi jam pelajaran.
*/


/* =========================================================
   1. TABLE: curriculum
   ========================================================= */

create table if not exists public.curriculum (
  id uuid primary key default gen_random_uuid(),

  academic_year_id uuid not null
    references public.academic_years(id)
    on delete restrict,

  subject_id uuid not null
    references public.subjects(id)
    on delete restrict,

  grade_level smallint not null,

  curriculum_name text,

  learning_hours_per_week numeric(5,2),

  minimum_passing_grade numeric(5,2),

  is_mandatory boolean not null default true,

  is_active boolean not null default true,

  notes text,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint curriculum_grade_level_check
    check (
      grade_level between 1 and 12
    ),

  constraint curriculum_learning_hours_check
    check (
      learning_hours_per_week is null
      or learning_hours_per_week > 0
    ),

  constraint curriculum_minimum_passing_grade_check
    check (
      minimum_passing_grade is null
      or (
        minimum_passing_grade >= 0
        and minimum_passing_grade <= 100
      )
    ),

  constraint curriculum_unique_structure
    unique (
      academic_year_id,
      subject_id,
      grade_level
    )
);


/* =========================================================
   2. COMMENTS
   ========================================================= */

comment on table public.curriculum is
  'Struktur kurikulum mata pelajaran berdasarkan tahun ajaran dan tingkat kelas.';

comment on column public.curriculum.academic_year_id is
  'Tahun ajaran yang menggunakan struktur kurikulum.';

comment on column public.curriculum.subject_id is
  'Mata pelajaran yang digunakan dalam struktur kurikulum.';

comment on column public.curriculum.grade_level is
  'Tingkat kelas yang menggunakan mata pelajaran, misalnya 1 sampai 6 untuk SD.';

comment on column public.curriculum.curriculum_name is
  'Nama kurikulum yang digunakan, misalnya Kurikulum Merdeka.';

comment on column public.curriculum.learning_hours_per_week is
  'Alokasi jam pelajaran per minggu.';

comment on column public.curriculum.minimum_passing_grade is
  'Nilai batas minimum yang digunakan sekolah jika ditetapkan.';

comment on column public.curriculum.is_mandatory is
  'Menentukan apakah mata pelajaran wajib atau tidak wajib.';


/* =========================================================
   3. INDEXES
   ========================================================= */

create index if not exists
  curriculum_academic_year_idx
on public.curriculum(academic_year_id);

create index if not exists
  curriculum_subject_idx
on public.curriculum(subject_id);

create index if not exists
  curriculum_grade_level_idx
on public.curriculum(grade_level);

create index if not exists
  curriculum_active_idx
on public.curriculum(is_active);


/* =========================================================
   4. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  curriculum_set_updated_at
on public.curriculum;

create trigger curriculum_set_updated_at
before update on public.curriculum
for each row
execute function public.set_updated_at();


/* =========================================================
   5. ROW LEVEL SECURITY
   ========================================================= */

alter table public.curriculum enable row level security;


/* =========================================================
   6. SELECT POLICY
   ========================================================= */

drop policy if exists
  curriculum_select_with_permission
on public.curriculum;

create policy curriculum_select_with_permission
on public.curriculum
for select
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'view')
);


/* =========================================================
   7. INSERT POLICY
   ========================================================= */

drop policy if exists
  curriculum_insert_with_permission
on public.curriculum;

create policy curriculum_insert_with_permission
on public.curriculum
for insert
to authenticated
with check (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'create')
);


/* =========================================================
   8. UPDATE POLICY
   ========================================================= */

drop policy if exists
  curriculum_update_with_permission
on public.curriculum;

create policy curriculum_update_with_permission
on public.curriculum
for update
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'update')
)
with check (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'update')
);


/* =========================================================
   9. DELETE POLICY
   ========================================================= */

drop policy if exists
  curriculum_delete_with_permission
on public.curriculum;

create policy curriculum_delete_with_permission
on public.curriculum
for delete
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'delete')
);


/* =========================================================
   10. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.curriculum
to authenticated;