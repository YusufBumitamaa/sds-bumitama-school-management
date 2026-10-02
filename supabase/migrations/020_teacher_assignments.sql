/*
  Migration 020
  Teacher Assignments

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menghubungkan Guru dengan Tahun Ajaran.
  - Menghubungkan Guru dengan Kelas.
  - Menghubungkan Guru dengan Mata Pelajaran.
  - Mendukung penugasan Guru Mata Pelajaran.
  - Mendukung penugasan Wali Kelas.
*/


/* =========================================================
   1. ENUM ASSIGNMENT TYPE
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'teacher_assignment_type'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.teacher_assignment_type as enum (
      'guru_mapel',
      'wali_kelas'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE: teacher_assignments
   ========================================================= */

create table if not exists public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),

  teacher_id uuid not null
    references public.teachers_staff(id)
    on delete restrict,

  academic_year_id uuid not null
    references public.academic_years(id)
    on delete restrict,

  class_id uuid
    references public.classes(id)
    on delete restrict,

  subject_id uuid
    references public.subjects(id)
    on delete restrict,

  assignment_type public.teacher_assignment_type not null
    default 'guru_mapel',

  start_date date,

  end_date date,

  is_active boolean not null default true,

  notes text,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint teacher_assignments_date_check
    check (
      end_date is null
      or start_date is null
      or end_date >= start_date
    ),

  constraint teacher_assignments_subject_required
    check (
      assignment_type = 'wali_kelas'
      or subject_id is not null
    ),

  constraint teacher_assignments_class_required
    check (
      assignment_type = 'wali_kelas'
      or class_id is not null
    ),

  constraint teacher_assignments_homeroom_class_required
    check (
      assignment_type = 'guru_mapel'
      or class_id is not null
    )
);


/* =========================================================
   3. COMMENTS
   ========================================================= */

comment on table public.teacher_assignments is
  'Penugasan guru berdasarkan tahun ajaran, kelas, dan mata pelajaran.';

comment on column public.teacher_assignments.teacher_id is
  'Guru yang mendapatkan penugasan.';

comment on column public.teacher_assignments.academic_year_id is
  'Tahun ajaran penugasan.';

comment on column public.teacher_assignments.class_id is
  'Rombongan belajar yang terkait dengan penugasan.';

comment on column public.teacher_assignments.subject_id is
  'Mata pelajaran yang diajarkan. Tidak diperlukan untuk wali kelas.';

comment on column public.teacher_assignments.assignment_type is
  'Jenis penugasan: guru mata pelajaran atau wali kelas.';

comment on column public.teacher_assignments.is_active is
  'Menentukan apakah penugasan masih aktif.';


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  teacher_assignments_teacher_idx
on public.teacher_assignments(teacher_id);

create index if not exists
  teacher_assignments_academic_year_idx
on public.teacher_assignments(academic_year_id);

create index if not exists
  teacher_assignments_class_idx
on public.teacher_assignments(class_id);

create index if not exists
  teacher_assignments_subject_idx
on public.teacher_assignments(subject_id);

create index if not exists
  teacher_assignments_type_idx
on public.teacher_assignments(assignment_type);

create index if not exists
  teacher_assignments_active_idx
on public.teacher_assignments(is_active);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  teacher_assignments_set_updated_at
on public.teacher_assignments;

create trigger teacher_assignments_set_updated_at
before update on public.teacher_assignments
for each row
execute function public.set_updated_at();


/* =========================================================
   6. UNIQUE ACTIVE HOMEROOM TEACHER
   ========================================================= */

/*
  Satu kelas hanya boleh mempunyai satu wali kelas aktif
  dalam satu tahun ajaran.
*/

create unique index if not exists
  teacher_assignments_one_active_homeroom_idx
on public.teacher_assignments (
  academic_year_id,
  class_id
)
where assignment_type = 'wali_kelas'
  and is_active = true;


/* =========================================================
   7. UNIQUE ACTIVE SUBJECT ASSIGNMENT
   ========================================================= */

/*
  Mencegah duplikasi penugasan guru yang sama untuk
  kombinasi:
  Tahun Ajaran + Guru + Kelas + Mata Pelajaran.
*/

create unique index if not exists
  teacher_assignments_unique_active_subject_idx
on public.teacher_assignments (
  academic_year_id,
  teacher_id,
  class_id,
  subject_id
)
where assignment_type = 'guru_mapel'
  and is_active = true;


/* =========================================================
   8. ROW LEVEL SECURITY
   ========================================================= */

alter table public.teacher_assignments enable row level security;


/* =========================================================
   9. SELECT POLICY
   ========================================================= */

drop policy if exists
  teacher_assignments_select_with_permission
on public.teacher_assignments;

create policy teacher_assignments_select_with_permission
on public.teacher_assignments
for select
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'view')
  or public.has_permission('akademik', 'view')
  or public.has_permission('gtk', 'view')
);


/* =========================================================
   10. INSERT POLICY
   ========================================================= */

drop policy if exists
  teacher_assignments_insert_with_permission
on public.teacher_assignments;

create policy teacher_assignments_insert_with_permission
on public.teacher_assignments
for insert
to authenticated
with check (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'create')
  or public.has_permission('akademik', 'create')
  or public.has_permission('gtk', 'create')
);


/* =========================================================
   11. UPDATE POLICY
   ========================================================= */

drop policy if exists
  teacher_assignments_update_with_permission
on public.teacher_assignments;

create policy teacher_assignments_update_with_permission
on public.teacher_assignments
for update
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'update')
  or public.has_permission('akademik', 'update')
  or public.has_permission('gtk', 'update')
)
with check (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'update')
  or public.has_permission('akademik', 'update')
  or public.has_permission('gtk', 'update')
);


/* =========================================================
   12. DELETE POLICY
   ========================================================= */

drop policy if exists
  teacher_assignments_delete_with_permission
on public.teacher_assignments;

create policy teacher_assignments_delete_with_permission
on public.teacher_assignments
for delete
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'delete')
  or public.has_permission('akademik', 'delete')
  or public.has_permission('gtk', 'delete')
);


/* =========================================================
   13. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.teacher_assignments
to authenticated;