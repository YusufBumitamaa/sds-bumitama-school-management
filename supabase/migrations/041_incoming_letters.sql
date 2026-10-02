/*
  Migration 041
  Incoming Letters / Surat Masuk

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menyimpan administrasi surat masuk sekolah.
  - Menyimpan informasi pengirim, nomor, tanggal,
    perihal, disposisi, dan dokumen surat.
*/


/* =========================================================
   1. ENUM SIFAT SURAT
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'letter_nature'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.letter_nature as enum (
      'biasa',
      'penting',
      'segera',
      'rahasia'
    );

  end if;
end
$$;


/* =========================================================
   2. ENUM STATUS SURAT MASUK
   ========================================================= */

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'incoming_letter_status'
      and typnamespace = 'public'::regnamespace
  ) then

    create type public.incoming_letter_status as enum (
      'diterima',
      'didisposisi',
      'ditindaklanjuti',
      'selesai',
      'diarsipkan'
    );

  end if;
end
$$;


/* =========================================================
   3. TABLE INCOMING LETTERS
   ========================================================= */

create table if not exists public.incoming_letters (
  id uuid primary key default gen_random_uuid(),

  agenda_number text not null,

  letter_number text,

  letter_date date,

  received_date date not null
    default current_date,

  sender_name text not null,

  sender_organization text,

  sender_address text,

  sender_phone text,

  subject text not null,

  letter_nature public.letter_nature not null
    default 'biasa',

  attachment_description text,

  disposition text,

  disposition_date date,

  disposition_to text,

  follow_up text,

  status public.incoming_letter_status not null
    default 'diterima',

  document_url text,

  notes text,

  recorded_by uuid
    references public.users(id)
    on delete set null,

  created_at timestamptz not null
    default now(),

  updated_at timestamptz not null
    default now(),

  constraint incoming_letter_agenda_number_check
    check (
      length(trim(agenda_number)) > 0
    ),

  constraint incoming_letter_sender_check
    check (
      length(trim(sender_name)) > 0
    ),

  constraint incoming_letter_subject_check
    check (
      length(trim(subject)) > 0
    ),

  constraint incoming_letter_date_check
    check (
      letter_date is null
      or letter_date <= received_date
    ),

  constraint incoming_letter_disposition_date_check
    check (
      disposition_date is null
      or disposition_date >= received_date
    )
);


/* =========================================================
   4. UNIQUE AGENDA NUMBER
   ========================================================= */

create unique index if not exists
  uq_incoming_letters_agenda_number
on public.incoming_letters(agenda_number);


/* =========================================================
   5. INDEXES
   ========================================================= */

create index if not exists
  idx_incoming_letters_received_date
on public.incoming_letters(received_date);

create index if not exists
  idx_incoming_letters_letter_date
on public.incoming_letters(letter_date);

create index if not exists
  idx_incoming_letters_sender
on public.incoming_letters(sender_name);

create index if not exists
  idx_incoming_letters_subject
on public.incoming_letters(subject);

create index if not exists
  idx_incoming_letters_nature
on public.incoming_letters(letter_nature);

create index if not exists
  idx_incoming_letters_status
on public.incoming_letters(status);

create index if not exists
  idx_incoming_letters_recorded_by
on public.incoming_letters(recorded_by);


/* =========================================================
   6. UPDATED_AT TRIGGER
   ========================================================= */

drop trigger if exists
  incoming_letters_set_updated_at
on public.incoming_letters;

create trigger incoming_letters_set_updated_at
before update
on public.incoming_letters
for each row
execute function public.set_updated_at();


/* =========================================================
   7. ROW LEVEL SECURITY
   ========================================================= */

alter table public.incoming_letters
enable row level security;


/* =========================================================
   8. SELECT POLICY
   ========================================================= */

drop policy if exists
  incoming_letters_select
on public.incoming_letters;

create policy incoming_letters_select
on public.incoming_letters
for select
to authenticated
using (
  public.has_permission('persuratan', 'view')
);


/* =========================================================
   9. INSERT POLICY
   ========================================================= */

drop policy if exists
  incoming_letters_insert
on public.incoming_letters;

create policy incoming_letters_insert
on public.incoming_letters
for insert
to authenticated
with check (
  public.has_permission('persuratan', 'create')
);


/* =========================================================
   10. UPDATE POLICY
   ========================================================= */

drop policy if exists
  incoming_letters_update
on public.incoming_letters;

create policy incoming_letters_update
on public.incoming_letters
for update
to authenticated
using (
  public.has_permission('persuratan', 'update')
)
with check (
  public.has_permission('persuratan', 'update')
);


/* =========================================================
   11. DELETE POLICY
   ========================================================= */

drop policy if exists
  incoming_letters_delete
on public.incoming_letters;

create policy incoming_letters_delete
on public.incoming_letters
for delete
to authenticated
using (
  public.has_permission('persuratan', 'delete')
);


/* =========================================================
   12. GRANTS
   ========================================================= */

grant select, insert, update, delete
on public.incoming_letters
to authenticated;


/* =========================================================
   13. COMMENTS
   ========================================================= */

comment on table public.incoming_letters is
  'Administrasi surat masuk sekolah.';

comment on column public.incoming_letters.agenda_number is
  'Nomor agenda surat masuk.';

comment on column public.incoming_letters.letter_number is
  'Nomor surat dari pihak pengirim.';

comment on column public.incoming_letters.letter_date is
  'Tanggal yang tercantum pada surat.';

comment on column public.incoming_letters.received_date is
  'Tanggal surat diterima sekolah.';

comment on column public.incoming_letters.sender_name is
  'Nama pengirim surat.';

comment on column public.incoming_letters.sender_organization is
  'Instansi atau organisasi pengirim.';

comment on column public.incoming_letters.subject is
  'Perihal surat.';

comment on column public.incoming_letters.letter_nature is
  'Sifat surat.';

comment on column public.incoming_letters.disposition is
  'Isi atau arahan disposisi surat.';

comment on column public.incoming_letters.disposition_to is
  'Pihak yang menerima disposisi.';

comment on column public.incoming_letters.follow_up is
  'Tindak lanjut atas surat.';

comment on column public.incoming_letters.document_url is
  'Lokasi file surat pada storage/digital archive.';

comment on column public.incoming_letters.recorded_by is
  'User yang mencatat surat masuk.';


/* =========================================================
   MIGRATION SELESAI
   ========================================================= */