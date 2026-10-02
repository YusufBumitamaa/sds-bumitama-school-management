/*
  Migration 056
  Financial Account Balance Integration

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Mengintegrasikan ledger cash_transactions
    dengan financial_accounts.current_balance.
  - Saldo rekening berubah hanya untuk transaksi
    kas berstatus 'tercatat'.
  - Menjaga saldo tetap konsisten ketika transaksi
    ditambahkan, diubah, atau dibatalkan.
  - Menyediakan fungsi rekalkulasi saldo untuk
    sinkronisasi dan pemeriksaan integritas.

  Prinsip:
  - Draft tidak memengaruhi saldo.
  - Transaksi tercatat memengaruhi saldo.
  - Transaksi dibatalkan tidak memengaruhi saldo.
  - Perubahan transaksi tercatat harus mengoreksi
    saldo sebelumnya sebelum menerapkan saldo baru.
*/


/* =========================================================
   1. VALIDATE ACCOUNT BALANCE
   ========================================================= */

create or replace function public.validate_financial_account_balance()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin

  if new.opening_balance < 0 then
    raise exception
      'Saldo awal rekening tidak boleh negatif.';
  end if;

  if new.current_balance < 0 then
    raise exception
      'Saldo rekening tidak boleh negatif.';
  end if;

  return new;

end;
$$;


/* =========================================================
   2. TRIGGER VALIDATE ACCOUNT BALANCE
   ========================================================= */

drop trigger if exists
  financial_accounts_validate_balance
on public.financial_accounts;

create trigger financial_accounts_validate_balance
before insert or update of opening_balance, current_balance
on public.financial_accounts
for each row
execute function public.validate_financial_account_balance();


/* =========================================================
   3. APPLY CASH TRANSACTION TO ACCOUNT BALANCE
   ========================================================= */

create or replace function public.apply_cash_transaction_to_account_balance()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  old_effect numeric(18,2) := 0;
  new_effect numeric(18,2) := 0;
  calculated_balance numeric(18,2);
begin

  /*
    ---------------------------------------------------------
    A. HAPUS TRANSAKSI
    ---------------------------------------------------------
  */

  if tg_op = 'DELETE' then

    if old.status = 'tercatat' then

      if old.transaction_type in (
        'pemasukan',
        'transfer_masuk',
        'penyesuaian'
      ) then

        old_effect := old.amount;

      elsif old.transaction_type in (
        'pengeluaran',
        'transfer_keluar'
      ) then

        old_effect := old.amount * -1;

      end if;


      update public.financial_accounts
      set current_balance = current_balance - old_effect,
          updated_at = now()
      where id = old.account_id;

    end if;

    return old;

  end if;


  /*
    ---------------------------------------------------------
    B. HITUNG EFEK TRANSAKSI LAMA
    ---------------------------------------------------------
  */

  if tg_op = 'UPDATE'
     and old.status = 'tercatat' then

    if old.transaction_type in (
      'pemasukan',
      'transfer_masuk',
      'penyesuaian'
    ) then

      old_effect := old.amount;

    elsif old.transaction_type in (
      'pengeluaran',
      'transfer_keluar'
    ) then

      old_effect := old.amount * -1;

    end if;


    /*
      Kembalikan saldo rekening lama
      sebelum menerapkan transaksi baru.
    */

    update public.financial_accounts
    set current_balance = current_balance - old_effect,
        updated_at = now()
    where id = old.account_id;

  end if;


  /*
    ---------------------------------------------------------
    C. HITUNG EFEK TRANSAKSI BARU
    ---------------------------------------------------------
  */

  if new.status = 'tercatat' then

    if new.transaction_type in (
      'pemasukan',
      'transfer_masuk',
      'penyesuaian'
    ) then

      new_effect := new.amount;

    elsif new.transaction_type in (
      'pengeluaran',
      'transfer_keluar'
    ) then

      new_effect := new.amount * -1;

    end if;


    /*
      Pastikan rekening masih tersedia.
    */

    select current_balance
    into calculated_balance
    from public.financial_accounts
    where id = new.account_id
    for update;


    if calculated_balance is null then
      raise exception
        'Rekening keuangan tidak ditemukan.';
    end if;


    /*
      Terapkan transaksi baru.
    */

    if calculated_balance + new_effect < 0 then
      raise exception
        'Saldo rekening tidak mencukupi untuk transaksi kas.';
    end if;


    update public.financial_accounts
    set current_balance = current_balance + new_effect,
        updated_at = now()
    where id = new.account_id;

  end if;


  return new;

end;
$$;


/* =========================================================
   4. TRIGGER APPLY BALANCE
   ========================================================= */

drop trigger if exists
  cash_transactions_apply_account_balance
on public.cash_transactions;

create trigger cash_transactions_apply_account_balance
after insert or update or delete
on public.cash_transactions
for each row
execute function public.apply_cash_transaction_to_account_balance();


/* =========================================================
   5. REBUILD ACCOUNT BALANCE FUNCTION
   ========================================================= */

create or replace function public.rebuild_financial_account_balance(
  target_account_id uuid
)
returns numeric
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  account_opening_balance numeric(18,2);
  calculated_balance numeric(18,2);
begin

  /*
    Ambil saldo awal rekening.
  */

  select opening_balance
  into account_opening_balance
  from public.financial_accounts
  where id = target_account_id
  for update;


  if account_opening_balance is null then
    raise exception
      'Rekening keuangan tidak ditemukan.';
  end if;


  /*
    Hitung ulang berdasarkan seluruh
    transaksi kas yang telah tercatat.
  */

  select
    account_opening_balance
    +
    coalesce(
      sum(
        case

          when transaction_type in (
            'pemasukan',
            'transfer_masuk',
            'penyesuaian'
          )
          then amount

          when transaction_type in (
            'pengeluaran',
            'transfer_keluar'
          )
          then -amount

          else 0

        end
      ),
      0
    )
  into calculated_balance
  from public.cash_transactions
  where account_id = target_account_id
    and status = 'tercatat';


  if calculated_balance < 0 then
    raise exception
      'Hasil rekalkulasi saldo rekening tidak boleh negatif.';
  end if;


  /*
    Simpan saldo hasil rekalkulasi.
  */

  update public.financial_accounts
  set current_balance = calculated_balance,
      updated_at = now()
  where id = target_account_id;


  return calculated_balance;

end;
$$;


/* =========================================================
   6. REBUILD ALL ACCOUNT BALANCES
   ========================================================= */

create or replace function public.rebuild_all_financial_account_balances()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  account_record record;
begin

  for account_record in
    select id
    from public.financial_accounts
  loop

    perform public.rebuild_financial_account_balance(
      account_record.id
    );

  end loop;

end;
$$;


/* =========================================================
   7. FUNCTION SECURITY
   ========================================================= */

revoke execute
on function public.validate_financial_account_balance()
from public;

revoke execute
on function public.validate_financial_account_balance()
from anon;

revoke execute
on function public.validate_financial_account_balance()
from authenticated;


revoke execute
on function public.apply_cash_transaction_to_account_balance()
from public;

revoke execute
on function public.apply_cash_transaction_to_account_balance()
from anon;

revoke execute
on function public.apply_cash_transaction_to_account_balance()
from authenticated;


revoke execute
on function public.rebuild_financial_account_balance(uuid)
from public;

revoke execute
on function public.rebuild_financial_account_balance(uuid)
from anon;

revoke execute
on function public.rebuild_financial_account_balance(uuid)
from authenticated;


revoke execute
on function public.rebuild_all_financial_account_balances()
from public;

revoke execute
on function public.rebuild_all_financial_account_balances()
from anon;

revoke execute
on function public.rebuild_all_financial_account_balances()
from authenticated;


/* =========================================================
   8. COMMENTS
   ========================================================= */

comment on function public.rebuild_financial_account_balance(uuid) is
  'Menghitung ulang saldo rekening berdasarkan saldo awal dan seluruh transaksi kas yang telah tercatat.';

comment on function public.rebuild_all_financial_account_balances() is
  'Menghitung ulang saldo seluruh rekening keuangan sekolah.';


/* =========================================================
   MIGRATION 056 SELESAI
   ========================================================= */