/*
  Migration 036
  Inventory / Inventaris Sarpras

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan master inventaris sarana dan prasarana sekolah.
  - Menghubungkan aset dengan ruangan.
  - Menyimpan kondisi dan status aset.
  - Menjadi dasar untuk pergerakan inventaris,
    pemeliharaan, pengadaan, dan penghapusan aset.
*/


/* =========================================================
   1. ENUM KONDISI INVENTARIS
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'inventory_condition'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.inventory_condition as enum (
      'baik',
      'rusak_ringan',
      'rusak_berat'
    );

  end if;
end
$$;


/* =========================================================
   2. ENUM STATUS INVENTARIS
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'inventory_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.inventory_status as enum (
      'aktif',
      'dipinjamkan',
      'diperbaiki',
      'dihapuskan'
    );

  end if;
end
$$;


/* =========================================================
   3. TABLE INVENTORY
   ========================================================= */

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),

  inventory_code text not null,

  item_name text not null,

  category text not null,

  brand text,

  model text,

  serial_number text,

  quantity numeric(12,2) not null
    default 1,

  unit text not null
    default 'unit',

  acquisition_year integer,

  acquisition_date date,

  funding_source text,

  acquisition_value numeric(15,2),

  room_id uuid
    references public.rooms(id)
    on delete restrict,

  condition public.inventory_condition not null
    default 'baik',

  status public.inventory_status not null
    default 'aktif',

  description text,

  notes text,

  document_url text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint inventory_code_check
    check (
      length(trim(inventory_code)) > 0
    ),

  constraint inventory_item_name_check
    check (
      length(trim(item_name)) > 0
    ),

  constraint inventory_category_check
    check (
      length(trim(category)) > 0
    ),

  constraint inventory_quantity_check
    check (
      quantity > 0
    ),

  constraint inventory_acquisition_year_check
    check (
      acquisition_year is null
      or (
        acquisition_year >= 1900
        and acquisition_year <= 2100
      )
    ),

  constraint inventory_acquisition_value_check
    check (
      acquisition_value is null
      or acquisition_value >= 0
    )
);


/* =========================================================
   4. UNIQUE INVENTORY CODE
   ========================================================= */

create unique index if not exists
  uq_inventory_code
on public.inventory(inventory_code);


/* =========================================================
   5. UNIQUE SERIAL NUMBER
   ========================================================= */

create unique index if not exists
  uq_inventory_serial_number
on public.inventory(serial_number)
where serial_number is not null;


/* =========================================================
   6. INDEXES
   ========================================================= */

create index if not exists
  idx_inventory_item_name
on public.inventory(item_name);

create index if not exists
  idx_inventory_category
on public.inventory(category);

create index if not exists
  idx_inventory_room
on public.inventory(room_id);

create index if not exists
  idx_inventory_condition
on public.inventory(condition);

create index if not exists
  idx_inventory_status
on public.inventory(status);

create index if not exists
  idx_inventory_acquisition_year
on public.inventory(acquisition_year);

create index if not exists
  idx_inventory_created_by
on public.inventory(created_by);


/* =========================================================
   7. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  inventory_set_updated_at
on public.inventory;

create trigger inventory_set_updated_at
before update
on public.inventory
for each row
execute function public.set_updated_at();


/* =========================================================
   8. ROW LEVEL SECURITY
   ========================================================= */

alter table public.inventory
enable row level security;


/* =========================================================
   9. SELECT POLICY
   ========================================================= */

drop policy if exists
  inventory_select
on public.inventory;

create policy inventory_select
on public.inventory
for select
to authenticated
using (
  public.has_permission('sarpras', 'view')
);


/* =========================================================
   10. INSERT POLICY
   ========================================================= */

drop policy if exists
  inventory_insert
on public.inventory;

create policy inventory_insert
on public.inventory
for insert
to authenticated
with check (
  public.has_permission('sarpras', 'create')
);


/* =========================================================
   11. UPDATE POLICY
   ========================================================= */

drop policy if exists
  inventory_update
on public.inventory;

create policy inventory_update
on public.inventory
for update
to authenticated
using (
  public.has_permission('sarpras', 'update')
)
with check (
  public.has_permission('sarpras', 'update')
);


/* =========================================================
   12. DELETE POLICY
   ========================================================= */

drop policy if exists
  inventory_delete
on public.inventory;

create policy inventory_delete
on public.inventory
for delete
to authenticated
using (
  public.has_permission('sarpras', 'delete')
);


/* =========================================================
   13. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.inventory
to authenticated;


/* =========================================================
   14. COMMENTS
   ========================================================= */

comment on table public.inventory is
  'Master data inventaris sarana dan prasarana sekolah.';

comment on column public.inventory.inventory_code is
  'Kode inventaris unik aset/barang.';

comment on column public.inventory.item_name is
  'Nama barang atau aset.';

comment on column public.inventory.category is
  'Kategori inventaris.';

comment on column public.inventory.brand is
  'Merek barang jika tersedia.';

comment on column public.inventory.model is
  'Model atau tipe barang jika tersedia.';

comment on column public.inventory.serial_number is
  'Nomor seri barang jika tersedia.';

comment on column public.inventory.quantity is
  'Jumlah barang dalam satuan yang ditentukan.';

comment on column public.inventory.unit is
  'Satuan barang, misalnya unit, buah, set, atau lainnya.';

comment on column public.inventory.acquisition_year is
  'Tahun perolehan barang.';

comment on column public.inventory.acquisition_date is
  'Tanggal perolehan barang jika tersedia.';

comment on column public.inventory.funding_source is
  'Sumber dana perolehan barang.';

comment on column public.inventory.acquisition_value is
  'Nilai perolehan barang.';

comment on column public.inventory.room_id is
  'Ruangan/lokasi tempat barang ditempatkan.';

comment on column public.inventory.condition is
  'Kondisi fisik inventaris.';

comment on column public.inventory.status is
  'Status penggunaan atau pengelolaan inventaris.';

comment on column public.inventory.document_url is
  'Lokasi dokumen pendukung inventaris pada storage/digital archive.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */