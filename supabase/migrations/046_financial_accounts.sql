/*
  Migration 046
  Financial Accounts / Rekening Keuangan

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan daftar rekening/kas sekolah.
  - Mendukung rekening bank dan kas tunai.
  - Menjadi referensi transaksi pemasukan,
    pengeluaran, dan kas pada modul keuangan.
*/


/* =========================================================
   1. ENUM JENIS REKENING
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'financial_account_type'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.financial_account_type as enum (
      'kas',
      'bank',
      'rekening_lainnya'
    );

  end if;
end
$$;


/* =========================================================
   2. ENUM STATUS REKENING
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'financial_account_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.financial_account_status as enum (
      'aktif',
      'nonaktif'
    );

  end if;
end
$$;


/* =========================================================
   3. TABLE FINANCIAL ACCOUNTS
   ========================================================= */

create table if not exists public.financial_accounts (
  id uuid primary key default gen_random_uuid(),

  account_code text not null,

  account_name text not null,

  account_type public.financial_account_type not null
    default 'kas',

  bank_name text,

  account_number text,

  account_holder_name text,

  opening_balance numeric(18,2) not null
    default 0,

  current_balance numeric(18,2) not null
    default 0,

  status public.financial_account_status not null
    default 'aktif',

  description text,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint financial_account_code_check
    check (
      length(trim(account_code)) > 0
    ),

  constraint financial_account_name_check
    check (
      length(trim(account_name)) > 0
    ),

  constraint financial_account_opening_balance_check
    check (
      opening_balance >= 0
    ),

  constraint financial_account_type_check
    check (
      account_type <> 'bank'
      or length(trim(coalesce(bank_name, ''))) > 0
    )
);


/* =========================================================
   4. UNIQUE ACCOUNT CODE
   ========================================================= */

create unique index if not exists
  uq_financial_accounts_account_code
on public.financial_accounts(account_code);


/* =========================================================
   5. UNIQUE ACCOUNT NUMBER
   ========================================================= */

create unique index if not exists
  uq_financial_accounts_account_number
on public.financial_accounts(account_number)
where account_number is not null
  and length(trim(account_number)) > 0;


/* =========================================================
   6. INDEXES
   ========================================================= */

create index if not exists
  idx_financial_accounts_name
on public.financial_accounts(account_name);

create index if not exists
  idx_financial_accounts_type
on public.financial_accounts(account_type);

create index if not exists
  idx_financial_accounts_status
on public.financial_accounts(status);

create index if not exists
  idx_financial_accounts_bank
on public.financial_accounts(bank_name);

create index if not exists
  idx_financial_accounts_created_by
on public.financial_accounts(created_by);


/* =========================================================
   7. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  financial_accounts_set_updated_at
on public.financial_accounts;

create trigger financial_accounts_set_updated_at
before update
on public.financial_accounts
for each row
execute function public.set_updated_at();


/* =========================================================
   8. ROW LEVEL SECURITY
   ========================================================= */

alter table public.financial_accounts
enable row level security;


/* =========================================================
   9. SELECT POLICY
   ========================================================= */

drop policy if exists
  financial_accounts_select
on public.financial_accounts;

create policy financial_accounts_select
on public.financial_accounts
for select
to authenticated
using (
  public.has_permission('keuangan', 'view')
);


/* =========================================================
   10. INSERT POLICY
   ========================================================= */

drop policy if exists
  financial_accounts_insert
on public.financial_accounts;

create policy financial_accounts_insert
on public.financial_accounts
for insert
to authenticated
with check (
  public.has_permission('keuangan', 'create')
);


/* =========================================================
   11. UPDATE POLICY
   ========================================================= */

drop policy if exists
  financial_accounts_update
on public.financial_accounts;

create policy financial_accounts_update
on public.financial_accounts
for update
to authenticated
using (
  public.has_permission('keuangan', 'update')
)
with check (
  public.has_permission('keuangan', 'update')
);


/* =========================================================
   12. DELETE POLICY
   ========================================================= */

drop policy if exists
  financial_accounts_delete
on public.financial_accounts;

create policy financial_accounts_delete
on public.financial_accounts
for delete
to authenticated
using (
  public.has_permission('keuangan', 'delete')
);


/* =========================================================
   13. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.financial_accounts
to authenticated;


/* =========================================================
   14. COMMENTS
   ========================================================= */

comment on table public.financial_accounts is
  'Daftar rekening dan kas yang digunakan dalam administrasi keuangan sekolah.';

comment on column public.financial_accounts.account_code is
  'Kode unik rekening atau kas.';

comment on column public.financial_accounts.account_name is
  'Nama rekening atau kas.';

comment on column public.financial_accounts.account_type is
  'Jenis rekening: kas, bank, atau rekening lainnya.';

comment on column public.financial_accounts.bank_name is
  'Nama bank jika rekening bertipe bank.';

comment on column public.financial_accounts.account_number is
  'Nomor rekening bank jika tersedia.';

comment on column public.financial_accounts.account_holder_name is
  'Nama pemilik/pemegang rekening.';

comment on column public.financial_accounts.opening_balance is
  'Saldo awal rekening.';

comment on column public.financial_accounts.current_balance is
  'Saldo berjalan rekening.';

comment on column public.financial_accounts.status is
  'Status rekening aktif atau nonaktif.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */