/*
  Migration 021
  Rooms / Ruangan

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan master data ruangan sekolah.
  - Menjadi referensi untuk jadwal pelajaran.
  - Menjadi dasar modul Sarpras.
*/


/* =========================================================
   1. TABLE: rooms
   ========================================================= */

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),

  code text not null,

  name text not null,

  room_type text,

  building text,

  floor smallint,

  capacity integer,

  description text,

  is_active boolean not null default true,

  notes text,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint rooms_code_unique
    unique (code),

  constraint rooms_name_unique
    unique (name),

  constraint rooms_floor_check
    check (
      floor is null
      or floor >= 1
    ),

  constraint rooms_capacity_check
    check (
      capacity is null
      or capacity > 0
    )
);


/* =========================================================
   2. COMMENTS
   ========================================================= */

comment on table public.rooms is
  'Master data ruangan sekolah.';

comment on column public.rooms.code is
  'Kode unik ruangan.';

comment on column public.rooms.name is
  'Nama ruangan.';

comment on column public.rooms.room_type is
  'Jenis ruangan, misalnya kelas, laboratorium, perpustakaan, kantor, atau lainnya.';

comment on column public.rooms.building is
  'Nama gedung tempat ruangan berada.';

comment on column public.rooms.floor is
  'Lantai tempat ruangan berada.';

comment on column public.rooms.capacity is
  'Kapasitas maksimal ruangan.';

comment on column public.rooms.is_active is
  'Menentukan apakah ruangan masih aktif digunakan.';


/* =========================================================
   3. INDEXES
   ========================================================= */

create index if not exists
  rooms_name_idx
on public.rooms(name);

create index if not exists
  rooms_type_idx
on public.rooms(room_type);

create index if not exists
  rooms_building_idx
on public.rooms(building);

create index if not exists
  rooms_active_idx
on public.rooms(is_active);


/* =========================================================
   4. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  rooms_set_updated_at
on public.rooms;

create trigger rooms_set_updated_at
before update on public.rooms
for each row
execute function public.set_updated_at();


/* =========================================================
   5. ROW LEVEL SECURITY
   ========================================================= */

alter table public.rooms enable row level security;


/* =========================================================
   6. SELECT POLICY
   ========================================================= */

drop policy if exists
  rooms_select_with_permission
on public.rooms;

create policy rooms_select_with_permission
on public.rooms
for select
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('sarpras', 'view')
  or public.has_permission('akademik', 'view')
);


/* =========================================================
   7. INSERT POLICY
   ========================================================= */

drop policy if exists
  rooms_insert_with_permission
on public.rooms;

create policy rooms_insert_with_permission
on public.rooms
for insert
to authenticated
with check (
  public.is_super_admin()
  or public.has_permission('sarpras', 'create')
);


/* =========================================================
   8. UPDATE POLICY
   ========================================================= */

drop policy if exists
  rooms_update_with_permission
on public.rooms;

create policy rooms_update_with_permission
on public.rooms
for update
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('sarpras', 'update')
)
with check (
  public.is_super_admin()
  or public.has_permission('sarpras', 'update')
);


/* =========================================================
   9. DELETE POLICY
   ========================================================= */

drop policy if exists
  rooms_delete_with_permission
on public.rooms;

create policy rooms_delete_with_permission
on public.rooms
for delete
to authenticated
using (
  public.is_super_admin()
  or public.has_permission('sarpras', 'delete')
);


/* =========================================================
   10. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.rooms
to authenticated;