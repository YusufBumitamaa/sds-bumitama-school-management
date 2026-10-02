/*
  Migration 010
  Automatic Student Status History Trigger

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Fungsi:
  - Mencatat perubahan students.status secara otomatis.
  - Menghindari ketergantungan pada UI untuk membuat histori.
  - Menyimpan user yang melakukan perubahan melalui auth.uid().
*/


/* =========================================================
   1. FUNCTION
   ========================================================= */

create or replace function public.record_student_status_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  /*
    Hanya mencatat apabila status benar-benar berubah.
  */
  if old.status is distinct from new.status then

    insert into public.student_status_history (
      student_id,
      previous_status,
      new_status,
      changed_at,
      changed_by
    )
    values (
      new.id,
      old.status,
      new.status,
      now(),
      auth.uid()
    );

  end if;

  return new;
end;
$$;


/* =========================================================
   2. TRIGGER
   ========================================================= */

drop trigger if exists
  students_record_status_change
on public.students;


create trigger students_record_status_change
after update of status
on public.students
for each row
when (
  old.status is distinct from new.status
)
execute function public.record_student_status_change();


/* =========================================================
   3. FUNCTION SECURITY
   ========================================================= */

/*
  Function hanya digunakan oleh trigger.
  Tidak perlu diberikan EXECUTE kepada pengguna biasa.
*/

revoke execute
on function public.record_student_status_change()
from public;

revoke execute
on function public.record_student_status_change()
from anon;

revoke execute
on function public.record_student_status_change()
from authenticated;