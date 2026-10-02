/*
  Migration 042
  Outgoing Letters / Surat Keluar

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan administrasi surat keluar sekolah.
  - Menyimpan nomor surat, tujuan, perihal,
    penandatangan, dan dokumen surat.
*/


/* =========================================================
   1. ENUM STATUS SURAT KELUAR
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'outgoing_letter_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.outgoing_letter_status as enum (
      'draft',
      'diajukan',
      'disetujui',
      'ditandatangani',
      'dikirim',
      'diarsipkan',
      'dibatalkan'
    );

  end if;
end
$$;


/* =========================================================
   2. TABLE OUTGOING LETTERS
   ========================================================= */

create table if not exists public.outgoing_letters (
  id uuid primary key default gen_random_uuid(),

  agenda_number text,

  letter_number text,

  letter_date date,

  recipient_name text not null,

  recipient_organization text,

  recipient_address text,

  recipient_phone text,

  subject text not null,

  letter_nature public.letter_nature not null
    default 'biasa',

  attachment_description text,

  signer_name text,

  signer_position text,

  signer_nip text,

  status public.outgoing_letter_status not null
    default 'draft',

  sent_date date,

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

  constraint outgoing_letter_recipient_check
    check (
      length(trim(recipient_name)) > 0
    ),

  constraint outgoing_letter_subject_check
    check (
      length(trim(subject)) > 0
    ),

  constraint outgoing_letter_date_check
    check (
      sent_date is null
      or letter_date is null
      or sent_date >= letter_date
    ),

  constraint outgoing_letter_approval_check
    check (
      status not in (
        'disetujui',
        'ditandatangani',
        'dikirim',
        'diarsipkan'
      )
      or approved_at is not null
    )
);


/* =========================================================
   3. UNIQUE LETTER NUMBER
   ========================================================= */

create unique index if not exists
  uq_outgoing_letters_letter_number
on public.outgoing_letters(letter_number)
where letter_number is not null
  and length(trim(letter_number)) > 0;


/* =========================================================
   4. INDEXES
   ========================================================= */

create index if not exists
  idx_outgoing_letters_letter_date
on public.outgoing_letters(letter_date);

create index if not exists
  idx_outgoing_letters_recipient
on public.outgoing_letters(recipient_name);

create index if not exists
  idx_outgoing_letters_subject
on public.outgoing_letters(subject);

create index if not exists
  idx_outgoing_letters_status
on public.outgoing_letters(status);

create index if not exists
  idx_outgoing_letters_created_by
on public.outgoing_letters(created_by);

create index if not exists
  idx_outgoing_letters_approved_by
on public.outgoing_letters(approved_by);


/* =========================================================
   5. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  outgoing_letters_set_updated_at
on public.outgoing_letters;

create trigger outgoing_letters_set_updated_at
before update
on public.outgoing_letters
for each row
execute function public.set_updated_at();


/* =========================================================
   6. ROW LEVEL SECURITY
   ========================================================= */

alter table public.outgoing_letters
enable row level security;


/* =========================================================
   7. SELECT POLICY
   ========================================================= */

drop policy if exists
  outgoing_letters_select
on public.outgoing_letters;

create policy outgoing_letters_select
on public.outgoing_letters
for select
to authenticated
using (
  public.has_permission('persuratan', 'view')
);


/* =========================================================
   8. INSERT POLICY
   ========================================================= */

drop policy if exists
  outgoing_letters_insert
on public.outgoing_letters;

create policy outgoing_letters_insert
on public.outgoing_letters
for insert
to authenticated
with check (
  public.has_permission('persuratan', 'create')
);


/* =========================================================
   9. UPDATE POLICY
   ========================================================= */

drop policy if exists
  outgoing_letters_update
on public.outgoing_letters;

create policy outgoing_letters_update
on public.outgoing_letters
for update
to authenticated
using (
  public.has_permission('persuratan', 'update')
)
with check (
  public.has_permission('persuratan', 'update')
);


/* =========================================================
   10. DELETE POLICY
   ========================================================= */

drop policy if exists
  outgoing_letters_delete
on public.outgoing_letters;

create policy outgoing_letters_delete
on public.outgoing_letters
for delete
to authenticated
using (
  public.has_permission('persuratan', 'delete')
);


/* =========================================================
   11. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.outgoing_letters
to authenticated;


/* =========================================================
   12. COMMENTS
   ========================================================= */

comment on table public.outgoing_letters is
  'Administrasi surat keluar sekolah.';

comment on column public.outgoing_letters.agenda_number is
  'Nomor agenda surat keluar jika digunakan.';

comment on column public.outgoing_letters.letter_number is
  'Nomor resmi surat keluar.';

comment on column public.outgoing_letters.letter_date is
  'Tanggal surat.';

comment on column public.outgoing_letters.recipient_name is
  'Nama penerima surat.';

comment on column public.outgoing_letters.recipient_organization is
  'Instansi atau organisasi penerima.';

comment on column public.outgoing_letters.recipient_address is
  'Alamat penerima surat.';

comment on column public.outgoing_letters.subject is
  'Perihal surat.';

comment on column public.outgoing_letters.letter_nature is
  'Sifat surat.';

comment on column public.outgoing_letters.signer_name is
  'Nama pejabat yang menandatangani surat.';

comment on column public.outgoing_letters.signer_position is
  'Jabatan penandatangan surat.';

comment on column public.outgoing_letters.signer_nip is
  'NIP penandatangan jika tersedia.';

comment on column public.outgoing_letters.sent_date is
  'Tanggal surat dikirim.';

comment on column public.outgoing_letters.document_url is
  'Lokasi file surat pada storage/digital archive.';

comment on column public.outgoing_letters.approved_by is
  'User yang memberikan persetujuan surat.';

comment on column public.outgoing_letters.approved_at is
  'Waktu persetujuan surat.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */