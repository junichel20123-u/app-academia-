-- Public Storage bucket hosting pre-chosen stock exercise-demonstration
-- videos (one object per exercise slug: exercise-videos/<slug>.mp4),
-- uploaded via tools/exercise_videos/upload_to_supabase.py. Public reads
-- bypass RLS on storage.objects entirely, and writes only ever happen via
-- the service_role key (which also bypasses RLS) from that local script —
-- so no RLS policy is needed here, unlike the template_catalog tables.
insert into storage.buckets (id, name, public)
values ('exercise-videos', 'exercise-videos', true)
on conflict (id) do nothing;
