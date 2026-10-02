/*
  Migration 051
  Income Transactions / Transaksi Pemasukan

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Mencatat seluruh transaksi pemasukan sekolah.
  - Menghubungkan transaksi dengan rekening,
    kategori, sumber dana, dan anggaran.
  - Mendukung status transaksi keuangan.
  - Mendukung proses persetujuan oleh pengguna
    yang memiliki permission keuangan.approve.

  Catatan:
  - Tidak digunakan untuk pembayaran siswa.
  - Tidak digunakan untuk gaji/honor.
  - Transaksi yang sudah disetujui tidak boleh
    dihapus secara permanen.
*/


/* =========================================================
   1. ENUM STATUS TRANSAKSI KEUANGAN
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'income_transaction_status'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.income_transaction_status as enum (
      'draft',
      'menunggu_persetujuan',
      'disetujui',
      'ditolak',
      'dibatalkan'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE INCOME TRANSACTIONS
   ========================================================= */

create table if not exists public.income_transactions (
  id uuid primary key default gen_random_uuid(),

  transaction_number text not null,

  transaction_date date not null
    default current_date,

  account_id uuid not null
    references public.financial_accounts(id)
    on delete restrict,

  category_id uuid not null
    references public.financial_categories(id)
    on delete restrict,

  funding_source_id uuid
    references public.funding_sources(id)
    on delete restrict,

  budget_id uuid
    references public.budgets(id)
    on delete restrict,

  description text not null,

  amount numeric(18,2) not null,

  payer_name text,

  reference_number text,

  status public.income_transaction_status not null
    default 'draft',

  document_url text,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  approved_by uuid
    references public.users(id)
    on delete set null,

  approved_at timestamptz,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint income_transactions_number_check
    check (
      length(trim(transaction_number)) > 0
    ),

  constraint income_transactions_description_check
    check (
      length(trim(description)) > 0
    ),

  constraint income_transactions_amount_check
    check (
      amount > 0
    ),

  constraint income_transactions_approval_check
    check (
      (
        status = 'disetujui'
        and approved_at is not null
      )
      or
      (
        status <> 'disetujui'
      )
    )
);


/* =========================================================
   3. UNIQUE TRANSACTION NUMBER
   ========================================================= */

create unique index if not exists
  uq_income_transactions_transaction_number
on public.income_transactions(transaction_number);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_income_transactions_date
on public.income_transactions(transaction_date);

create index if not exists
  idx_income_transactions_account
on public.income_transactions(account_id);

create index if not exists
  idx_income_transactions_category
on public.income_transactions(category_id);

create index if not exists
  idx_income_transactions_funding_source
on public.income_transactions(funding_source_id);

create index if not exists
  idx_income_transactions_budget
on public.income_transactions(budget_id);

create index if not exists
  idx_income_transactions_status
on public.income_transactions(status);

create index if not exists
  idx_income_transactions_created_by
on public.income_transactions(created_by);

create index if not exists
  idx_income_transactions_approved_by
on public.income_transactions(approved_by);


/* =========================================================
   5. VALIDATE INCOME CATEGORY
   ========================================================= */

create or replace function public.validate_income_transaction_category()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  selected_category_type public.financial_category_type;
begin

  select category_type
  into selected_category_type
  from public.financial_categories
  where id = new.category_id;

  if selected_category_type is null then
    raise exception
      'Kategori keuangan tidak ditemukan.';
  end if;

  if selected_category_type not in (
    'pemasukan',
    'umum'
  ) then
    raise exception
      'Kategori transaksi pemasukan harus bertipe pemasukan atau umum.';
  end if;

  return new;
end;
$$;


/* =========================================================
   6. TRIGGER VALIDASI KATEGORI
   ========================================================= */

drop trigger if exists
  income_transactions_validate_category
on public.income_transactions;

create trigger income_transactions_validate_category
before insert or update of category_id
on public.income_transactions
for each row
execute function public.validate_income_transaction_category();


/* =========================================================
   7. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  income_transactions_set_updated_at
on public.income_transactions;

create trigger income_transactions_set_updated_at
before update
on public.income_transactions
for each row
execute function public.set_updated_at();


/* =========================================================
   8. VALIDASI STATUS PERSETUJUAN
   ========================================================= */

