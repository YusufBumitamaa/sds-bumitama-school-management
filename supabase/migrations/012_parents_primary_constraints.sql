/*
  Migration 012
  Parents / Guardians - Primary Relationship Constraints

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Menjamin hanya ada satu orang tua/wali utama
    untuk setiap siswa pada setiap jenis hubungan.
*/


/* =========================================================
   1. UNIQUE PARTIAL INDEX
   ========================================================= */

/*
  Setiap siswa hanya boleh memiliki satu data primary
  untuk relationship yang sama.

  Contoh yang diperbolehkan:

  Siswa A
  ├── Ayah  - primary
  ├── Ibu   - primary
  └── Wali  - non-primary

  Tidak diperbolehkan:

  Siswa A
  ├── Ayah  - primary
  └── Ayah  - primary
*/

create unique index if not exists
  parents_one_primary_per_relationship_idx
on public.parents (
  student_id,
  relationship
)
where is_primary = true;


/* =========================================================
   2. INDEX UNTUK PENCARIAN RELASI SISWA
   ========================================================= */

create index if not exists
  parents_student_relationship_idx
on public.parents (
  student_id,
  relationship
);


/* =========================================================
   3. INDEX UNTUK ORANG TUA UTAMA
   ========================================================= */

create index if not exists
  parents_student_primary_idx
on public.parents (
  student_id
)
where is_primary = true;


/* =========================================================
   4. DOCUMENTATION
   ========================================================= */

comment on index
  public.parents_one_primary_per_relationship_idx
is
  'Menjamin hanya satu orang tua/wali utama untuk setiap siswa pada setiap jenis hubungan.';