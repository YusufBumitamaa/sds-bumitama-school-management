/*
  Migration 022
  Lesson Schedules / Jadwal Pelajaran

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan jadwal pelajaran.
  - Menghubungkan tahun ajaran, kelas, guru,
    mata pelajaran, penugasan guru, dan ruangan.
  - Menjadi dasar validasi konflik jadwal.
*/


/* =========================================================
   1. ENUM DAY OF WEEK
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'school_day'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.school_day as enum (
      'senin',
      'selasa',
      'rabu',
      'kamis',
      'jumat',
      'sabtu'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE: lesson_schedules
   ========================================================= */

create table if not exists public.lesson_schedules (
  id uuid primary key default gen_random_uuid(),

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

  teacher_assignment_id uuid
    references public.teacher_assignments(id)
    on delete restrict,

  room_id uuid
    references public.rooms(id)
    on delete restrict,

  day_of_week public.school_day not null,

  start_time time not null,

  end_time time not null,

  lesson_period smallint,

  is_active boolean not null default true,

  notes text,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint lesson_schedules_time_check
    check (
      end_time > start_time
    ),

  constraint lesson_schedules_period_check
    check (
      lesson_period is null
      or lesson_period > 0
    )
);


/* =========================================================
   3. COMMENTS
   ========================================================= */

comment on table public.lesson_schedules is
  'Jadwal pelajaran sekolah berdasarkan tahun ajaran, kelas, guru, mata pelajaran, hari, waktu, dan ruangan.';

comment on column public.lesson_schedules.academic_year_id is
  'Tahun ajaran jadwal.';

comment on column public.lesson_schedules.class_id is
  'Rombongan belajar yang mengikuti pelajaran.';

comment on column public.lesson_schedules.subject_id is
  'Mata pelajaran pada jadwal.';

comment on column public.lesson_schedules.teacher_id is
  'Guru yang mengajar pada jadwal.';

comment on column public.lesson_schedules.teacher_assignment_id is
  'Penugasan guru yang menjadi sumber penugasan jadwal.';

comment on column public.lesson_schedules.room_id is
  'Ruangan tempat pelajaran berlangsung.';

comment on column public.lesson_schedules.day_of_week is
  'Hari pelaksanaan pelajaran.';

comment on column public.lesson_schedules.start_time is
  'Waktu mulai pelajaran.';

comment on column public.lesson_schedules.end_time is
  'Waktu selesai pelajaran.';

comment on column public.lesson_schedules.lesson_period is
  'Nomor jam pelajaran jika sekolah menggunakan pembagian periode.';


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  lesson_schedules_academic_year_idx
on public.lesson_schedules(academic_year_id);

create index if not exists
  lesson_schedules_class_idx
on public.lesson_schedules(class_id);

create index if not exists
  lesson_schedules_subject_idx
on public.lesson_schedules(subject_id);

create index if not exists
  lesson_schedules_teacher_idx
on public.lesson_schedules(teacher_id);

create index if not exists
  lesson_schedules_assignment_idx
on public.lesson_schedules(teacher_assignment_id);

create index if not exists
  lesson_schedules_room_idx
on public.lesson_schedules(room_id);

create index if not exists
  lesson_schedules_day_idx
on public.lesson_schedules(day_of_week);

create index if not exists
  lesson_schedules_active_idx
on public.lesson_schedules(is_active);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  lesson_schedules_set_updated_at
on public.lesson_schedules;

create trigger lesson_schedules_set_updated_at
before update on public.lesson_schedules
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.lesson_schedules enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  lesson_schedules_select_with_permission
on public.lesson_schedules;

create policy lesson_schedules_select_with_permission
on public.lesson_schedules
for select
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'view')
  or public.has_permission('akademik', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  lesson_schedules_insert_with_permission
on public.lesson_schedules;

create policy lesson_schedules_insert_with_permission
on public.lesson_schedules
for insert
to authenticated
with check (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'create')
  or public.has_permission('akademik', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  lesson_schedules_update_with_permission
on public.lesson_schedules;

create policy lesson_schedules_update_with_permission
on public.lesson_schedules
for update
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'update')
  or public.has_permission('akademik', 'update')
)
with check (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'update')
  or public.has_permission('akademik', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  lesson_schedules_delete_with_permission
on public.lesson_schedules;

create policy lesson_schedules_delete_with_permission
on public.lesson_schedules
for delete
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('kurikulum', 'delete')
  or public.has_permission('akademik', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.lesson_schedules
to authenticated;