create or replace function public.validate_income_transaction_approval()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  /*
    Jika transaksi berubah menjadi disetujui,
    maka approved_by dan approved_at wajib tersedia.
  */

  if new.status = 'disetujui' then

    if new.approved_by is null then
      raise exception
        'Transaksi yang disetujui harus memiliki approved_by.';
    end if;

    if new.approved_at is null then
      new.approved_at := now();
    end if;

  else

    /*
      Jika status bukan disetujui,
      informasi approval harus dikosongkan.
    */

    new.approved_by := null;
    new.approved_at := null;

  end if;

  return new;
end;
$$;


/* =========================================================
   9. TRIGGER VALIDASI APPROVAL
   ========================================================= */

drop trigger if exists
  income_transactions_validate_approval
on public.income_transactions;

create trigger income_transactions_validate_approval
before insert or update of status, approved_by, approved_at
on public.income_transactions
for each row
execute function public.validate_income_transaction_approval();


/* =========================================================
   10. ROW LEVEL SECURITY
   ========================================================= */

alter table public.income_transactions
enable row level security;


/* =========================================================
   11. SELECT POLICY
   ========================================================= */

drop policy if exists
  income_transactions_select
on public.income_transactions;

create policy income_transactions_select
on public.income_transactions
for select
to authenticated
using (
  public.has_permission('keuangan', 'view')
);


/* =========================================================
   12. INSERT POLICY
   ========================================================= */

drop policy if exists
  income_transactions_insert
on public.income_transactions;

create policy income_transactions_insert
on public.income_transactions
for insert
to authenticated
with check (
  public.has_permission('keuangan', 'create')
);


/* =========================================================
   13. UPDATE POLICY
   ========================================================= */

drop policy if exists
  income_transactions_update
on public.income_transactions;

create policy income_transactions_update
on public.income_transactions
for update
to authenticated
using (
  public.has_permission('keuangan', 'update')
  or
  public.has_permission('keuangan', 'approve')
)
with check (
  public.has_permission('keuangan', 'update')
  or
  public.has_permission('keuangan', 'approve')
);


/* =========================================================
   14. DELETE POLICY
   ========================================================= */

drop policy if exists
  income_transactions_delete
on public.income_transactions;

create policy income_transactions_delete
on public.income_transactions
for delete
to authenticated
using (
  public.has_permission('keuangan', 'delete')
  and status in (
    'draft',
    'ditolak',
    'dibatalkan'
  )
);


/* =========================================================
   15. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.income_transactions
to authenticated;


/* =========================================================
   16. FUNCTION SECURITY
   ========================================================= */

revoke execute
on function public.validate_income_transaction_category()
from public;

revoke execute
on function public.validate_income_transaction_category()
from anon;

revoke execute
on function public.validate_income_transaction_category()
from authenticated;

revoke execute
on function public.validate_income_transaction_approval()
from public;

revoke execute
on function public.validate_income_transaction_approval()
from anon;

revoke execute
on function public.validate_income_transaction_approval()
from authenticated;


/* =========================================================
   17. COMMENTS
   ========================================================= */

comment on table public.income_transactions is
  'Transaksi pemasukan sekolah. Tidak digunakan untuk pembayaran siswa atau gaji/honor.';

comment on column public.income_transactions.transaction_number is
  'Nomor unik transaksi pemasukan.';

comment on column public.income_transactions.transaction_date is
  'Tanggal transaksi pemasukan.';

comment on column public.income_transactions.account_id is
  'Rekening atau kas yang menerima dana.';

comment on column public.income_transactions.category_id is
  'Kategori pemasukan.';

comment on column public.income_transactions.funding_source_id is
  'Sumber dana transaksi.';

comment on column public.income_transactions.budget_id is
  'Anggaran terkait jika transaksi memiliki kaitan dengan anggaran.';

comment on column public.income_transactions.description is
  'Uraian transaksi pemasukan.';

comment on column public.income_transactions.amount is
  'Nilai transaksi pemasukan.';

comment on column public.income_transactions.payer_name is
  'Nama pihak yang memberikan dana jika diperlukan.';

comment on column public.income_transactions.reference_number is
  'Nomor referensi atau bukti transaksi.';

comment on column public.income_transactions.status is
  'Status transaksi: draft, menunggu_persetujuan, disetujui, ditolak, dibatalkan.';

comment on column public.income_transactions.approved_by is
  'User yang memberikan persetujuan transaksi.';

comment on column public.income_transactions.approved_at is
  'Waktu transaksi disetujui.';


/* =========================================================
   MIGRATION 051 SELESAI
   ========================================================= */