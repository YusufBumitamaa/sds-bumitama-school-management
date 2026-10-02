/*
  Migration 038
  Maintenance / Pemeliharaan Sarpras

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Mencatat pemeliharaan dan perbaikan inventaris.
  - Menyimpan jadwal pemeliharaan.
  - Menyimpan biaya pemeliharaan.
  - Menyimpan pihak pelaksana.
  - Menyimpan status pekerjaan.
*/


/* =========================================================
   1. ENUM JENIS PEMELIHARAAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'maintenance_type'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.maintenance_type as enum (
      'pemeliharaan_rutin',
      'perbaikan',
      'servis',
      'penggantian_komponen',
      'lainnya'
    );

  end if;
end
$$;


/* =========================================================
   2. ENUM STATUS PEMELIHARAAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'maintenance_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.maintenance_status as enum (
      'direncanakan',
      'diproses',
      'selesai',
      'dibatalkan'
    );

  end if;
end
$$;


/* =========================================================
   3. TABLE MAINTENANCE
   ========================================================= */

create table if not exists public.maintenance (
  id uuid primary key default gen_random_uuid(),

  inventory_id uuid
    references public.inventory(id)
    on delete restrict,

  room_id uuid
    references public.rooms(id)
    on delete restrict,

  maintenance_type public.maintenance_type not null,

  title text not null,

  description text,

  scheduled_date date,

  started_date date,

  completed_date date,

  service_provider text,

  technician_name text,

  estimated_cost numeric(15,2),

  actual_cost numeric(15,2),

  status public.maintenance_status not null
    default 'direncanakan',

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

  constraint maintenance_title_check
    check (
      length(trim(title)) > 0
    ),

  constraint maintenance_target_check
    check (
      inventory_id is not null
      or room_id is not null
    ),

  constraint maintenance_date_check
    check (
      completed_date is null
      or started_date is null
      or completed_date >= started_date
    ),

  constraint maintenance_estimated_cost_check
    check (
      estimated_cost is null
      or estimated_cost >= 0
    ),

  constraint maintenance_actual_cost_check
    check (
      actual_cost is null
      or actual_cost >= 0
    )
);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_maintenance_inventory
on public.maintenance(inventory_id);

create index if not exists
  idx_maintenance_room
on public.maintenance(room_id);

create index if not exists
  idx_maintenance_type
on public.maintenance(maintenance_type);

create index if not exists
  idx_maintenance_status
on public.maintenance(status);

create index if not exists
  idx_maintenance_scheduled_date
on public.maintenance(scheduled_date);

create index if not exists
  idx_maintenance_created_by
on public.maintenance(created_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  maintenance_set_updated_at
on public.maintenance;

create trigger maintenance_set_updated_at
before update
on public.maintenance
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.maintenance
enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  maintenance_select
on public.maintenance;

create policy maintenance_select
on public.maintenance
for select
to authenticated
using (
  public.has_permission('sarpras', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  maintenance_insert
on public.maintenance;

create policy maintenance_insert
on public.maintenance
for insert
to authenticated
with check (
  public.has_permission('sarpras', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  maintenance_update
on public.maintenance;

create policy maintenance_update
on public.maintenance
for update
to authenticated
using (
  public.has_permission('sarpras', 'update')
)
with check (
  public.has_permission('sarpras', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  maintenance_delete
on public.maintenance;

create policy maintenance_delete
on public.maintenance
for delete
to authenticated
using (
  public.has_permission('sarpras', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.maintenance
to authenticated;


/* =========================================================
   12. COMMENTS
   ========================================================= */

comment on table public.maintenance is
  'Data pemeliharaan dan perbaikan sarana prasarana sekolah.';

comment on column public.maintenance.inventory_id is
  'Inventaris yang dipelihara atau diperbaiki.';

comment on column public.maintenance.room_id is
  'Ruangan yang menjadi objek pemeliharaan.';

comment on column public.maintenance.maintenance_type is
  'Jenis pemeliharaan atau perbaikan.';

comment on column public.maintenance.title is
  'Judul atau nama kegiatan pemeliharaan.';

comment on column public.maintenance.scheduled_date is
  'Tanggal pemeliharaan yang direncanakan.';

comment on column public.maintenance.started_date is
  'Tanggal pekerjaan mulai dilakukan.';

comment on column public.maintenance.completed_date is
  'Tanggal pekerjaan selesai.';

comment on column public.maintenance.service_provider is
  'Penyedia jasa pemeliharaan jika menggunakan pihak luar.';

comment on column public.maintenance.technician_name is
  'Nama teknisi atau pelaksana pekerjaan.';

comment on column public.maintenance.estimated_cost is
  'Estimasi biaya pemeliharaan.';

comment on column public.maintenance.actual_cost is
  'Biaya aktual pemeliharaan.';

comment on column public.maintenance.document_url is
  'Lokasi dokumen pendukung pemeliharaan.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */