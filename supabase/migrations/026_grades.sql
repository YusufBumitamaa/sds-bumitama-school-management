/*
  Migration 026
  Student Grades / Penilaian Siswa

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan nilai siswa.
  - Menghubungkan nilai dengan:
      siswa
      tahun ajaran
      rombel
      mata pelajaran
      guru
  - Mendukung semester dan berbagai jenis penilaian.
  - Menjadi dasar untuk modul Rapor.
*/


/* =========================================================
   1. ENUM SEMESTER
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'academic_semester'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.academic_semester as enum (
      'ganjil',
      'genap'
    );

  end if;
end
$$;


/* =========================================================
   2. ENUM JENIS PENILAIAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'grade_assessment_type'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.grade_assessment_type as enum (
      'tugas',
      'formatif',
      'sumatif',
      'pts',
      'pas',
      'praktik',
      'proyek',
      'portofolio',
      'lainnya'
    );

  end if;
end
$$;


/* =========================================================
   3. TABLE GRADES
   ========================================================= */

create table if not exists public.grades (
  id uuid primary key default gen_random_uuid(),

  student_id uuid not null
    references public.students(id)
    on delete restrict,

  academic_year_id uuid not null
    references public.academic_years(id)
    on delete restrict,

  class_id uuid not null
    references public.classes(id)
    on delete restrict,

  subject_id uuid not null
    references public.subjects(id)
    on delete restrict,

  teacher_id uuid not null
    references public.teachers_staff(id)
    on delete restrict,

  semester public.academic_semester not null,

  assessment_type public.grade_assessment_type not null,

  assessment_name text not null,

  assessment_date date,

  score numeric(5,2) not null,

  notes text,

  recorded_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint grades_score_range_check
    check (
      score >= 0
      and score <= 100
    ),

  constraint grades_assessment_name_check
    check (
      length(trim(assessment_name)) > 0
    )
);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_grades_student
on public.grades(student_id);

create index if not exists
  idx_grades_academic_year
on public.grades(academic_year_id);

create index if not exists
  idx_grades_class
on public.grades(class_id);

create index if not exists
  idx_grades_subject
on public.grades(subject_id);

create index if not exists
  idx_grades_teacher
on public.grades(teacher_id);

create index if not exists
  idx_grades_semester
on public.grades(semester);

create index if not exists
  idx_grades_assessment_type
on public.grades(assessment_type);

create index if not exists
  idx_grades_assessment_date
on public.grades(assessment_date);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  grades_set_updated_at
on public.grades;

create trigger grades_set_updated_at
before update
on public.grades
for each row
execute function public.set_updated_at();


/* =========================================================
   6. VALIDASI ENROLLMENT
   =========================================================

   Memastikan siswa memang terdaftar pada:
   - tahun ajaran
   - rombel
   yang digunakan dalam data nilai.
*/

create or replace function public.validate_grade_enrollment()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin

  if not exists (
    select 1
    from public.student_enrollments se
    where se.student_id = new.student_id
      and se.academic_year_id = new.academic_year_id
      and se.class_id = new.class_id
  ) then

    raise exception
      using
        errcode = '23514',
        message = 'Data nilai tidak valid: siswa tidak terdaftar pada kelas dan tahun ajaran yang dipilih.',
        detail = 'Siswa harus memiliki student_enrollment yang sesuai sebelum nilai dapat dicatat.';

  end if;

  return new;
end;
$$;


/* =========================================================
   7. VALIDASI GURU
   =========================================================

   Memastikan guru yang mencatat nilai merupakan guru aktif
   yang memiliki assignment mengajar mata pelajaran tersebut
   pada kelas dan tahun ajaran yang dipilih.

   Jika teacher_assignment_id belum tersedia pada grades,
   validasi dilakukan berdasarkan teacher_id + class_id +
   subject_id + academic_year_id.
*/

create or replace function public.validate_grade_teacher_assignment()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin

  if not exists (
    select 1
    from public.teacher_assignments ta
    join public.teachers_staff ts
      on ts.id = ta.teacher_id
    where ta.teacher_id = new.teacher_id
      and ta.academic_year_id = new.academic_year_id
      and ta.class_id = new.class_id
      and ta.subject_id = new.subject_id
      and ta.assignment_type = 'guru_mapel'
      and ta.is_active = true
      and ts.is_active = true
  ) then

    raise exception
      using
        errcode = '23514',
        message = 'Data nilai tidak valid: guru tidak memiliki penugasan mata pelajaran yang sesuai.',
        detail = 'Guru harus memiliki teacher_assignment aktif untuk mata pelajaran, kelas, dan tahun ajaran yang dipilih.';

  end if;

  return new;
end;
$$;


/* =========================================================
   8. TRIGGER VALIDASI ENROLLMENT
   ========================================================= */

drop trigger if exists
  grades_validate_enrollment
on public.grades;

create trigger grades_validate_enrollment
before insert or update
on public.grades
for each row
execute function public.validate_grade_enrollment();


/* =========================================================
   9. TRIGGER VALIDASI GURU
   ========================================================= */

drop trigger if exists
  grades_validate_teacher_assignment
on public.grades;

create trigger grades_validate_teacher_assignment
before insert or update
on public.grades
for each row
execute function public.validate_grade_teacher_assignment();


/* =========================================================
   10. ROW LEVEL SECURITY
   ========================================================= */

alter table public.grades enable row level security;


/* =========================================================
   11. SELECT POLICY
   ========================================================= */

drop policy if exists
  grades_select
on public.grades;

create policy grades_select
on public.grades
for select
to authenticated
using (
  public.has_permission('akademik', 'view')
);


/* =========================================================
   12. INSERT POLICY
   ========================================================= */

drop policy if exists
  grades_insert
on public.grades;

create policy grades_insert
on public.grades
for insert
to authenticated
with check (
  public.has_permission('akademik', 'create')
);


/* =========================================================
   13. UPDATE POLICY
   ========================================================= */

drop policy if exists
  grades_update
on public.grades;

create policy grades_update
on public.grades
for update
to authenticated
using (
  public.has_permission('akademik', 'update')
)
with check (
  public.has_permission('akademik', 'update')
);


/* =========================================================
   14. DELETE POLICY
   ========================================================= */

drop policy if exists
  grades_delete
on public.grades;

create policy grades_delete
on public.grades
for delete
to authenticated
using (
  public.has_permission('akademik', 'delete')
);


/* =========================================================
   15. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.grades
to authenticated;


/* =========================================================
   16. FUNCTION GRANTS
   ========================================================= */

grant execute
on function public.validate_grade_enrollment()
to authenticated;

grant execute
on function public.validate_grade_teacher_assignment()
to authenticated;


/* =========================================================
   17. COMMENTS
   ========================================================= */

comment on table public.grades is
  'Data penilaian siswa berdasarkan tahun ajaran, rombel, mata pelajaran, guru, semester, dan jenis penilaian.';

comment on column public.grades.student_id is
  'Siswa yang memperoleh nilai.';

comment on column public.grades.academic_year_id is
  'Tahun ajaran penilaian.';

comment on column public.grades.class_id is
  'Rombel siswa pada saat penilaian.';

comment on column public.grades.subject_id is
  'Mata pelajaran yang dinilai.';

comment on column public.grades.teacher_id is
  'Guru yang memberikan atau mencatat penilaian.';

comment on column public.grades.semester is
  'Semester penilaian: ganjil atau genap.';

comment on column public.grades.assessment_type is
  'Jenis penilaian.';

comment on column public.grades.assessment_name is
  'Nama atau identitas penilaian.';

comment on column public.grades.score is
  'Nilai numerik dengan rentang 0 sampai 100.';

comment on column public.grades.recorded_by is
  'User yang mencatat data nilai.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */