/*
  Migration 048
  Funding Sources / Sumber Dana

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan sumber dana yang digunakan sekolah.
  - Menjadi referensi untuk anggaran,
    pemasukan, pengeluaran, dan transaksi keuangan.
*/


/* =========================================================
   1. ENUM JENIS SUMBER DANA
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'funding_source_type'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.funding_source_type as enum (
      'bos',
      'bop',
      'yayasan',
      'hibah',
      'sumbangan',
      'komite',
      'pemerintah',
      'lainnya'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE FUNDING SOURCES
   ========================================================= */

create table if not exists public.funding_sources (
  id uuid primary key default gen_random_uuid(),

  source_code text not null,

  source_name text not null,

  source_type public.funding_source_type not null
    default 'lainnya',

  description text,

  is_active boolean not null
    default true,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint funding_source_code_check
    check (
      length(trim(source_code)) > 0
    ),

  constraint funding_source_name_check
    check (
      length(trim(source_name)) > 0
    )
);


/* =========================================================
   3. UNIQUE SOURCE CODE
   ========================================================= */

create unique index if not exists
  uq_funding_sources_source_code
on public.funding_sources(source_code);


/* =========================================================
   4. UNIQUE SOURCE NAME
   ========================================================= */

create unique index if not exists
  uq_funding_sources_source_name
on public.funding_sources(source_name);


/* =========================================================
   5. INDEXES
   ========================================================= */

create index if not exists
  idx_funding_sources_name
on public.funding_sources(source_name);

create index if not exists
  idx_funding_sources_type
on public.funding_sources(source_type);

create index if not exists
  idx_funding_sources_active
on public.funding_sources(is_active);

create index if not exists
  idx_funding_sources_created_by
on public.funding_sources(created_by);


/* =========================================================
   6. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  funding_sources_set_updated_at
on public.funding_sources;

create trigger funding_sources_set_updated_at
before update
on public.funding_sources
for each row
execute function public.set_updated_at();


/* =========================================================
   7. ROW LEVEL SECURITY
   ========================================================= */

alter table public.funding_sources
enable row level security;


/* =========================================================
   8. SELECT POLICY
   ========================================================= */

drop policy if exists
  funding_sources_select
on public.funding_sources;

create policy funding_sources_select
on public.funding_sources
for select
to authenticated
using (
  public.has_permission('keuangan', 'view')
);


/* =========================================================
   9. INSERT POLICY
   ========================================================= */

drop policy if exists
  funding_sources_insert
on public.funding_sources;

create policy funding_sources_insert
on public.funding_sources
for insert
to authenticated
with check (
  public.has_permission('keuangan', 'create')
);


/* =========================================================
   10. UPDATE POLICY
   ========================================================= */

drop policy if exists
  funding_sources_update
on public.funding_sources;

create policy funding_sources_update
on public.funding_sources
for update
to authenticated
using (
  public.has_permission('keuangan', 'update')
)
with check (
  public.has_permission('keuangan', 'update')
);


/* =========================================================
   11. DELETE POLICY
   ========================================================= */

drop policy if exists
  funding_sources_delete
on public.funding_sources;

create policy funding_sources_delete
on public.funding_sources
for delete
to authenticated
using (
  public.has_permission('keuangan', 'delete')
);


/* =========================================================
   12. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.funding_sources
to authenticated;


/* =========================================================
   13. COMMENTS
   ========================================================= */

comment on table public.funding_sources is
  'Daftar sumber dana yang digunakan dalam pengelolaan keuangan sekolah.';

comment on column public.funding_sources.source_code is
  'Kode unik sumber dana.';

comment on column public.funding_sources.source_name is
  'Nama sumber dana.';

comment on column public.funding_sources.source_type is
  'Jenis sumber dana.';

comment on column public.funding_sources.is_active is
  'Menentukan apakah sumber dana masih aktif digunakan.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */