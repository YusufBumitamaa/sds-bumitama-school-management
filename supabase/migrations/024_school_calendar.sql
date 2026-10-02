/*
  Migration 024
  School Calendar

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan kalender pendidikan sekolah.
  - Terhubung dengan tahun ajaran.
  - Mendukung kegiatan satu hari maupun beberapa hari.
  - Menyimpan kategori dan status kegiatan.
  - Mempertahankan histori kalender setiap tahun ajaran.
*/


/* =========================================================
   1. ENUM KATEGORI KALENDER
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'school_calendar_category'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.school_calendar_category as enum (
      'hari_efektif',
      'libur_sekolah',
      'libur_nasional',
      'ujian',
      'asesmen',
      'kegiatan_sekolah',
      'rapat',
      'pembagian_rapor',
      'semester',
      'lainnya'
    );

  end if;
end
$$;


/* =========================================================
   2. ENUM STATUS KALENDER
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'school_calendar_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.school_calendar_status as enum (
      'rencana',
      'berlangsung',
      'selesai',
      'dibatalkan'
    );

  end if;
end
$$;


/* =========================================================
   3. TABLE SCHOOL CALENDAR
   ========================================================= */

create table if not exists public.school_calendar (
  id uuid primary key default gen_random_uuid(),

  academic_year_id uuid not null
    references public.academic_years(id)
    on delete restrict,

  title text not null,

  category public.school_calendar_category not null,

  description text,

  start_date date not null,

  end_date date not null,

  start_time time,

  end_time time,

  location text,

  organizer text,

  person_in_charge text,

  status public.school_calendar_status not null
    default 'rencana',

  is_school_day boolean not null
    default true,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint school_calendar_date_range_check
    check (end_date >= start_date),

  constraint school_calendar_time_range_check
    check (
      (
        start_time is null
        and end_time is null
      )
      or
      (
        start_time is not null
        and end_time is not null
        and end_time > start_time
      )
    )
);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_school_calendar_academic_year
on public.school_calendar(academic_year_id);

create index if not exists
  idx_school_calendar_start_date
on public.school_calendar(start_date);

create index if not exists
  idx_school_calendar_end_date
on public.school_calendar(end_date);

create index if not exists
  idx_school_calendar_category
on public.school_calendar(category);

create index if not exists
  idx_school_calendar_status
on public.school_calendar(status);

create index if not exists
  idx_school_calendar_school_day
on public.school_calendar(is_school_day);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  school_calendar_set_updated_at
on public.school_calendar;

create trigger school_calendar_set_updated_at
before update
on public.school_calendar
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.school_calendar enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  school_calendar_select
on public.school_calendar;

create policy school_calendar_select
on public.school_calendar
for select
to authenticated
using (
  public.has_permission('kurikulum', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  school_calendar_insert
on public.school_calendar;

create policy school_calendar_insert
on public.school_calendar
for insert
to authenticated
with check (
  public.has_permission('kurikulum', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  school_calendar_update
on public.school_calendar;

create policy school_calendar_update
on public.school_calendar
for update
to authenticated
using (
  public.has_permission('kurikulum', 'update')
)
with check (
  public.has_permission('kurikulum', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  school_calendar_delete
on public.school_calendar;

create policy school_calendar_delete
on public.school_calendar
for delete
to authenticated
using (
  public.has_permission('kurikulum', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.school_calendar
to authenticated;


/* =========================================================
   12. COMMENTS
   ========================================================= */

comment on table public.school_calendar is
  'Kalender pendidikan dan kegiatan sekolah yang terhubung dengan tahun ajaran.';

comment on column public.school_calendar.academic_year_id is
  'Tahun ajaran yang menjadi konteks kalender.';

comment on column public.school_calendar.category is
  'Kategori kegiatan kalender sekolah.';

comment on column public.school_calendar.is_school_day is
  'Menentukan apakah tanggal tersebut merupakan hari sekolah/efektif.';

comment on column public.school_calendar.created_by is
  'User yang membuat data kalender.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */