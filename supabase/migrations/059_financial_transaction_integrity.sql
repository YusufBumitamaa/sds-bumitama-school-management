/*
  Migration 059
  Financial Transaction Integrity & Reconciliation

  Acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0
  - Migration 051 - Income Transactions
  - Migration 052 - Expense Transactions
  - Migration 053 - Cash Transactions
  - Migration 056 - Financial Account Balance
  - Migration 057 - Financial Approval Sync

  Tujuan:
  1. Memastikan status transaksi dan approval konsisten.
  2. Memastikan transaksi disetujui memiliki informasi approval.
  3. Memastikan transaksi yang belum disetujui tidak memiliki
     approved_by / approved_at.
  4. Mencegah transaksi yang sudah digunakan sebagai ledger kas
     diubah pada bagian finansial penting.
  5. Menyediakan fungsi pemeriksaan integritas transaksi.
*/


/* =========================================================
   1. VALIDATE INCOME TRANSACTION INTEGRITY
   ========================================================= */

create or replace function public.validate_income_transaction_integrity()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  /*
    Nilai transaksi harus positif.
  */

  if new.amount <= 0 then
    raise exception
      'Nominal transaksi pemasukan harus lebih besar dari 0.';
  end if;


  /*
    Status disetujui wajib memiliki approval.
  */

  if new.status = 'disetujui'
     and (
       new.approved_by is null
       or new.approved_at is null
     ) then

    raise exception
      'Transaksi pemasukan berstatus disetujui wajib memiliki approved_by dan approved_at.';

  end if;


  /*
    Status selain disetujui tidak boleh
    menyimpan informasi approval final.
  */

  if new.status <> 'disetujui'
     and (
       new.approved_by is not null
       or new.approved_at is not null
     ) then

    raise exception
      'Transaksi pemasukan yang belum disetujui tidak boleh memiliki approval final.';

  end if;


  return new;

end;
$$;


/* =========================================================
   2. TRIGGER INCOME INTEGRITY
   ========================================================= */

drop trigger if exists
  income_transaction_integrity
on public.income_transactions;

create trigger income_transaction_integrity
before insert or update
on public.income_transactions
for each row
execute function public.validate_income_transaction_integrity();


/* =========================================================
   3. VALIDATE EXPENSE TRANSACTION INTEGRITY
   ========================================================= */

create or replace function public.validate_expense_transaction_integrity()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  /*
    Nilai transaksi harus positif.
  */

  if new.amount <= 0 then
    raise exception
      'Nominal transaksi pengeluaran harus lebih besar dari 0.';
  end if;


  /*
    Status disetujui wajib memiliki approval.
  */

  if new.status = 'disetujui'
     and (
       new.approved_by is null
       or new.approved_at is null
     ) then

    raise exception
      'Transaksi pengeluaran berstatus disetujui wajib memiliki approved_by dan approved_at.';

  end if;


  /*
    Status selain disetujui tidak boleh
    menyimpan informasi approval final.
  */

  if new.status <> 'disetujui'
     and (
       new.approved_by is not null
       or new.approved_at is not null
     ) then

    raise exception
      'Transaksi pengeluaran yang belum disetujui tidak boleh memiliki approval final.';

  end if;


  return new;

end;
$$;


/* =========================================================
   4. TRIGGER EXPENSE INTEGRITY
   ========================================================= */

drop trigger if exists
  expense_transaction_integrity
on public.expense_transactions;

create trigger expense_transaction_integrity
before insert or update
on public.expense_transactions
for each row
execute function public.validate_expense_transaction_integrity();


/* =========================================================
   5. PROTECT TRANSACTIONS ALREADY IN CASH LEDGER
   ========================================================= */

create or replace function public.prevent_linked_transaction_financial_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  linked_cash_count integer;
begin

  /*
    Hanya periksa jika transaksi sudah pernah
    digunakan sebagai sumber cash transaction.
  */

  if tg_table_name = 'income_transactions' then

    select count(*)
    into linked_cash_count
    from public.cash_transactions
    where income_transaction_id = old.id
      and status <> 'dibatalkan';


  elsif tg_table_name = 'expense_transactions' then

    select count(*)
    into linked_cash_count
    from public.cash_transactions
    where expense_transaction_id = old.id
      and status <> 'dibatalkan';

  end if;


  /*
    Jika belum digunakan sebagai ledger kas,
    transaksi masih dapat diperbarui sesuai RLS.
  */

  if linked_cash_count = 0 then
    return new;
  end if;


  /*
    Setelah masuk ledger kas aktif, informasi finansial
    utama tidak boleh berubah.
  */

  if new.account_id is distinct from old.account_id
     or new.amount is distinct from old.amount
     or new.transaction_date is distinct from old.transaction_date
     or new.category_id is distinct from old.category_id
     or new.funding_source_id is distinct from old.funding_source_id
     or new.budget_id is distinct from old.budget_id then

    raise exception
      'Transaksi keuangan yang sudah tercatat dalam ledger kas tidak dapat mengubah informasi finansial utamanya.';

  end if;


  return new;

end;
$$;


/* =========================================================
   6. TRIGGER PROTECT INCOME
   ========================================================= */

drop trigger if exists
  income_transaction_linked_protection
on public.income_transactions;

create trigger income_transaction_linked_protection
before update
on public.income_transactions
for each row
execute function public.prevent_linked_transaction_financial_change();


/* =========================================================
   7. TRIGGER PROTECT EXPENSE
   ========================================================= */

drop trigger if exists
  expense_transaction_linked_protection
on public.expense_transactions;

create trigger expense_transaction_linked_protection
before update
on public.expense_transactions
for each row
execute function public.prevent_linked_transaction_financial_change();


/* =========================================================
   8. CASH TRANSACTION SOURCE VALIDATION
   ========================================================= */

create or replace function public.validate_cash_transaction_source_integrity()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  source_amount numeric(18,2);
  source_account uuid;
begin

  /*
    Transaksi kas dari pemasukan yang disetujui.
  */

  if new.income_transaction_id is not null then

    select
      amount,
      account_id
    into
      source_amount,
      source_account
    from public.income_transactions
    where id = new.income_transaction_id
      and status = 'disetujui';

    if source_amount is null then
      raise exception
        'Sumber transaksi pemasukan harus berstatus disetujui.';
    end if;


    if new.amount <> source_amount then
      raise exception
        'Nominal transaksi kas harus sama dengan nominal transaksi pemasukan sumber.';
    end if;


    if new.account_id <> source_account then
      raise exception
        'Rekening transaksi kas harus sama dengan rekening transaksi pemasukan sumber.';
    end if;

  end if;


  /*
    Transaksi kas dari pengeluaran yang disetujui.
  */

  if new.expense_transaction_id is not null then

    select
      amount,
      account_id
    into
      source_amount,
      source_account
    from public.expense_transactions
    where id = new.expense_transaction_id
      and status = 'disetujui';

    if source_amount is null then
      raise exception
        'Sumber transaksi pengeluaran harus berstatus disetujui.';
    end if;


    if new.amount <> source_amount then
      raise exception
        'Nominal transaksi kas harus sama dengan nominal transaksi pengeluaran sumber.';
    end if;


    if new.account_id <> source_account then
      raise exception
        'Rekening transaksi kas harus sama dengan rekening transaksi pengeluaran sumber.';
    end if;

  end if;


  return new;

end;
$$;


/* =========================================================
   9. TRIGGER CASH SOURCE VALIDATION
   ========================================================= */

drop trigger if exists
  cash_transaction_source_integrity
on public.cash_transactions;

create trigger cash_transaction_source_integrity
before insert or update
on public.cash_transactions
for each row
execute function public.validate_cash_transaction_source_integrity();


/* =========================================================
   10. RECONCILIATION FUNCTION
   ========================================================= */

create or replace function public.check_financial_transaction_integrity()
returns table (
  issue_type text,
  transaction_id uuid,
  transaction_type text,
  description text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  /*
    ---------------------------------------------------------
    A. INCOME APPROVED WITHOUT APPROVAL DATA
    ---------------------------------------------------------
  */

  return query
  select
    'income_missing_approval'::text,
    i.id,
    'income'::text,
    'Transaksi pemasukan berstatus disetujui tetapi tidak memiliki approved_by atau approved_at.'::text
  from public.income_transactions i
  where i.status = 'disetujui'
    and (
      i.approved_by is null
      or i.approved_at is null
    );


  /*
    ---------------------------------------------------------
    B. EXPENSE APPROVED WITHOUT APPROVAL DATA
    ---------------------------------------------------------
  */

  return query
  select
    'expense_missing_approval'::text,
    e.id,
    'expense'::text,
    'Transaksi pengeluaran berstatus disetujui tetapi tidak memiliki approved_by atau approved_at.'::text
  from public.expense_transactions e
  where e.status = 'disetujui'
    and (
      e.approved_by is null
      or e.approved_at is null
    );


  /*
    ---------------------------------------------------------
    C. CASH FROM UNAPPROVED INCOME
    ---------------------------------------------------------
  */

  return query
  select
    'cash_invalid_income_source'::text,
    c.id,
    'cash'::text,
    'Transaksi kas menggunakan sumber pemasukan yang tidak berstatus disetujui.'::text
  from public.cash_transactions c
  join public.income_transactions i
    on i.id = c.income_transaction_id
  where i.status <> 'disetujui'
    and c.status <> 'dibatalkan';


  /*
    ---------------------------------------------------------
    D. CASH FROM UNAPPROVED EXPENSE
    ---------------------------------------------------------
  */

  return query
  select
    'cash_invalid_expense_source'::text,
    c.id,
    'cash'::text,
    'Transaksi kas menggunakan sumber pengeluaran yang tidak berstatus disetujui.'::text
  from public.cash_transactions c
  join public.expense_transactions e
    on e.id = c.expense_transaction_id
  where e.status <> 'disetujui'
    and c.status <> 'dibatalkan';


  /*
    ---------------------------------------------------------
    E. CASH AMOUNT DIFFERENCE - INCOME
    ---------------------------------------------------------
  */

  return query
  select
    'cash_income_amount_mismatch'::text,
    c.id,
    'cash'::text,
    'Nominal transaksi kas berbeda dengan nominal transaksi pemasukan sumber.'::text
  from public.cash_transactions c
  join public.income_transactions i
    on i.id = c.income_transaction_id
  where c.status <> 'dibatalkan'
    and c.amount <> i.amount;


  /*
    ---------------------------------------------------------
    F. CASH AMOUNT DIFFERENCE - EXPENSE
    ---------------------------------------------------------
  */

  return query
  select
    'cash_expense_amount_mismatch'::text,
    c.id,
    'cash'::text,
    'Nominal transaksi kas berbeda dengan nominal transaksi pengeluaran sumber.'::text
  from public.cash_transactions c
  join public.expense_transactions e
    on e.id = c.expense_transaction_id
  where c.status <> 'dibatalkan'
    and c.amount <> e.amount;


  /*
    ---------------------------------------------------------
    G. CASH ACCOUNT DIFFERENCE - INCOME
    ---------------------------------------------------------
  */

  return query
  select
    'cash_income_account_mismatch'::text,
    c.id,
    'cash'::text,
    'Rekening transaksi kas berbeda dengan rekening transaksi pemasukan sumber.'::text
  from public.cash_transactions c
  join public.income_transactions i
    on i.id = c.income_transaction_id
  where c.status <> 'dibatalkan'
    and c.account_id <> i.account_id;


  /*
    ---------------------------------------------------------
    H. CASH ACCOUNT DIFFERENCE - EXPENSE
    ---------------------------------------------------------
  */

  return query
  select
    'cash_expense_account_mismatch'::text,
    c.id,
    'cash'::text,
    'Rekening transaksi kas berbeda dengan rekening transaksi pengeluaran sumber.'::text
  from public.cash_transactions c
  join public.expense_transactions e
    on e.id = c.expense_transaction_id
  where c.status <> 'dibatalkan'
    and c.account_id <> e.account_id;

end;
$$;


/* =========================================================
   11. FUNCTION SECURITY
   ========================================================= */

revoke execute
on function public.validate_income_transaction_integrity()
from public;

revoke execute
on function public.validate_income_transaction_integrity()
from anon;

revoke execute
on function public.validate_income_transaction_integrity()
from authenticated;


revoke execute
on function public.validate_expense_transaction_integrity()
from public;

revoke execute
on function public.validate_expense_transaction_integrity()
from anon;

revoke execute
on function public.validate_expense_transaction_integrity()
from authenticated;


revoke execute
on function public.prevent_linked_transaction_financial_change()
from public;

revoke execute
on function public.prevent_linked_transaction_financial_change()
from anon;

revoke execute
on function public.prevent_linked_transaction_financial_change()
from authenticated;


revoke execute
on function public.validate_cash_transaction_source_integrity()
from public;

revoke execute
on function public.validate_cash_transaction_source_integrity()
from anon;

revoke execute
on function public.validate_cash_transaction_source_integrity()
from authenticated;


revoke execute
on function public.check_financial_transaction_integrity()
from public;

revoke execute
on function public.check_financial_transaction_integrity()
from anon;

revoke execute
on function public.check_financial_transaction_integrity()
from authenticated;


/* =========================================================
   12. COMMENTS
   ========================================================= */

comment on function public.check_financial_transaction_integrity() is
  'Memeriksa konsistensi transaksi pemasukan, pengeluaran, approval, dan ledger kas.';

comment on function public.validate_cash_transaction_source_integrity() is
  'Memastikan transaksi kas yang berasal dari pemasukan atau pengeluaran memiliki sumber yang telah disetujui dengan nominal dan rekening yang sama.';


/* =========================================================
   MIGRATION 059 SELESAI
   ========================================================= */