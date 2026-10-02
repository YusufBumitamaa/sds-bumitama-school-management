/*
  Migration 053
  Cash Transactions / Transaksi Kas

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Mencatat seluruh pergerakan kas/rekening.
  - Menghubungkan pergerakan kas dengan transaksi
    pemasukan atau pengeluaran.
  - Menyimpan saldo sebelum dan sesudah transaksi.
  - Menjadi ledger untuk laporan kas.
  - Menjaga histori transaksi keuangan.

  Catatan:
  - Tidak digunakan untuk pembayaran siswa.
  - Tidak digunakan untuk gaji/honor.
  - Transaksi final tidak dapat dihapus secara permanen.
*/


/* =========================================================
   1. ENUM JENIS TRANSAKSI KAS
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'cash_transaction_type'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.cash_transaction_type as enum (
      'pemasukan',
      'pengeluaran',
      'transfer_masuk',
      'transfer_keluar',
      'penyesuaian'
    );
  end if;
end
$$;


/* =========================================================
   2. ENUM STATUS TRANSAKSI KAS
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'cash_transaction_status'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.cash_transaction_status as enum (
      'draft',
      'tercatat',
      'dibatalkan'
    );
  end if;
end
$$;


/* =========================================================
   3. TABLE CASH TRANSACTIONS
   ========================================================= */

create table if not exists public.cash_transactions (
  id uuid primary key default gen_random_uuid(),

  transaction_number text not null,

  transaction_date date not null
    default current_date,

  account_id uuid not null
    references public.financial_accounts(id)
    on delete restrict,

  transaction_type public.cash_transaction_type not null,

  status public.cash_transaction_status not null
    default 'draft',

  description text not null,

  amount numeric(18,2) not null,

  balance_before numeric(18,2) not null
    default 0,

  balance_after numeric(18,2) not null
    default 0,

  income_transaction_id uuid
    references public.income_transactions(id)
    on delete restrict,

  expense_transaction_id uuid
    references public.expense_transactions(id)
    on delete restrict,

  reference_number text,

  document_url text,

  notes text,

  created_by uuid
    references public.users(id)
    on delete set null,

  recorded_by uuid
    references public.users(id)
    on delete set null,

  recorded_at timestamptz,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint cash_transactions_number_check
    check (
      length(trim(transaction_number)) > 0
    ),

  constraint cash_transactions_description_check
    check (
      length(trim(description)) > 0
    ),

  constraint cash_transactions_amount_check
    check (
      amount > 0
    ),

  constraint cash_transactions_balance_before_check
    check (
      balance_before >= 0
    ),

  constraint cash_transactions_balance_after_check
    check (
      balance_after >= 0
    ),

  constraint cash_transactions_recorded_check
    check (
      (
        status = 'tercatat'
        and recorded_at is not null
      )
      or
      (
        status <> 'tercatat'
      )
    )
);


/* =========================================================
   4. UNIQUE TRANSACTION NUMBER
   ========================================================= */

create unique index if not exists
  uq_cash_transactions_transaction_number
on public.cash_transactions(transaction_number);


/* =========================================================
   5. INDEXES
   ========================================================= */

create index if not exists
  idx_cash_transactions_date
on public.cash_transactions(transaction_date);

create index if not exists
  idx_cash_transactions_account
on public.cash_transactions(account_id);

create index if not exists
  idx_cash_transactions_type
on public.cash_transactions(transaction_type);

create index if not exists
  idx_cash_transactions_status
on public.cash_transactions(status);

create index if not exists
  idx_cash_transactions_income
on public.cash_transactions(income_transaction_id);

create index if not exists
  idx_cash_transactions_expense
on public.cash_transactions(expense_transaction_id);

create index if not exists
  idx_cash_transactions_created_by
on public.cash_transactions(created_by);

create index if not exists
  idx_cash_transactions_recorded_by
on public.cash_transactions(recorded_by);


/* =========================================================
   6. VALIDATE SOURCE TRANSACTION
   ========================================================= */

create or replace function public.validate_cash_transaction_source()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  income_status public.income_transaction_status;
  expense_status public.expense_transaction_status;
begin

  /*
    Pemasukan harus memiliki income_transaction_id.
  */

  if new.transaction_type = 'pemasukan' then

    if new.income_transaction_id is null then
      raise exception
        'Transaksi kas pemasukan harus memiliki transaksi pemasukan.';
    end if;

    if new.expense_transaction_id is not null then
      raise exception
        'Transaksi kas pemasukan tidak boleh memiliki transaksi pengeluaran.';
    end if;

    select status
    into income_status
    from public.income_transactions
    where id = new.income_transaction_id;

    if income_status is null then
      raise exception
        'Transaksi pemasukan tidak ditemukan.';
    end if;

    if income_status <> 'disetujui' then
      raise exception
        'Transaksi pemasukan harus disetujui sebelum dicatat ke kas.';
    end if;

  end if;


  /*
    Pengeluaran harus memiliki expense_transaction_id.
  */

  if new.transaction_type = 'pengeluaran' then

    if new.expense_transaction_id is null then
      raise exception
        'Transaksi kas pengeluaran harus memiliki transaksi pengeluaran.';
    end if;

    if new.income_transaction_id is not null then
      raise exception
        'Transaksi kas pengeluaran tidak boleh memiliki transaksi pemasukan.';
    end if;

    select status
    into expense_status
    from public.expense_transactions
    where id = new.expense_transaction_id;

    if expense_status is null then
      raise exception
        'Transaksi pengeluaran tidak ditemukan.';
    end if;

    if expense_status <> 'disetujui' then
      raise exception
        'Transaksi pengeluaran harus disetujui sebelum dicatat ke kas.';
    end if;

  end if;


  /*
    Penyesuaian tidak boleh memiliki sumber
    transaksi pemasukan/pengeluaran.
  */

  if new.transaction_type = 'penyesuaian' then

    if new.income_transaction_id is not null
       or new.expense_transaction_id is not null then
      raise exception
        'Penyesuaian kas tidak boleh memiliki transaksi sumber.';
    end if;

  end if;


  return new;
end;
$$;


/* =========================================================
   7. TRIGGER VALIDASI SUMBER
   ========================================================= */

drop trigger if exists
  cash_transactions_validate_source
on public.cash_transactions;

create trigger cash_transactions_validate_source
before insert or update
on public.cash_transactions
for each row
execute function public.validate_cash_transaction_source();


/* =========================================================
   8. CALCULATE BALANCE
   ========================================================= */

create or replace function public.calculate_cash_transaction_balance()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  /*
    Saldo sebelum transaksi berasal dari
    current_balance rekening.
  */

  if new.status = 'tercatat' then

    if new.transaction_type in (
      'pemasukan',
      'transfer_masuk'
    ) then

      new.balance_after :=
        new.balance_before + new.amount;

    elsif new.transaction_type in (
      'pengeluaran',
      'transfer_keluar'
    ) then

      if new.balance_before < new.amount then
        raise exception
          'Saldo tidak mencukupi untuk transaksi kas.';
      end if;

      new.balance_after :=
        new.balance_before - new.amount;

    elsif new.transaction_type = 'penyesuaian' then

      new.balance_after :=
        new.balance_before + new.amount;

    end if;

  end if;

  return new;
end;
$$;


/* =========================================================
   9. TRIGGER CALCULATE BALANCE
   ========================================================= */

drop trigger if exists
  cash_transactions_calculate_balance
on public.cash_transactions;

create trigger cash_transactions_calculate_balance
before insert or update
on public.cash_transactions
for each row
execute function public.calculate_cash_transaction_balance();


/* =========================================================
   10. RECORDING VALIDATION
   ========================================================= */

create or replace function public.validate_cash_transaction_recording()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  if new.status = 'tercatat' then

    if new.recorded_by is null then
      raise exception
        'Transaksi kas yang tercatat harus memiliki recorded_by.';
    end if;

    if new.recorded_at is null then
      new.recorded_at := now();
    end if;

  else

    new.recorded_by := null;
    new.recorded_at := null;

  end if;

  return new;
end;
$$;


/* =========================================================
   11. TRIGGER RECORDING VALIDATION
   ========================================================= */

drop trigger if exists
  cash_transactions_validate_recording
on public.cash_transactions;

create trigger cash_transactions_validate_recording
before insert or update of status, recorded_by, recorded_at
on public.cash_transactions
for each row
execute function public.validate_cash_transaction_recording();


/* =========================================================
   12. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  cash_transactions_set_updated_at
on public.cash_transactions;

create trigger cash_transactions_set_updated_at
before update
on public.cash_transactions
for each row
execute function public.set_updated_at();


/* =========================================================
   13. ROW LEVEL SECURITY
   ========================================================= */

alter table public.cash_transactions
enable row level security;


/* =========================================================
   14. SELECT POLICY
   ========================================================= */

drop policy if exists
  cash_transactions_select
on public.cash_transactions;

create policy cash_transactions_select
on public.cash_transactions
for select
to authenticated
using (
  public.has_permission('keuangan', 'view')
);


/* =========================================================
   15. INSERT POLICY
   ========================================================= */

drop policy if exists
  cash_transactions_insert
on public.cash_transactions;

create policy cash_transactions_insert
on public.cash_transactions
for insert
to authenticated
with check (
  public.has_permission('keuangan', 'create')
);


/* =========================================================
   16. UPDATE POLICY
   ========================================================= */

drop policy if exists
  cash_transactions_update
on public.cash_transactions;

create policy cash_transactions_update
on public.cash_transactions
for update
to authenticated
using (
  public.has_permission('keuangan', 'update')
)
with check (
  public.has_permission('keuangan', 'update')
);


/* =========================================================
   17. DELETE POLICY
   ========================================================= */

drop policy if exists
  cash_transactions_delete
on public.cash_transactions;

create policy cash_transactions_delete
on public.cash_transactions
for delete
to authenticated
using (
  public.has_permission('keuangan', 'delete')
  and status = 'draft'
);


/* =========================================================
   18. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.cash_transactions
to authenticated;


/* =========================================================
   19. FUNCTION SECURITY
   ========================================================= */

revoke execute
on function public.validate_cash_transaction_source()
from public;

revoke execute
on function public.validate_cash_transaction_source()
from anon;

revoke execute
on function public.validate_cash_transaction_source()
from authenticated;


revoke execute
on function public.calculate_cash_transaction_balance()
from public;

revoke execute
on function public.calculate_cash_transaction_balance()
from anon;

revoke execute
on function public.calculate_cash_transaction_balance()
from authenticated;


revoke execute
on function public.validate_cash_transaction_recording()
from public;

revoke execute
on function public.validate_cash_transaction_recording()
from anon;

revoke execute
on function public.validate_cash_transaction_recording()
from authenticated;


/* =========================================================
   20. COMMENTS
   ========================================================= */

comment on table public.cash_transactions is
  'Ledger pergerakan kas dan rekening sekolah.';

comment on column public.cash_transactions.transaction_number is
  'Nomor unik transaksi kas.';

comment on column public.cash_transactions.transaction_date is
  'Tanggal transaksi kas.';

comment on column public.cash_transactions.account_id is
  'Rekening atau kas tempat transaksi terjadi.';

comment on column public.cash_transactions.transaction_type is
  'Jenis pergerakan kas: pemasukan, pengeluaran, transfer masuk, transfer keluar, atau penyesuaian.';

comment on column public.cash_transactions.status is
  'Status pencatatan transaksi kas.';

comment on column public.cash_transactions.amount is
  'Nilai pergerakan kas.';

comment on column public.cash_transactions.balance_before is
  'Saldo rekening sebelum transaksi.';

comment on column public.cash_transactions.balance_after is
  'Saldo rekening setelah transaksi.';

comment on column public.cash_transactions.income_transaction_id is
  'Referensi transaksi pemasukan yang telah disetujui.';

comment on column public.cash_transactions.expense_transaction_id is
  'Referensi transaksi pengeluaran yang telah disetujui.';

comment on column public.cash_transactions.recorded_by is
  'User yang mencatat transaksi ke ledger kas.';

comment on column public.cash_transactions.recorded_at is
  'Waktu transaksi dicatat ke ledger kas.';


/* =========================================================
   MIGRATION 053 SELESAI
   ========================================================= */