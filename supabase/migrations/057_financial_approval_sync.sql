/*
  Migration 057
  Financial Approval Status Synchronization

  Acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0
  - Migration 051 - Income Transactions
  - Migration 052 - Expense Transactions
  - Migration 055 - Financial Approvals

  Tujuan:
  1. Menjadikan financial_approvals sebagai bagian aktif
     dari workflow transaksi keuangan.
  2. Menyinkronkan action approval dengan status transaksi.
  3. Menjaga approved_by dan approved_at tetap konsisten.
  4. Menjadikan riwayat financial_approvals append-only.
  5. Mempertahankan Bendahara sebagai role yang dapat melakukan
     approval sesuai keputusan requirement terbaru.

  Workflow:
    draft
      ↓
    diajukan
      ↓
    menunggu_persetujuan
      ↓
    disetujui / ditolak / dibatalkan

  Catatan:
  - Cash transaction bukan objek approval utama.
  - Cash transaction menggunakan transaksi pemasukan/
    pengeluaran yang telah disetujui sebagai sumber ledger.
*/


/* =========================================================
   1. FUNCTION SYNC INCOME TRANSACTION
   ========================================================= */

create or replace function public.sync_income_transaction_from_approval()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  if new.income_transaction_id is null then
    return new;
  end if;


  /*
    AJUKAN
  */

  if new.action = 'diajukan' then

    update public.income_transactions
    set status = 'menunggu_persetujuan',
        approved_by = null,
        approved_at = null,
        updated_at = now()
    where id = new.income_transaction_id
      and status = 'draft';

  end if;


  /*
    SETUJUI
  */

  if new.action = 'disetujui' then

    update public.income_transactions
    set status = 'disetujui',
        approved_by = new.acted_by,
        approved_at = new.acted_at,
        updated_at = now()
    where id = new.income_transaction_id
      and status = 'menunggu_persetujuan';

  end if;


  /*
    TOLAK
  */

  if new.action = 'ditolak' then

    update public.income_transactions
    set status = 'ditolak',
        approved_by = null,
        approved_at = null,
        updated_at = now()
    where id = new.income_transaction_id
      and status = 'menunggu_persetujuan';

  end if;


  /*
    BATALKAN
  */

  if new.action = 'dibatalkan' then

    update public.income_transactions
    set status = 'dibatalkan',
        approved_by = null,
        approved_at = null,
        updated_at = now()
    where id = new.income_transaction_id
      and status in (
        'draft',
        'menunggu_persetujuan',
        'ditolak'
      );

  end if;


  return new;

end;
$$;


/* =========================================================
   2. FUNCTION SYNC EXPENSE TRANSACTION
   ========================================================= */

create or replace function public.sync_expense_transaction_from_approval()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  if new.expense_transaction_id is null then
    return new;
  end if;


  /*
    AJUKAN
  */

  if new.action = 'diajukan' then

    update public.expense_transactions
    set status = 'menunggu_persetujuan',
        approved_by = null,
        approved_at = null,
        updated_at = now()
    where id = new.expense_transaction_id
      and status = 'draft';

  end if;


  /*
    SETUJUI
  */

  if new.action = 'disetujui' then

    update public.expense_transactions
    set status = 'disetujui',
        approved_by = new.acted_by,
        approved_at = new.acted_at,
        updated_at = now()
    where id = new.expense_transaction_id
      and status = 'menunggu_persetujuan';

  end if;


  /*
    TOLAK
  */

  if new.action = 'ditolak' then

    update public.expense_transactions
    set status = 'ditolak',
        approved_by = null,
        approved_at = null,
        updated_at = now()
    where id = new.expense_transaction_id
      and status = 'menunggu_persetujuan';

  end if;


  /*
    BATALKAN
  */

  if new.action = 'dibatalkan' then

    update public.expense_transactions
    set status = 'dibatalkan',
        approved_by = null,
        approved_at = null,
        updated_at = now()
    where id = new.expense_transaction_id
      and status in (
        'draft',
        'menunggu_persetujuan',
        'ditolak'
      );

  end if;


  return new;

end;
$$;


/* =========================================================
   3. TRIGGER INCOME APPROVAL SYNC
   ========================================================= */

drop trigger if exists
  financial_approval_sync_income
on public.financial_approvals;

create trigger financial_approval_sync_income
after insert
on public.financial_approvals
for each row
when (new.income_transaction_id is not null)
execute function public.sync_income_transaction_from_approval();


/* =========================================================
   4. TRIGGER EXPENSE APPROVAL SYNC
   ========================================================= */

drop trigger if exists
  financial_approval_sync_expense
on public.financial_approvals;

create trigger financial_approval_sync_expense
after insert
on public.financial_approvals
for each row
when (new.expense_transaction_id is not null)
execute function public.sync_expense_transaction_from_approval();


/* =========================================================
   5. VALIDATE APPROVAL RESULT
   ========================================================= */

create or replace function public.validate_financial_approval_result()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  transaction_status text;
begin

  /*
    Approval untuk pemasukan
  */

  if new.income_transaction_id is not null then

    select status::text
    into transaction_status
    from public.income_transactions
    where id = new.income_transaction_id;

    if transaction_status is null then
      raise exception
        'Transaksi pemasukan tidak ditemukan.';
    end if;


    if new.action = 'disetujui'
       and transaction_status <> 'disetujui' then

      raise exception
        'Status transaksi pemasukan gagal disinkronkan menjadi disetujui.';

    end if;


    if new.action = 'ditolak'
       and transaction_status <> 'ditolak' then

      raise exception
        'Status transaksi pemasukan gagal disinkronkan menjadi ditolak.';

    end if;

  end if;


  /*
    Approval untuk pengeluaran
  */

  if new.expense_transaction_id is not null then

    select status::text
    into transaction_status
    from public.expense_transactions
    where id = new.expense_transaction_id;

    if transaction_status is null then
      raise exception
        'Transaksi pengeluaran tidak ditemukan.';
    end if;


    if new.action = 'disetujui'
       and transaction_status <> 'disetujui' then

      raise exception
        'Status transaksi pengeluaran gagal disinkronkan menjadi disetujui.';

    end if;


    if new.action = 'ditolak'
       and transaction_status <> 'ditolak' then

      raise exception
        'Status transaksi pengeluaran gagal disinkronkan menjadi ditolak.';

    end if;

  end if;


  return new;

end;
$$;


/* =========================================================
   6. TRIGGER VALIDATE APPROVAL RESULT
   ========================================================= */

drop trigger if exists
  financial_approval_validate_result
on public.financial_approvals;

create trigger financial_approval_validate_result
after insert
on public.financial_approvals
for each row
execute function public.validate_financial_approval_result();


/* =========================================================
   7. APPEND-ONLY APPROVAL HISTORY
   ========================================================= */

create or replace function public.prevent_financial_approval_history_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  raise exception
    'Riwayat persetujuan keuangan bersifat permanen dan tidak dapat diubah atau dihapus.';

end;
$$;


/* =========================================================
   8. PREVENT UPDATE APPROVAL HISTORY
   ========================================================= */

drop trigger if exists
  financial_approvals_prevent_update
on public.financial_approvals;

create trigger financial_approvals_prevent_update
before update
on public.financial_approvals
for each row
execute function public.prevent_financial_approval_history_change();


/* =========================================================
   9. PREVENT DELETE APPROVAL HISTORY
   ========================================================= */

drop trigger if exists
  financial_approvals_prevent_delete
on public.financial_approvals;

create trigger financial_approvals_prevent_delete
before delete
on public.financial_approvals
for each row
execute function public.prevent_financial_approval_history_change();


/* =========================================================
   10. FUNCTION SECURITY
   ========================================================= */

revoke execute
on function public.sync_income_transaction_from_approval()
from public;

revoke execute
on function public.sync_income_transaction_from_approval()
from anon;

revoke execute
on function public.sync_income_transaction_from_approval()
from authenticated;


revoke execute
on function public.sync_expense_transaction_from_approval()
from public;

revoke execute
on function public.sync_expense_transaction_from_approval()
from anon;

revoke execute
on function public.sync_expense_transaction_from_approval()
from authenticated;


revoke execute
on function public.validate_financial_approval_result()
from public;

revoke execute
on function public.validate_financial_approval_result()
from anon;

revoke execute
on function public.validate_financial_approval_result()
from authenticated;


revoke execute
on function public.prevent_financial_approval_history_change()
from public;

revoke execute
on function public.prevent_financial_approval_history_change()
from anon;

revoke execute
on function public.prevent_financial_approval_history_change()
from authenticated;


/* =========================================================
   11. COMMENTS
   ========================================================= */

comment on table public.financial_approvals is
  'Riwayat permanen proses pengajuan, persetujuan, penolakan, dan pembatalan transaksi keuangan.';


comment on function public.sync_income_transaction_from_approval() is
  'Menyinkronkan action approval dengan status transaksi pemasukan.';


comment on function public.sync_expense_transaction_from_approval() is
  'Menyinkronkan action approval dengan status transaksi pengeluaran.';


/* =========================================================
   MIGRATION 057 SELESAI
   ========================================================= */