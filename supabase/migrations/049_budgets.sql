/*
  Migration 049
  Budgets / Anggaran Keuangan

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan rencana anggaran sekolah.
  - Menghubungkan anggaran dengan tahun ajaran,
    kategori keuangan, dan sumber dana.
  - Menjadi dasar pengendalian realisasi keuangan.
*/


/* =========================================================
   1. ENUM STATUS ANGGARAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'budget_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.budget_status as enum (
      'draft',
      'diajukan',
      'disetujui',
      'ditolak',
      'aktif',
      'selesai',
      'dibatalkan'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE BUDGETS
   ========================================================= */

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),

  budget_code text not null,

  budget_name text not null,

  academic_year_id uuid
    references public.academic_years(id)
    on delete restrict,

  fiscal_year integer not null,

  funding_source_id uuid
    references public.funding_sources(id)
    on delete restrict,

  total_amount numeric(18,2) not null
    default 0,

  status public.budget_status not null
    default 'draft',

  proposed_date date,

  approved_date date,

  start_date date,

  end_date date,

  description text,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  approved_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint budget_code_check
    check (
      length(trim(budget_code)) > 0
    ),

  constraint budget_name_check
    check (
      length(trim(budget_name)) > 0
    ),

  constraint budget_fiscal_year_check
    check (
      fiscal_year between 1900 and 2100
    ),

  constraint budget_total_amount_check
    check (
      total_amount >= 0
    ),

  constraint budget_date_range_check
    check (
      end_date is null
      or start_date is null
      or end_date >= start_date
    ),

  constraint budget_approval_date_check
    check (
      approved_date is null
      or proposed_date is null
      or approved_date >= proposed_date
    ),

  constraint budget_approved_status_check
    check (
      status not in (
        'disetujui',
        'aktif',
        'selesai'
      )
      or approved_date is not null
    )
);


/* =========================================================
   3. UNIQUE BUDGET CODE
   ========================================================= */

create unique index if not exists
  uq_budgets_budget_code
on public.budgets(budget_code);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_budgets_name
on public.budgets(budget_name);

create index if not exists
  idx_budgets_academic_year
on public.budgets(academic_year_id);

create index if not exists
  idx_budgets_fiscal_year
on public.budgets(fiscal_year);

create index if not exists
  idx_budgets_funding_source
on public.budgets(funding_source_id);

create index if not exists
  idx_budgets_status
on public.budgets(status);

create index if not exists
  idx_budgets_start_date
on public.budgets(start_date);

create index if not exists
  idx_budgets_created_by
on public.budgets(created_by);

create index if not exists
  idx_budgets_approved_by
on public.budgets(approved_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  budgets_set_updated_at
on public.budgets;

create trigger budgets_set_updated_at
before update
on public.budgets
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.budgets
enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  budgets_select
on public.budgets;

create policy budgets_select
on public.budgets
for select
to authenticated
using (
  public.has_permission('keuangan', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  budgets_insert
on public.budgets;

create policy budgets_insert
on public.budgets
for insert
to authenticated
with check (
  public.has_permission('keuangan', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  budgets_update
on public.budgets;

create policy budgets_update
on public.budgets
for update
to authenticated
using (
  public.has_permission('keuangan', 'update')
)
with check (
  public.has_permission('keuangan', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  budgets_delete
on public.budgets;

create policy budgets_delete
on public.budgets
for delete
to authenticated
using (
  public.has_permission('keuangan', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.budgets
to authenticated;


/* =========================================================
   12. COMMENTS
   ========================================================= */

comment on table public.budgets is
  'Rencana anggaran keuangan sekolah.';

comment on column public.budgets.budget_code is
  'Kode unik anggaran.';

comment on column public.budgets.budget_name is
  'Nama atau judul anggaran.';

comment on column public.budgets.academic_year_id is
  'Tahun ajaran yang terkait dengan anggaran jika ada.';

comment on column public.budgets.fiscal_year is
  'Tahun anggaran/fiskal.';

comment on column public.budgets.funding_source_id is
  'Sumber dana yang digunakan untuk anggaran.';

comment on column public.budgets.total_amount is
  'Total nilai anggaran.';

comment on column public.budgets.status is
  'Status proses anggaran.';

comment on column public.budgets.proposed_date is
  'Tanggal pengajuan anggaran.';

comment on column public.budgets.approved_date is
  'Tanggal persetujuan anggaran.';

comment on column public.budgets.approved_by is
  'User yang memberikan persetujuan anggaran.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */