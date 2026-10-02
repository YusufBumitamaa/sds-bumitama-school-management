/*
  Migration 033
  Staff Attendance / Kehadiran GTK

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Mencatat kehadiran Guru dan Tenaga Kependidikan.
  - Satu GTK hanya memiliki satu catatan kehadiran per tanggal.
  - Mendukung jam masuk dan jam pulang.
  - Menyimpan petugas yang mencatat kehadiran.
*/


/* =========================================================
   1. ENUM STATUS KEHADIRAN GTK
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'staff_attendance_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.staff_attendance_status as enum (
      'hadir',
      'sakit',
      'izin',
      'alpa'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE STAFF ATTENDANCE
   ========================================================= */

create table if not exists public.staff_attendance (
  id uuid primary key default gen_random_uuid(),

  staff_id uuid not null
    references public.teachers_staff(id)
    on delete restrict,

  attendance_date date not null,

  status public.staff_attendance_status not null,

  check_in_time time,

  check_out_time time,

  notes text,

  recorded_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint staff_attendance_time_check
    check (
      check_out_time is null
      or check_in_time is null
      or check_out_time >= check_in_time
    )
);


/* =========================================================
   3. UNIQUE CONSTRAINT
   ========================================================= */

create unique index if not exists
  uq_staff_attendance_staff_date
on public.staff_attendance(
  staff_id,
  attendance_date
);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_staff_attendance_staff
on public.staff_attendance(staff_id);

create index if not exists
  idx_staff_attendance_date
on public.staff_attendance(attendance_date);

create index if not exists
  idx_staff_attendance_status
on public.staff_attendance(status);

create index if not exists
  idx_staff_attendance_recorded_by
on public.staff_attendance(recorded_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  staff_attendance_set_updated_at
on public.staff_attendance;

create trigger staff_attendance_set_updated_at
before update
on public.staff_attendance
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.staff_attendance
enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  staff_attendance_select
on public.staff_attendance;

create policy staff_attendance_select
on public.staff_attendance
for select
to authenticated
using (
  public.has_permission('gtk', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  staff_attendance_insert
on public.staff_attendance;

create policy staff_attendance_insert
on public.staff_attendance
for insert
to authenticated
with check (
  public.has_permission('gtk', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  staff_attendance_update
on public.staff_attendance;

create policy staff_attendance_update
on public.staff_attendance
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
  staff_attendance_delete
on public.staff_attendance;

create policy staff_attendance_delete
on public.staff_attendance
for delete
to authenticated
using (
  public.has_permission('gtk', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.staff_attendance
to authenticated;


/* =========================================================
   12. COMMENTS
   ========================================================= */

comment on table public.staff_attendance is
  'Data kehadiran harian Guru dan Tenaga Kependidikan.';

comment on column public.staff_attendance.staff_id is
  'GTK yang dicatat kehadirannya.';

comment on column public.staff_attendance.attendance_date is
  'Tanggal kehadiran GTK.';

comment on column public.staff_attendance.status is
  'Status kehadiran: hadir, sakit, izin, atau alpa.';

comment on column public.staff_attendance.check_in_time is
  'Jam masuk GTK.';

comment on column public.staff_attendance.check_out_time is
  'Jam pulang GTK.';

comment on column public.staff_attendance.recorded_by is
  'User yang mencatat kehadiran.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */