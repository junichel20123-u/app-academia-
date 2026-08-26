-- Workout template catalog: curated, server-updatable workout programs.
-- Exercises are referenced by the client's local `slug` (see the app's M10
-- migration), never by a local database id, since those ids are
-- per-install autoincrement values with no meaning outside one device.

create table if not exists public.template_programs (
  id bigint generated always as identity primary key,
  slug text not null unique,
  name text not null,
  description text,
  goal text,
  difficulty text,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.template_program_workouts (
  id bigint generated always as identity primary key,
  program_id bigint not null
    references public.template_programs (id) on delete cascade,
  day_index int not null,
  name text not null,
  unique (program_id, day_index)
);

create table if not exists public.template_program_workout_exercises (
  id bigint generated always as identity primary key,
  workout_id bigint not null
    references public.template_program_workouts (id) on delete cascade,
  exercise_slug text not null,
  order_index int not null,
  target_sets int not null,
  target_reps int,
  target_rest_seconds int,
  notes text,
  unique (workout_id, order_index)
);

-- Read-only for everyone holding the publishable/anon key. There is
-- deliberately no insert/update/delete policy for anon or authenticated on
-- any of these three tables — only the service_role key (which bypasses
-- RLS entirely and is never embedded in the app) can write to the catalog.
alter table public.template_programs enable row level security;
alter table public.template_program_workouts enable row level security;
alter table public.template_program_workout_exercises enable row level security;

create policy "template_programs are publicly readable"
  on public.template_programs for select
  using (true);

create policy "template_program_workouts are publicly readable"
  on public.template_program_workouts for select
  using (true);

create policy "template_program_workout_exercises are publicly readable"
  on public.template_program_workout_exercises for select
  using (true);

-- Bumps template_programs.updated_at whenever a child workout or exercise
-- row changes, so the client's incremental-sync cursor (M12/M14) stays
-- accurate without the client needing to walk the whole tree on every sync.
create or replace function public.touch_template_program_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_program_id bigint;
begin
  if tg_table_name = 'template_program_workouts' then
    v_program_id := coalesce(new.program_id, old.program_id);
  elsif tg_table_name = 'template_program_workout_exercises' then
    select w.program_id into v_program_id
    from public.template_program_workouts w
    where w.id = coalesce(new.workout_id, old.workout_id);
  end if;

  if v_program_id is not null then
    update public.template_programs
      set updated_at = now()
      where id = v_program_id;
  end if;

  return coalesce(new, old);
end;
$$;

create trigger touch_program_on_workout_change
  after insert or update or delete on public.template_program_workouts
  for each row execute function public.touch_template_program_updated_at();

create trigger touch_program_on_exercise_change
  after insert or update or delete on public.template_program_workout_exercises
  for each row execute function public.touch_template_program_updated_at();
