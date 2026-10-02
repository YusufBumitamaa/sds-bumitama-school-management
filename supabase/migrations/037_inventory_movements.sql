/*
  Migration 037
  Inventory Movements / Pergerakan Inventaris

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan seluruh riwayat pergerakan inventaris.
  - Mencatat perpindahan barang antar ruangan.
  - Mencatat peminjaman dan pengembalian.
  - Menyimpan penyesuaian jumlah inventaris.
  - Menjaga histori perubahan inventaris.
*/


/* =========================================================
   1. ENUM JENIS PERGERAKAN INVENTARIS
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'inventory_movement_type'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.inventory_movement_type as enum (
      'masuk',
      'pindah',
      'pinjam',
      'kembali',
      'penyesuaian',
      'keluar'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE INVENTORY MOVEMENTS
   ========================================================= */

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),

  inventory_id uuid not null
    references public.inventory(id)
    on delete restrict,

  movement_type public.inventory_movement_type not null,

  movement_date date not null
    default current_date,

  quantity numeric(12,2) not null,

  from_room_id uuid
    references public.rooms(id)
    on delete restrict,

  to_room_id uuid
    references public.rooms(id)
    on delete restrict,

  recipient_name text,

  recipient_role text,

  reference_number text,

  reference_date date,

  reason text,

  notes text,

  recorded_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  constraint inventory_movement_quantity_check
    check (
      quantity > 0
    ),

  constraint inventory_movement_room_check
    check (
      from_room_id is null
      or to_room_id is null
      or from_room_id <> to_room_id
    ),

  constraint inventory_movement_recipient_check
    check (
      movement_type not in ('pinjam', 'kembali')
      or recipient_name is not null
      or recipient_role is not null
    )
);


/* =========================================================
   3. INDEXES
   ========================================================= */

create index if not exists
  idx_inventory_movements_inventory
on public.inventory_movements(inventory_id);

create index if not exists
  idx_inventory_movements_type
on public.inventory_movements(movement_type);

create index if not exists
  idx_inventory_movements_date
on public.inventory_movements(movement_date);

create index if not exists
  idx_inventory_movements_from_room
on public.inventory_movements(from_room_id);

create index if not exists
  idx_inventory_movements_to_room
on public.inventory_movements(to_room_id);

create index if not exists
  idx_inventory_movements_recorded_by
on public.inventory_movements(recorded_by);


/* =========================================================
   4. ROW LEVEL SECURITY
   ========================================================= */

alter table public.inventory_movements
enable row level security;


/* =========================================================
   5. SELECT POLICY
   ========================================================= */

drop policy if exists
  inventory_movements_select
on public.inventory_movements;

create policy inventory_movements_select
on public.inventory_movements
for select
to authenticated
using (
  public.has_permission('sarpras', 'view')
);


/* =========================================================
   6. INSERT POLICY
   ========================================================= */

drop policy if exists
  inventory_movements_insert
on public.inventory_movements;

create policy inventory_movements_insert
on public.inventory_movements
for insert
to authenticated
with check (
  public.has_permission('sarpras', 'create')
);


/* =========================================================
   7. UPDATE POLICY
   ========================================================= */

drop policy if exists
  inventory_movements_update
on public.inventory_movements;

create policy inventory_movements_update
on public.inventory_movements
for update
to authenticated
using (
  public.has_permission('sarpras', 'update')
)
with check (
  public.has_permission('sarpras', 'update')
);


/* =========================================================
   8. DELETE POLICY
   ========================================================= */

drop policy if exists
  inventory_movements_delete
on public.inventory_movements;

create policy inventory_movements_delete
on public.inventory_movements
for delete
to authenticated
using (
  public.has_permission('sarpras', 'delete')
);


/* =========================================================
   9. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.inventory_movements
to authenticated;


/* =========================================================
   10. COMMENTS
   ========================================================= */

comment on table public.inventory_movements is
  'Riwayat pergerakan dan perubahan inventaris sekolah.';

comment on column public.inventory_movements.inventory_id is
  'Inventaris yang mengalami pergerakan.';

comment on column public.inventory_movements.movement_type is
  'Jenis pergerakan inventaris.';

comment on column public.inventory_movements.movement_date is
  'Tanggal terjadinya pergerakan inventaris.';

comment on column public.inventory_movements.quantity is
  'Jumlah inventaris yang mengalami pergerakan.';

comment on column public.inventory_movements.from_room_id is
  'Ruangan/lokasi asal inventaris.';

comment on column public.inventory_movements.to_room_id is
  'Ruangan/lokasi tujuan inventaris.';

comment on column public.inventory_movements.recipient_name is
  'Nama penerima ketika inventaris dipinjamkan.';

comment on column public.inventory_movements.recipient_role is
  'Jabatan/peran penerima inventaris.';

comment on column public.inventory_movements.reference_number is
  'Nomor dokumen pendukung pergerakan inventaris.';

comment on column public.inventory_movements.reference_date is
  'Tanggal dokumen pendukung.';

comment on column public.inventory_movements.recorded_by is
  'User yang mencatat pergerakan inventaris.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */