/*
  Migration 047
  Financial Categories / Kategori Keuangan

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan kategori pemasukan dan pengeluaran.
  - Mendukung struktur kategori induk dan subkategori.
  - Menjadi referensi transaksi keuangan.
*/


/* =========================================================
   1. ENUM JENIS KATEGORI
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'financial_category_type'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.financial_category_type as enum (
      'pemasukan',
      'pengeluaran',
      'umum'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE FINANCIAL CATEGORIES
   ========================================================= */

create table if not exists public.financial_categories (
  id uuid primary key default gen_random_uuid(),

  category_code text not null,

  category_name text not null,

  category_type public.financial_category_type not null
    default 'umum',

  parent_category_id uuid
    references public.financial_categories(id)
    on delete restrict,

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

  constraint financial_category_code_check
    check (
      length(trim(category_code)) > 0
    ),

  constraint financial_category_name_check
    check (
      length(trim(category_name)) > 0
    ),

  constraint financial_category_parent_check
    check (
      parent_category_id is null
      or parent_category_id <> id
    )
);


/* =========================================================
   3. UNIQUE CATEGORY CODE
   ========================================================= */

create unique index if not exists
  uq_financial_categories_code
on public.financial_categories(category_code);


/* =========================================================
   4. UNIQUE CATEGORY NAME PER TYPE AND PARENT
   ========================================================= */

create unique index if not exists
  uq_financial_categories_name_type_parent
on public.financial_categories(
  category_name,
  category_type,
  coalesce(parent_category_id, '00000000-0000-0000-0000-000000000000'::uuid)
);


/* =========================================================
   5. INDEXES
   ========================================================= */

create index if not exists
  idx_financial_categories_name
on public.financial_categories(category_name);

create index if not exists
  idx_financial_categories_type
on public.financial_categories(category_type);

create index if not exists
  idx_financial_categories_parent
on public.financial_categories(parent_category_id);

create index if not exists
  idx_financial_categories_active
on public.financial_categories(is_active);

create index if not exists
  idx_financial_categories_created_by
on public.financial_categories(created_by);


/* =========================================================
   6. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  financial_categories_set_updated_at
on public.financial_categories;

create trigger financial_categories_set_updated_at
before update
on public.financial_categories
for each row
execute function public.set_updated_at();


/* =========================================================
   7. ROW LEVEL SECURITY
   ========================================================= */

alter table public.financial_categories
enable row level security;


/* =========================================================
   8. SELECT POLICY
   ========================================================= */

drop policy if exists
  financial_categories_select
on public.financial_categories;

create policy financial_categories_select
on public.financial_categories
for select
to authenticated
using (
  public.has_permission('keuangan', 'view')
);


/* =========================================================
   9. INSERT POLICY
   ========================================================= */

drop policy if exists
  financial_categories_insert
on public.financial_categories;

create policy financial_categories_insert
on public.financial_categories
for insert
to authenticated
with check (
  public.has_permission('keuangan', 'create')
);


/* =========================================================
   10. UPDATE POLICY
   ========================================================= */

drop policy if exists
  financial_categories_update
on public.financial_categories;

create policy financial_categories_update
on public.financial_categories
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
  financial_categories_delete
on public.financial_categories;

create policy financial_categories_delete
on public.financial_categories
for delete
to authenticated
using (
  public.has_permission('keuangan', 'delete')
);


/* =========================================================
   12. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.financial_categories
to authenticated;


/* =========================================================
   13. COMMENTS
   ========================================================= */

comment on table public.financial_categories is
  'Kategori pemasukan, pengeluaran, dan kategori umum keuangan sekolah.';

comment on column public.financial_categories.category_code is
  'Kode unik kategori keuangan.';

comment on column public.financial_categories.category_name is
  'Nama kategori keuangan.';

comment on column public.financial_categories.category_type is
  'Jenis kategori: pemasukan, pengeluaran, atau umum.';

comment on column public.financial_categories.parent_category_id is
  'Kategori induk untuk membentuk struktur kategori bertingkat.';

comment on column public.financial_categories.is_active is
  'Menentukan apakah kategori masih dapat digunakan untuk transaksi.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */