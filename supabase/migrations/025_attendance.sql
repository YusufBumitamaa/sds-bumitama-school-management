/*
  Migration 025
  Student Attendance

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Aturan:
  - Status: hadir, sakit, izin, alpa.
  - Satu siswa hanya memiliki satu absensi
    pada tanggal yang sama dalam tahun ajaran yang sama.
  - Absensi terhubung dengan:
      students
      academic_years
      classes
      student_enrollments
  - Histori absensi dipertahankan.
*/


/* =========================================================
   1. ENUM STATUS ABSENSI
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'attendance_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.attendance_status as enum (
      'hadir',
      'sakit',
      'izin',
      'alpa'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE ATTENDANCE
   ========================================================= */

create table if not exists public.attendance (
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

  attendance_date date not null,

  status public.attendance_status not null,

  notes text,

  recorded_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now()
);


/* =========================================================
   3. UNIQUE ABSENSI SISWA
   ========================================================= */

create unique index if not exists
  uq_attendance_student_year_date
on public.attendance(
  student_id,
  academic_year_id,
  attendance_date
);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_attendance_student
on public.attendance(student_id);

create index if not exists
  idx_attendance_academic_year
on public.attendance(academic_year_id);

create index if not exists
  idx_attendance_class
on public.attendance(class_id);

create index if not exists
  idx_attendance_date
on public.attendance(attendance_date);

create index if not exists
  idx_attendance_status
on public.attendance(status);

create index if not exists
  idx_attendance_recorded_by
on public.attendance(recorded_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  attendance_set_updated_at
on public.attendance;

create trigger attendance_set_updated_at
before update
on public.attendance
for each row
execute function public.set_updated_at();


/* =========================================================
   6. VALIDASI KESESUAIAN ENROLLMENT
   =========================================================

   Memastikan siswa memang terdaftar pada:
   - tahun ajaran yang dipilih
   - kelas yang dipilih
*/

create or replace function public.validate_attendance_enrollment()
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
        message = 'Data absensi tidak valid: siswa tidak terdaftar pada kelas dan tahun ajaran yang dipilih.',
        detail = 'Siswa harus memiliki student_enrollment yang sesuai sebelum absensi dapat dicatat.';

  end if;

  return new;
end;
$$;


/* =========================================================
   7. TRIGGER VALIDASI ENROLLMENT
   ========================================================= */

drop trigger if exists
  attendance_validate_enrollment
on public.attendance;

create trigger attendance_validate_enrollment
before insert or update
on public.attendance
for each row
execute function public.validate_attendance_enrollment();


/* =========================================================
   8. ROW LEVEL SECURITY
   ========================================================= */

alter table public.attendance enable row level security;


/* =========================================================
   9. SELECT POLICY
   ========================================================= */

drop policy if exists
  attendance_select
on public.attendance;

create policy attendance_select
on public.attendance
for select
to authenticated
using (
  public.has_permission('akademik', 'view')
);


/* =========================================================
   10. INSERT POLICY
   ========================================================= */

drop policy if exists
  attendance_insert
on public.attendance;

create policy attendance_insert
on public.attendance
for insert
to authenticated
with check (
  public.has_permission('akademik', 'create')
);


/* =========================================================
   11. UPDATE POLICY
   ========================================================= */

drop policy if exists
  attendance_update
on public.attendance;

create policy attendance_update
on public.attendance
for update
to authenticated
using (
  public.has_permission('akademik', 'update')
)
with check (
  public.has_permission('akademik', 'update')
);


/* =========================================================
   12. DELETE POLICY
   ========================================================= */

drop policy if exists
  attendance_delete
on public.attendance;

create policy attendance_delete
on public.attendance
for delete
to authenticated
using (
  public.has_permission('akademik', 'delete')
);


/* =========================================================
   13. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.attendance
to authenticated;


/* =========================================================
   14. FUNCTION GRANT
   ========================================================= */

grant execute
on function public.validate_attendance_enrollment()
to authenticated;


/* =========================================================
   15. COMMENTS
   ========================================================= */

comment on table public.attendance is
  'Data kehadiran siswa berdasarkan tahun ajaran, rombel, dan tanggal.';

comment on column public.attendance.student_id is
  'Siswa yang dicatat kehadirannya.';

comment on column public.attendance.academic_year_id is
  'Tahun ajaran pencatatan absensi.';

comment on column public.attendance.class_id is
  'Rombel siswa pada saat absensi dicatat.';

comment on column public.attendance.attendance_date is
  'Tanggal kehadiran siswa.';

comment on column public.attendance.status is
  'Status kehadiran: hadir, sakit, izin, atau alpa.';

comment on column public.attendance.recorded_by is
  'User yang mencatat atau memperbarui absensi.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */