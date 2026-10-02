/*
  Migration 023
  Lesson Schedule Conflict Validation

  Sumber acuan:
  - PRD v4.0
  - Master Technical Blueprint v1.0
  - Database Blueprint v1.0

  Aturan:
  1. Guru tidak boleh memiliki jadwal yang bertabrakan.
  2. Kelas tidak boleh memiliki jadwal yang bertabrakan.
  3. Ruangan tidak boleh memiliki jadwal yang bertabrakan.
  4. Hanya jadwal aktif yang diperiksa.
  5. Konflik hanya diperiksa dalam tahun ajaran yang sama.
  6. Konflik waktu menggunakan interval:
       start_time < existing_end_time
       AND end_time > existing_start_time
     
     Sehingga:
       07:00 - 08:00
       08:00 - 09:00
     
     tidak dianggap konflik.
*/


/* =========================================================
   1. CONFLICT VALIDATION FUNCTION
   ========================================================= */

create or replace function public.validate_lesson_schedule_conflict()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  conflicting_class_name text;
  conflicting_teacher_name text;
  conflicting_room_name text;
begin

  /*
    Hanya jadwal aktif yang perlu diperiksa.
  */
  if new.is_active = false then
    return new;
  end if;


  /*
    ========================================================
    1. VALIDASI KONFLIK KELAS
    ========================================================
  */

  select c.name
  into conflicting_class_name
  from public.lesson_schedules ls
  left join public.classes c
    on c.id = ls.class_id
  where ls.id <> new.id
    and ls.is_active = true
    and ls.academic_year_id = new.academic_year_id
    and ls.class_id = new.class_id
    and ls.day_of_week = new.day_of_week
    and new.start_time < ls.end_time
    and new.end_time > ls.start_time
  limit 1;

  if conflicting_class_name is not null then
    raise exception
      using
        errcode = '23514',
        message = format(
          'Jadwal bentrok: kelas "%s" sudah memiliki jadwal pada hari %s pukul %s-%s.',
          conflicting_class_name,
          new.day_of_week,
          new.start_time,
          new.end_time
        ),
        detail = 'Satu kelas tidak dapat memiliki dua jadwal aktif pada waktu yang bertabrakan.';
  end if;


  /*
    ========================================================
    2. VALIDASI KONFLIK GURU
    ========================================================
  */

  select ts.full_name
  into conflicting_teacher_name
  from public.lesson_schedules ls
  left join public.teachers_staff ts
    on ts.id = ls.teacher_id
  where ls.id <> new.id
    and ls.is_active = true
    and ls.academic_year_id = new.academic_year_id
    and ls.teacher_id = new.teacher_id
    and ls.day_of_week = new.day_of_week
    and new.start_time < ls.end_time
    and new.end_time > ls.start_time
  limit 1;

  if conflicting_teacher_name is not null then
    raise exception
      using
        errcode = '23514',
        message = format(
          'Jadwal bentrok: guru "%s" sudah memiliki jadwal pada hari %s pukul %s-%s.',
          conflicting_teacher_name,
          new.day_of_week,
          new.start_time,
          new.end_time
        ),
        detail = 'Satu guru tidak dapat mengajar dua kelas pada waktu yang bertabrakan.';
  end if;


  /*
    ========================================================
    3. VALIDASI KONFLIK RUANGAN
    ========================================================
    
    Ruangan boleh kosong karena tidak semua jadwal
    harus memiliki ruangan tertentu.
  */

  if new.room_id is not null then

    select r.name
    into conflicting_room_name
    from public.lesson_schedules ls
    left join public.rooms r
      on r.id = ls.room_id
    where ls.id <> new.id
      and ls.is_active = true
      and ls.academic_year_id = new.academic_year_id
      and ls.room_id = new.room_id
      and ls.day_of_week = new.day_of_week
      and new.start_time < ls.end_time
      and new.end_time > ls.start_time
    limit 1;

    if conflicting_room_name is not null then
      raise exception
        using
          errcode = '23514',
          message = format(
            'Jadwal bentrok: ruangan "%s" sudah digunakan pada hari %s pukul %s-%s.',
            conflicting_room_name,
            new.day_of_week,
            new.start_time,
            new.end_time
          ),
          detail = 'Satu ruangan tidak dapat digunakan oleh dua jadwal pada waktu yang bertabrakan.';
    end if;

  end if;


  /*
    Jika seluruh validasi lolos,
    data dapat disimpan.
  */

  return new;
end;
$$;


/* =========================================================
   2. TRIGGER
   ========================================================= */

drop trigger if exists
  lesson_schedules_validate_conflict
on public.lesson_schedules;

create trigger lesson_schedules_validate_conflict
before insert or update
on public.lesson_schedules
for each row
execute function public.validate_lesson_schedule_conflict();


/* =========================================================
   3. FUNCTION COMMENT
   ========================================================= */

comment on function public.validate_lesson_schedule_conflict()
is
  'Memvalidasi konflik jadwal berdasarkan tahun ajaran, kelas, guru, ruangan, hari, dan interval waktu.';


/* =========================================================
   4. GRANT
   ========================================================= */

grant execute
on function public.validate_lesson_schedule_conflict()
to authenticated;