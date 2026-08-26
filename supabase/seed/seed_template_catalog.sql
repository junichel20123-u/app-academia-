-- Initial curated catalog (M17). Not a schema migration — this is one-time
-- data, meant to be pasted into the Supabase Studio SQL Editor (or run via
-- `supabase db execute -f supabase/seed/seed_template_catalog.sql`) against
-- the already-migrated project. Safe to re-run: each block skips itself if
-- the program's slug already exists.
--
-- Exercise slugs below match `slugify(name)` from the app's local seed
-- (lib/core/database/seed/seed_exercises.dart) exactly, so every exercise
-- resolves on a fresh install without any unresolved-slug warning.

do $$
declare
  v_program_id bigint;
  v_day0_id bigint;
  v_day1_id bigint;
  v_day2_id bigint;
begin
  if exists (select 1 from public.template_programs where slug = 'push-pull-legs') then
    return;
  end if;

  insert into public.template_programs (slug, name, description, goal, difficulty)
  values (
    'push-pull-legs',
    'Push Pull Legs',
    'Rotina clássica de 3 dias dividida por padrão de movimento.',
    'hypertrophy',
    'intermediate'
  )
  returning id into v_program_id;

  insert into public.template_program_workouts (program_id, day_index, name)
  values (v_program_id, 0, 'Push') returning id into v_day0_id;
  insert into public.template_program_workouts (program_id, day_index, name)
  values (v_program_id, 1, 'Pull') returning id into v_day1_id;
  insert into public.template_program_workouts (program_id, day_index, name)
  values (v_program_id, 2, 'Legs') returning id into v_day2_id;

  insert into public.template_program_workout_exercises
    (workout_id, exercise_slug, order_index, target_sets, target_reps, target_rest_seconds, notes)
  values
    (v_day0_id, 'supino-reto-com-barra', 0, 4, 8, 90, null),
    (v_day0_id, 'desenvolvimento-com-halteres', 1, 3, 10, 60, null),
    (v_day0_id, 'triceps-corda-no-cabo', 2, 3, 12, 60, null),
    (v_day1_id, 'puxada-frontal', 0, 4, 10, 90, null),
    (v_day1_id, 'remada-curvada-com-barra', 1, 4, 8, 90, null),
    (v_day1_id, 'rosca-direta-com-barra', 2, 3, 12, 60, null),
    (v_day2_id, 'agachamento-livre', 0, 4, 8, 120, null),
    (v_day2_id, 'leg-press', 1, 3, 12, 90, null),
    (v_day2_id, 'cadeira-extensora', 2, 3, 15, 60, null);
end $$;

do $$
declare
  v_program_id bigint;
  v_day0_id bigint;
  v_day1_id bigint;
begin
  if exists (select 1 from public.template_programs where slug = 'full-body-iniciante') then
    return;
  end if;

  insert into public.template_programs (slug, name, description, goal, difficulty)
  values (
    'full-body-iniciante',
    'Full body iniciante',
    'Dois treinos de corpo inteiro alternados, ideal para quem está começando.',
    'general_fitness',
    'beginner'
  )
  returning id into v_program_id;

  insert into public.template_program_workouts (program_id, day_index, name)
  values (v_program_id, 0, 'Treino A') returning id into v_day0_id;
  insert into public.template_program_workouts (program_id, day_index, name)
  values (v_program_id, 1, 'Treino B') returning id into v_day1_id;

  insert into public.template_program_workout_exercises
    (workout_id, exercise_slug, order_index, target_sets, target_reps, target_rest_seconds, notes)
  values
    (v_day0_id, 'agachamento-livre', 0, 3, 12, 90, null),
    (v_day0_id, 'flexao-de-braco', 1, 3, 10, 60, null),
    (v_day0_id, 'remada-curvada-com-barra', 2, 3, 10, 90, null),
    (v_day0_id, 'prancha-abdominal', 3, 3, null, 45, '30 segundos por série'),
    (v_day1_id, 'leg-press', 0, 3, 12, 90, null),
    (v_day1_id, 'puxada-frontal', 1, 3, 10, 90, null),
    (v_day1_id, 'desenvolvimento-com-halteres', 2, 3, 10, 60, null),
    (v_day1_id, 'abdominal-supra', 3, 3, 15, 45, null);
end $$;

do $$
declare
  v_program_id bigint;
  v_day0_id bigint;
  v_day1_id bigint;
begin
  if exists (select 1 from public.template_programs where slug = 'upper-lower') then
    return;
  end if;

  insert into public.template_programs (slug, name, description, goal, difficulty)
  values (
    'upper-lower',
    'Upper/Lower',
    'Divisão de 2 dias entre membros superiores e inferiores.',
    'hypertrophy',
    'intermediate'
  )
  returning id into v_program_id;

  insert into public.template_program_workouts (program_id, day_index, name)
  values (v_program_id, 0, 'Upper') returning id into v_day0_id;
  insert into public.template_program_workouts (program_id, day_index, name)
  values (v_program_id, 1, 'Lower') returning id into v_day1_id;

  insert into public.template_program_workout_exercises
    (workout_id, exercise_slug, order_index, target_sets, target_reps, target_rest_seconds, notes)
  values
    (v_day0_id, 'supino-reto-com-barra', 0, 4, 8, 90, null),
    (v_day0_id, 'remada-curvada-com-barra', 1, 4, 8, 90, null),
    (v_day0_id, 'desenvolvimento-com-halteres', 2, 3, 10, 60, null),
    (v_day0_id, 'rosca-direta-com-barra', 3, 3, 12, 60, null),
    (v_day0_id, 'triceps-corda-no-cabo', 4, 3, 12, 60, null),
    (v_day1_id, 'agachamento-livre', 0, 4, 8, 120, null),
    (v_day1_id, 'leg-press', 1, 3, 12, 90, null),
    (v_day1_id, 'cadeira-flexora', 2, 3, 12, 60, null),
    (v_day1_id, 'afundo-com-halteres', 3, 3, 12, 60, null);
end $$;
