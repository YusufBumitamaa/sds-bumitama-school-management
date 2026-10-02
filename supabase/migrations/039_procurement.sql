/*
  Migration 039
  Procurement / Pengadaan Sarpras

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Mencatat kebutuhan/pengadaan barang atau jasa.
  - Mendukung alur pengajuan sampai barang diterima.
  - Menyimpan vendor, biaya, persetujuan, dan dokumen.
  - Menjadi dasar integrasi dengan keuangan dan inventaris.
*/


/* =========================================================
   1. ENUM STATUS PENGADAAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'procurement_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.procurement_status as enum (
      'draft',
      'diajukan',
      'disetujui',
      'diproses',
      'dipesan',
      'dibayar',
      'diterima',
      'dibatalkan'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE PROCUREMENT
   ========================================================= */

create table if not exists public.procurement (
  id uuid primary key default gen_random_uuid(),

  procurement_number text not null,

  procurement_date date not null
    default current_date,

  title text not null,

  category text,

  description text,

  quantity numeric(12,2) not null
    default 1,

  unit text not null
    default 'unit',

  estimated_unit_price numeric(15,2),

  estimated_total numeric(15,2),

  vendor_name text,

  vendor_contact text,

  vendor_address text,

  actual_unit_price numeric(15,2),

  actual_total numeric(15,2),

  funding_source text,

  requested_by uuid
    references public.users(id)
    on delete set null,

  approved_by uuid
    references public.users(id)
    on delete set null,

  approved_at timestamptz,

  order_date date,

  payment_date date,

  received_date date,

  status public.procurement_status not null
    default 'draft',

  reference_number text,

  reference_date date,

  document_url text,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint procurement_number_check
    check (
      length(trim(procurement_number)) > 0
    ),

  constraint procurement_title_check
    check (
      length(trim(title)) > 0
    ),

  constraint procurement_quantity_check
    check (
      quantity > 0
    ),

  constraint procurement_estimated_unit_price_check
    check (
      estimated_unit_price is null
      or estimated_unit_price >= 0
    ),

  constraint procurement_estimated_total_check
    check (
      estimated_total is null
      or estimated_total >= 0
    ),

  constraint procurement_actual_unit_price_check
    check (
      actual_unit_price is null
      or actual_unit_price >= 0
    ),

  constraint procurement_actual_total_check
    check (
      actual_total is null
      or actual_total >= 0
    ),

  constraint procurement_approval_check
    check (
      status not in (
        'disetujui',
        'diproses',
        'dipesan',
        'dibayar',
        'diterima'
      )
      or approved_at is not null
    ),

  constraint procurement_date_order_check
    check (
      order_date is null
      or order_date >= procurement_date
    ),

  constraint procurement_payment_date_check
    check (
      payment_date is null
      or order_date is null
      or payment_date >= order_date
    ),

  constraint procurement_received_date_check
    check (
      received_date is null
      or procurement_date <= received_date
    )
);


/* =========================================================
   3. UNIQUE PROCUREMENT NUMBER
   ========================================================= */

create unique index if not exists
  uq_procurement_number
on public.procurement(procurement_number);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_procurement_date
on public.procurement(procurement_date);

create index if not exists
  idx_procurement_status
on public.procurement(status);

create index if not exists
  idx_procurement_category
on public.procurement(category);

create index if not exists
  idx_procurement_vendor
on public.procurement(vendor_name);

create index if not exists
  idx_procurement_funding_source
on public.procurement(funding_source);

create index if not exists
  idx_procurement_requested_by
on public.procurement(requested_by);

create index if not exists
  idx_procurement_created_by
on public.procurement(created_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  procurement_set_updated_at
on public.procurement;

create trigger procurement_set_updated_at
before update
on public.procurement
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.procurement
enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  procurement_select
on public.procurement;

create policy procurement_select
on public.procurement
for select
to authenticated
using (
  public.has_permission('sarpras', 'view')
  or public.has_permission('keuangan', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  procurement_insert
on public.procurement;

create policy procurement_insert
on public.procurement
for insert
to authenticated
with check (
  public.has_permission('sarpras', 'create')
  or public.has_permission('keuangan', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  procurement_update
on public.procurement;

create policy procurement_update
on public.procurement
for update
to authenticated
using (
  public.has_permission('sarpras', 'update')
  or public.has_permission('keuangan', 'update')
)
with check (
  public.has_permission('sarpras', 'update')
  or public.has_permission('keuangan', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  procurement_delete
on public.procurement;

create policy procurement_delete
on public.procurement
for delete
to authenticated
using (
  public.has_permission('sarpras', 'delete')
  or public.has_permission('keuangan', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.procurement
to authenticated;


/* =========================================================
   12. COMMENTS
   ========================================================= */

comment on table public.procurement is
  'Data proses pengadaan barang dan jasa sekolah.';

comment on column public.procurement.procurement_number is
  'Nomor pengadaan yang unik.';

comment on column public.procurement.procurement_date is
  'Tanggal pengajuan atau permintaan pengadaan.';

comment on column public.procurement.title is
  'Nama atau judul pengadaan.';

comment on column public.procurement.quantity is
  'Jumlah barang atau jasa yang dibutuhkan.';

comment on column public.procurement.estimated_unit_price is
  'Estimasi harga satuan.';

comment on column public.procurement.estimated_total is
  'Estimasi total nilai pengadaan.';

comment on column public.procurement.vendor_name is
  'Nama penyedia/vendor.';

comment on column public.procurement.actual_unit_price is
  'Harga satuan aktual.';

comment on column public.procurement.actual_total is
  'Total nilai aktual pengadaan.';

comment on column public.procurement.funding_source is
  'Sumber dana pengadaan.';

comment on column public.procurement.requested_by is
  'User yang mengajukan kebutuhan pengadaan.';

comment on column public.procurement.approved_by is
  'User yang menyetujui pengadaan.';

comment on column public.procurement.received_date is
  'Tanggal barang atau jasa diterima.';

comment on column public.procurement.document_url is
  'Lokasi dokumen pengadaan pada storage/digital archive.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */