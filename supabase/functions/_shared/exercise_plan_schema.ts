import { z } from "npm:zod@^4.0.0";

/**
 * The per-exercise entry schema shared by every endpoint that asks the
 * model for a list of exercises against a closed slug list: `generate-plan`
 * (one array per workout day) and `adjust-workout` (one array for the whole
 * response). `exerciseSlug` is a closed enum of exactly the slugs the
 * client sent, so the model cannot reference an exercise outside that list
 * — the enum constrains generation itself, not just a downstream check.
 *
 * Bounds on sets/reps/rest are picked from real strength-training ranges,
 * not just "some positive number": they exist to catch a plausible-looking
 * but nonsensical generation (e.g. targetSets: 500) that a bare
 * `.positive()` would happily let through, rather than as a description of
 * the ideal program for any given goal — that nuance lives in each
 * endpoint's own SYSTEM_PROMPT, since a schema bound can only reject, not
 * steer.
 */
export function buildExercisesSchema(slugs: string[]) {
  if (slugs.length === 0) {
    throw new Error("slugs must be non-empty");
  }
  const [first, ...rest] = slugs;
  const exerciseSlug = z.enum([first, ...rest]);
  return z
    .array(
      z.object({
        exerciseSlug,
        targetSets: z.number().int().min(1).max(8),
        targetReps: z.number().int().min(1).max(50).nullable(),
        targetRestSeconds: z.number().int().min(10).max(600).nullable(),
        notes: z.string().nullable(),
      }),
    )
    .min(1)
    .max(12)
    // `uniqueItems` in JSON Schema checks whole-object equality, not one
    // field, so it can't express "no repeated exerciseSlug" (two entries
    // could legitimately share sets/reps but not the same exercise) — that
    // constraint only exists here, as a post-generation check.
    .superRefine((entries, ctx) => {
      const seen = new Set<string>();
      entries.forEach((entry, index) => {
        if (seen.has(entry.exerciseSlug)) {
          ctx.addIssue({
            code: "custom",
            message: `duplicate exerciseSlug "${entry.exerciseSlug}"`,
            path: [index, "exerciseSlug"],
          });
        }
        seen.add(entry.exerciseSlug);
      });
    });
}

/** The exercise-catalog entry shape every endpoint sends the model to pick
 * from (`slug`/`name`/`muscleGroup`/`equipment`) — shared so `generate-plan`
 * and `adjust-workout` describe their available exercises identically. */
export const CatalogExerciseSchema = z.object({
  slug: z.string().min(1),
  name: z.string().min(1),
  muscleGroup: z.string().min(1),
  equipment: z.string().nullable(),
});

export type CatalogExercise = z.infer<typeof CatalogExerciseSchema>;
