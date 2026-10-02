/*
  Migration 055
  Financial Approvals / Persetujuan Transaksi Keuangan

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan histori persetujuan transaksi keuangan.
  - Mendukung approval dan rejection.
  - Menyimpan user, waktu, tindakan, dan catatan.
  - Menghubungkan approval dengan transaksi pemasukan,
    pengeluaran, atau kas.
  - Menjadi dasar audit proses persetujuan.

  Keputusan bisnis:
  - Bendahara memiliki permission approve.
  - Kepala Sekolah dapat memiliki permission approve
    sesuai matriks hak akses.
  - Riwayat approval tidak boleh dihapus sembarangan.
*/


/* =========================================================
   1. ENUM JENIS APPROVAL
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'financial_approval_action'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.financial_approval_action as enum (
      'diajukan',
      'disetujui',
      'ditolak',
      'dibatalkan'
    );
  end if;
end
$$;


/* =========================================================
   2. TABLE FINANCIAL APPROVALS
   ========================================================= */

create table if not exists public.financial_approvals (
  id uuid primary key default gen_random_uuid(),

  approval_number text not null,

  income_transaction_id uuid
    references public.income_transactions(id)
    on delete restrict,

  expense_transaction_id uuid
    references public.expense_transactions(id)
    on delete restrict,

  cash_transaction_id uuid
    references public.cash_transactions(id)
    on delete restrict,

  action public.financial_approval_action not null,

  notes text,

  acted_by uuid not null
    references public.users(id)
    on delete restrict,

  acted_at timestamptz not null
    default now(),

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint financial_approvals_number_check
    check (
      length(trim(approval_number)) > 0
    ),

  constraint financial_approvals_transaction_check
    check (
      (
        income_transaction_id is not null
        and expense_transaction_id is null
        and cash_transaction_id is null
      )
      or
      (
        income_transaction_id is null
        and expense_transaction_id is not null
        and cash_transaction_id is null
      )
      or
      (
        income_transaction_id is null
        and expense_transaction_id is null
        and cash_transaction_id is not null
      )
    )
);


/* =========================================================
   3. UNIQUE APPROVAL NUMBER
   ========================================================= */

create unique index if not exists
  uq_financial_approvals_approval_number
on public.financial_approvals(approval_number);


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_financial_approvals_income
on public.financial_approvals(income_transaction_id);

create index if not exists
  idx_financial_approvals_expense
on public.financial_approvals(expense_transaction_id);

create index if not exists
  idx_financial_approvals_cash
on public.financial_approvals(cash_transaction_id);

create index if not exists
  idx_financial_approvals_action
on public.financial_approvals(action);

create index if not exists
  idx_financial_approvals_acted_by
on public.financial_approvals(acted_by);

create index if not exists
  idx_financial_approvals_acted_at
on public.financial_approvals(acted_at);


/* =========================================================
   5. VALIDATE APPROVAL ACTION
   ========================================================= */

create or replace function public.validate_financial_approval_action()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_status text;
begin

  /*
    Approval pemasukan.
  */

  if new.income_transaction_id is not null then

    select status::text
    into current_status
    from public.income_transactions
    where id = new.income_transaction_id;

    if current_status is null then
      raise exception
        'Transaksi pemasukan tidak ditemukan.';
    end if;

    if new.action = 'disetujui'
       and current_status <> 'menunggu_persetujuan' then

      raise exception
        'Transaksi pemasukan harus berada pada status menunggu_persetujuan untuk disetujui.';

    end if;

    if new.action = 'ditolak'
       and current_status <> 'menunggu_persetujuan' then

      raise exception
        'Transaksi pemasukan harus berada pada status menunggu_persetujuan untuk ditolak.';

    end if;

  end if;


  /*
    Approval pengeluaran.
  */

  if new.expense_transaction_id is not null then

    select status::text
    into current_status
    from public.expense_transactions
    where id = new.expense_transaction_id;

    if current_status is null then
      raise exception
        'Transaksi pengeluaran tidak ditemukan.';
    end if;

    if new.action = 'disetujui'
       and current_status <> 'menunggu_persetujuan' then

      raise exception
        'Transaksi pengeluaran harus berada pada status menunggu_persetujuan untuk disetujui.';

    end if;

    if new.action = 'ditolak'
       and current_status <> 'menunggu_persetujuan' then

      raise exception
        'Transaksi pengeluaran harus berada pada status menunggu_persetujuan untuk ditolak.';

    end if;

  end if;


  return new;
end;
$$;


/* =========================================================
   6. TRIGGER VALIDATE APPROVAL
   ========================================================= */

drop trigger if exists
  financial_approvals_validate_action
on public.financial_approvals;

create trigger financial_approvals_validate_action
before insert
on public.financial_approvals
for each row
execute function public.validate_financial_approval_action();


/* =========================================================
   7. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  financial_approvals_set_updated_at
on public.financial_approvals;

create trigger financial_approvals_set_updated_at
before update
on public.financial_approvals
for each row
execute function public.set_updated_at();


/* =========================================================
   8. ROW LEVEL SECURITY
   ========================================================= */

alter table public.financial_approvals
enable row level security;


/* =========================================================
   9. SELECT POLICY
   ========================================================= */

drop policy if exists
  financial_approvals_select
on public.financial_approvals;

create policy financial_approvals_select
on public.financial_approvals
for select
to authenticated
using (
  public.has_permission('keuangan', 'view')
);


/* =========================================================
   10. INSERT POLICY
   ========================================================= */

drop policy if exists
  financial_approvals_insert
on public.financial_approvals;

create policy financial_approvals_insert
on public.financial_approvals
for insert
to authenticated
with check (
  public.has_permission('keuangan', 'approve')
  and acted_by = auth.uid()
);


/* =========================================================
   11. UPDATE POLICY
   ========================================================= */

drop policy if exists
  financial_approvals_update
on public.financial_approvals;

create policy financial_approvals_update
on public.financial_approvals
for update
to authenticated
using (
  public.has_permission('keuangan', 'approve')
)
with check (
  public.has_permission('keuangan', 'approve')
);


/* =========================================================
   12. DELETE POLICY
   ========================================================= */

drop policy if exists
  financial_approvals_delete
on public.financial_approvals;

create policy financial_approvals_delete
on public.financial_approvals
for delete
to authenticated
using (
  public.is_super_admin()
);


/* =========================================================
   13. GRANTS
   ========================================================= */

grant select, insert, update
on public.financial_approvals
to authenticated;


/* =========================================================
   14. FUNCTION SECURITY
   ========================================================= */

revoke execute
on function public.validate_financial_approval_action()
from public;

revoke execute
on function public.validate_financial_approval_action()
from anon;

revoke execute
on function public.validate_financial_approval_action()
from authenticated;


/* =========================================================
   15. COMMENTS
   ========================================================= */

comment on table public.financial_approvals is
  'Riwayat proses persetujuan transaksi keuangan sekolah.';

comment on column public.financial_approvals.approval_number is
  'Nomor unik proses persetujuan.';

comment on column public.financial_approvals.income_transaction_id is
  'Transaksi pemasukan yang diproses.';

comment on column public.financial_approvals.expense_transaction_id is
  'Transaksi pengeluaran yang diproses.';

comment on column public.financial_approvals.cash_transaction_id is
  'Transaksi kas yang diproses.';

comment on column public.financial_approvals.action is
  'Tindakan approval: diajukan, disetujui, ditolak, atau dibatalkan.';

comment on column public.financial_approvals.notes is
  'Catatan dari pihak yang melakukan tindakan.';

comment on column public.financial_approvals.acted_by is
  'User yang melakukan tindakan persetujuan.';

comment on column public.financial_approvals.acted_at is
  'Waktu tindakan persetujuan dilakukan.';


/* =========================================================
   MIGRATION 055 SELESAI
   ========================================================= */