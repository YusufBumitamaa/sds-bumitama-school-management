/*
  Migration 032
  Staff Additional Assignments / Tugas Tambahan GTK

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan riwayat tugas tambahan Guru/Tendik.
  - Mendukung beberapa tugas tambahan untuk satu GTK.
  - Menyimpan periode tugas dan dokumen pendukung.
*/


/* =========================================================
   1. ENUM STATUS TUGAS TAMBAHAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'staff_additional_assignment_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.staff_additional_assignment_status as enum (
      'aktif',
      'selesai',
      'dibatalkan'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE STAFF ADDITIONAL ASSIGNMENTS
   ========================================================= */

create table if not exists public.staff_additional_assignments (
  id uuid primary key default gen_random_uuid(),

  staff_id uuid not null
    references public.teachers_staff(id)
    on delete restrict,

  assignment_name text not null,

  assignment_type text,

  assignment_number text,

  assignment_date date,

  start_date date,

  end_date date,

  description text,

  status public.staff_additional_assignment_status not null
    default 'aktif',

  document_url text,

  notes text,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint staff_additional_assignment_name_check
    check (
      length(trim(assignment_name)) > 0
    ),

  constraint staff_additional_assignment_date_check
    check (
      end_date is null
      or start_date is null
      or end_date >= start_date
    )
);


/* =========================================================
   3. INDEXES
   ========================================================= */

create index if not exists
  idx_staff_additional_assignments_staff
on public.staff_additional_assignments(staff_id);

create index if not exists
  idx_staff_additional_assignments_type
on public.staff_additional_assignments(assignment_type);

create index if not exists
  idx_staff_additional_assignments_status
on public.staff_additional_assignments(status);

create index if not exists
  idx_staff_additional_assignments_start_date
on public.staff_additional_assignments(start_date);

create index if not exists
  idx_staff_additional_assignments_end_date
on public.staff_additional_assignments(end_date);


/* =========================================================
   4. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  staff_additional_assignments_set_updated_at
on public.staff_additional_assignments;

create trigger staff_additional_assignments_set_updated_at
before update
on public.staff_additional_assignments
for each row
execute function public.set_updated_at();


/* =========================================================
   5. ROW LEVEL SECURITY
   ========================================================= */

alter table public.staff_additional_assignments
enable row level security;


/* =========================================================
   6. SELECT POLICY
   ========================================================= */

drop policy if exists
  staff_additional_assignments_select
on public.staff_additional_assignments;

create policy staff_additional_assignments_select
on public.staff_additional_assignments
for select
to authenticated
using (
  public.has_permission('gtk', 'view')
);


/* =========================================================
   7. INSERT POLICY
   ========================================================= */

drop policy if exists
  staff_additional_assignments_insert
on public.staff_additional_assignments;

create policy staff_additional_assignments_insert
on public.staff_additional_assignments
for insert
to authenticated
with check (
  public.has_permission('gtk', 'create')
);


/* =========================================================
   8. UPDATE POLICY
   ========================================================= */

drop policy if exists
  staff_additional_assignments_update
on public.staff_additional_assignments;

create policy staff_additional_assignments_update
on public.staff_additional_assignments
for update
to authenticated
using (
  public.has_permission('gtk', 'update')
)
with check (
  public.has_permission('gtk', 'update')
);


/* =========================================================
   9. DELETE POLICY
   ========================================================= */

drop policy if exists
  staff_additional_assignments_delete
on public.staff_additional_assignments;

create policy staff_additional_assignments_delete
on public.staff_additional_assignments
for delete
to authenticated
using (
  public.has_permission('gtk', 'delete')
);


/* =========================================================
   10. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.staff_additional_assignments
to authenticated;


/* =========================================================
   11. COMMENTS
   ========================================================= */

comment on table public.staff_additional_assignments is
  'Riwayat tugas tambahan Guru dan Tenaga Kependidikan.';

comment on column public.staff_additional_assignments.staff_id is
  'GTK yang menerima tugas tambahan.';

comment on column public.staff_additional_assignments.assignment_name is
  'Nama tugas tambahan.';

comment on column public.staff_additional_assignments.assignment_type is
  'Kategori atau jenis tugas tambahan.';

comment on column public.staff_additional_assignments.assignment_number is
  'Nomor surat keputusan atau dokumen penugasan jika ada.';

comment on column public.staff_additional_assignments.assignment_date is
  'Tanggal surat atau dokumen penugasan.';

comment on column public.staff_additional_assignments.start_date is
  'Tanggal mulai menjalankan tugas tambahan.';

comment on column public.staff_additional_assignments.end_date is
  'Tanggal berakhirnya tugas tambahan.';

comment on column public.staff_additional_assignments.document_url is
  'Lokasi dokumen penugasan pada storage/digital archive.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */