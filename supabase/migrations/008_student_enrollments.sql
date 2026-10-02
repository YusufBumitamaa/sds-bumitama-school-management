/*
  Migration 008
  Tahun Ajaran, Rombongan Belajar, dan Student Enrollment

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Urutan dependency:
  academic_years
      ↓
  classes
      ↓
  students
      ↓
  student_enrollments

  Catatan:
  - Tahun Ajaran merupakan master akademik.
  - Rombongan Belajar terkait dengan Tahun Ajaran.
  - Siswa ditempatkan ke Rombongan Belajar melalui
    student_enrollments.
  - Riwayat penempatan siswa dipertahankan.
*/


/* =========================================================
   1. TABEL TAHUN AJARAN
   ========================================================= */

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),

  name text not null unique,

  start_date date not null,

  end_date date not null,

  is_active boolean not null default false,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint academic_years_date_check
    check (
      end_date >= start_date
    )
);

comment on table public.academic_years is
  'Master Tahun Ajaran sekolah.';

comment on column public.academic_years.name is
  'Nama Tahun Ajaran, contoh: 2026/2027.';

comment on column public.academic_years.is_active is
  'Menandai Tahun Ajaran yang sedang aktif.';


create index academic_years_is_active_idx
  on public.academic_years(is_active);

create index academic_years_start_date_idx
  on public.academic_years(start_date);


create trigger academic_years_set_updated_at
before update on public.academic_years
for each row
execute function public.set_updated_at();


alter table public.academic_years
enable row level security;


create policy academic_years_select_with_permission
on public.academic_years
for select
to authenticated
using (
  public.has_permission(
    'kurikulum',
    'view'
  )
  or
  public.has_permission(
    'akademik',
    'view'
  )
);


create policy academic_years_insert_with_permission
on public.academic_years
for insert
to authenticated
with check (
  public.has_permission(
    'kurikulum',
    'create'
  )
);


create policy academic_years_update_with_permission
on public.academic_years
for update
to authenticated
using (
  public.has_permission(
    'kurikulum',
    'update'
  )
)
with check (
  public.has_permission(
    'kurikulum',
    'update'
  )
);


create policy academic_years_delete_with_permission
on public.academic_years
for delete
to authenticated
using (
  public.has_permission(
    'kurikulum',
    'delete'
  )
);


grant select
on table public.academic_years
to authenticated;

grant insert
on table public.academic_years
to authenticated;

grant update
on table public.academic_years
to authenticated;

grant delete
on table public.academic_years
to authenticated;


/* =========================================================
   2. TABEL ROMBONGAN BELAJAR
   ========================================================= */

create table public.classes (
  id uuid primary key default gen_random_uuid(),

  academic_year_id uuid not null
    references public.academic_years(id)
    on delete restrict,

  name text not null,

  grade_level integer not null,

  section text not null,

  capacity integer,

  notes text,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint classes_grade_level_check
    check (
      grade_level between 1 and 12
    ),

  constraint classes_section_check
    check (
      length(trim(section)) > 0
    ),

  constraint classes_capacity_check
    check (
      capacity is null
      or capacity > 0
    ),

  constraint classes_year_name_unique
    unique (
      academic_year_id,
      name
    )
);

comment on table public.classes is
  'Master Rombongan Belajar berdasarkan Tahun Ajaran.';

comment on column public.classes.name is
  'Nama Rombongan Belajar, contoh: Kelas I A.';

comment on column public.classes.grade_level is
  'Tingkat kelas numerik, contoh 1 untuk Kelas I.';

comment on column public.classes.section is
  'Pembagian rombel, contoh A atau B.';


create index classes_academic_year_idx
  on public.classes(academic_year_id);

create index classes_grade_level_idx
  on public.classes(grade_level);

create index classes_name_idx
  on public.classes(name);


create trigger classes_set_updated_at
before update on public.classes
for each row
execute function public.set_updated_at();


alter table public.classes
enable row level security;


create policy classes_select_with_permission
on public.classes
for select
to authenticated
using (
  public.has_permission(
    'akademik',
    'view'
  )
);


create policy classes_insert_with_permission
on public.classes
for insert
to authenticated
with check (
  public.has_permission(
    'akademik',
    'create'
  )
);


create policy classes_update_with_permission
on public.classes
for update
to authenticated
using (
  public.has_permission(
    'akademik',
    'update'
  )
)
with check (
  public.has_permission(
    'akademik',
    'update'
  )
);


create policy classes_delete_with_permission
on public.classes
for delete
to authenticated
using (
  public.has_permission(
    'akademik',
    'delete'
  )
);


grant select
on table public.classes
to authenticated;

grant insert
on table public.classes
to authenticated;

grant update
on table public.classes
to authenticated;

grant delete
on table public.classes
to authenticated;


/* =========================================================
   3. TABEL STUDENT ENROLLMENTS
   ========================================================= */

create table public.student_enrollments (
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

  roll_number integer,

  notes text,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint student_enrollments_student_year_unique
    unique (
      student_id,
      academic_year_id
    ),

  constraint student_enrollments_roll_number_check
    check (
      roll_number is null
      or roll_number > 0
    )
);

comment on table public.student_enrollments is
  'Riwayat penempatan siswa pada Tahun Ajaran dan Rombongan Belajar.';

comment on column public.student_enrollments.student_id is
  'Referensi ke master siswa.';

comment on column public.student_enrollments.academic_year_id is
  'Tahun Ajaran tempat siswa terdaftar.';

comment on column public.student_enrollments.class_id is
  'Rombongan Belajar tempat siswa ditempatkan.';

comment on column public.student_enrollments.roll_number is
  'Nomor urut siswa dalam Rombongan Belajar.';


create index student_enrollments_student_idx
  on public.student_enrollments(student_id);

create index student_enrollments_academic_year_idx
  on public.student_enrollments(academic_year_id);

create index student_enrollments_class_idx
  on public.student_enrollments(class_id);

create index student_enrollments_year_class_idx
  on public.student_enrollments(
    academic_year_id,
    class_id
  );


create trigger student_enrollments_set_updated_at
before update on public.student_enrollments
for each row
execute function public.set_updated_at();


alter table public.student_enrollments
enable row level security;


create policy student_enrollments_select_with_permission
on public.student_enrollments
for select
to authenticated
using (
  public.has_permission(
    'kesiswaan',
    'view'
  )
  or
  public.has_permission(
    'akademik',
    'view'
  )
);


create policy student_enrollments_insert_with_permission
on public.student_enrollments
for insert
to authenticated
with check (
  public.has_permission(
    'kesiswaan',
    'create'
  )
  or
  public.has_permission(
    'akademik',
    'create'
  )
);


create policy student_enrollments_update_with_permission
on public.student_enrollments
for update
to authenticated
using (
  public.has_permission(
    'kesiswaan',
    'update'
  )
  or
  public.has_permission(
    'akademik',
    'update'
  )
)
with check (
  public.has_permission(
    'kesiswaan',
    'update'
  )
  or
  public.has_permission(
    'akademik',
    'update'
  )
);


create policy student_enrollments_delete_with_permission
on public.student_enrollments
for delete
to authenticated
using (
  public.has_permission(
    'kesiswaan',
    'delete'
  )
  or
  public.has_permission(
    'akademik',
    'delete'
  )
);


grant select
on table public.student_enrollments
to authenticated;

grant insert
on table public.student_enrollments
to authenticated;

grant update
on table public.student_enrollments
to authenticated;

grant delete
on table public.student_enrollments
to authenticated;