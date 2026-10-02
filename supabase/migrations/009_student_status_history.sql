/*
  Migration 009
  Riwayat Status Siswa

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Aturan:
  - students.status adalah status terkini siswa.
  - Setiap perubahan status harus dapat dilacak.
  - Riwayat tidak boleh dihapus secara normal.
  - Status:
      aktif
      lulus
      pindah
      keluar
*/


/* =========================================================
   1. TABEL RIWAYAT STATUS SISWA
   ========================================================= */

create table public.student_status_history (
  id uuid primary key default gen_random_uuid(),

  student_id uuid not null
    references public.students(id)
    on delete restrict,

  /*
    Status sebelum perubahan.
    NULL diperbolehkan untuk pencatatan status awal.
  */
  previous_status public.student_status,

  /*
    Status setelah perubahan.
  */
  new_status public.student_status not null,

  /*
    Waktu perubahan status.
  */
  changed_at timestamptz not null default now(),

  /*
    User yang melakukan perubahan.
  */
  changed_by uuid
    references public.users(id)
    on delete set null,

  /*
    Alasan perubahan status.
  */
  reason text,

  /*
    Referensi tambahan, misalnya nomor dokumen
    atau keterangan administratif.
  */
  notes text,

  created_at timestamptz not null default now()
);

comment on table public.student_status_history is
  'Riwayat perubahan status siswa.';

comment on column public.student_status_history.student_id is
  'Siswa yang mengalami perubahan status.';

comment on column public.student_status_history.previous_status is
  'Status siswa sebelum perubahan.';

comment on column public.student_status_history.new_status is
  'Status siswa setelah perubahan.';

comment on column public.student_status_history.changed_by is
  'Pengguna yang melakukan perubahan status.';

comment on column public.student_status_history.reason is
  'Alasan perubahan status siswa.';


/* =========================================================
   2. INDEX
   ========================================================= */

create index student_status_history_student_idx
  on public.student_status_history(student_id);

create index student_status_history_changed_at_idx
  on public.student_status_history(changed_at);

create index student_status_history_new_status_idx
  on public.student_status_history(new_status);

create index student_status_history_changed_by_idx
  on public.student_status_history(changed_by);


/* =========================================================
   3. ROW LEVEL SECURITY
   ========================================================= */

alter table public.student_status_history
enable row level security;


/*
  Melihat histori membutuhkan akses view Kesiswaan.
*/

create policy student_status_history_select_with_permission
on public.student_status_history
for select
to authenticated
using (
  public.has_permission(
    'kesiswaan',
    'view'
  )
);


/*
  Membuat histori membutuhkan akses update Kesiswaan,
  karena histori dibuat ketika status siswa diubah.
*/

create policy student_status_history_insert_with_permission
on public.student_status_history
for insert
to authenticated
with check (
  public.has_permission(
    'kesiswaan',
    'update'
  )
);


/*
  Histori status tidak boleh diedit.
  Tidak dibuat policy UPDATE.
*/


/*
  Histori status tidak boleh dihapus
  melalui aplikasi.
  Tidak dibuat policy DELETE.
*/


/* =========================================================
   4. PRIVILEGE
   ========================================================= */

grant select
on table public.student_status_history
to authenticated;

grant insert
on table public.student_status_history
to authenticated;