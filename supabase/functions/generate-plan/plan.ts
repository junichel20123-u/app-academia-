import { z } from "npm:zod@^4.0.0";

export const RequestSchema = z.object({
  goal: z.string().min(1),
  daysPerWeek: z.number().int().min(1).max(7),
  experienceLevel: z.string().min(1),
  availableEquipment: z.array(z.string()),
  exercises: z
    .array(
      z.object({
        slug: z.string().min(1),
        name: z.string().min(1),
        muscleGroup: z.string().min(1),
        equipment: z.string().nullable(),
      }),
    )
    .min(1),
});

export type GeneratePlanRequest = z.infer<typeof RequestSchema>;

/**
 * Builds the structured-output schema for one request: `workouts.length` is
 * locked to the requested `daysPerWeek`, and `exerciseSlug` is a closed enum
 * of exactly the slugs the client sent. The model cannot reference an
 * exercise outside that list because the enum constrains generation itself,
 * not just a downstream check on the response. Serves double duty: fed to
 * the provider as the required response shape (via `buildPlanJsonSchema`
 * below) *and* used again client-side to validate whatever comes back
 * (`TextGenerationProvider.generateStructured` returns raw `unknown` —
 * providers don't share a validation story, only a JSON Schema request
 * shape, so this Zod schema is the one place both sides agree on).
 */
export function buildPlanSchema(daysPerWeek: number, slugs: string[]) {
  if (slugs.length === 0) {
    throw new Error("slugs must be non-empty");
  }
  const [first, ...rest] = slugs;
  const exerciseSlug = z.enum([first, ...rest]);
  // Bounds picked from real strength-training ranges, not just "some
  // positive number": they exist to catch a plausible-looking but
  // nonsensical generation (e.g. targetSets: 500) that a bare `.positive()`
  // would happily let through, rather than as a description of the ideal
  // program for any given goal — that nuance lives in SYSTEM_PROMPT, since
  // a schema bound can only reject, not steer.
  const exercises = z
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
    // field, so it can't express "no repeated exerciseSlug within a day"
    // (two entries could legitimately share sets/reps but not the same
    // exercise) — that constraint only exists here, as a post-generation
    // check, same as the closed-slug-list safety net in index.ts.
    .superRefine((entries, ctx) => {
      const seen = new Set<string>();
      entries.forEach((entry, index) => {
        if (seen.has(entry.exerciseSlug)) {
          ctx.addIssue({
            code: "custom",
            message:
              `duplicate exerciseSlug "${entry.exerciseSlug}" in the same workout`,
            path: [index, "exerciseSlug"],
          });
        }
        seen.add(entry.exerciseSlug);
      });
    });
  return z.object({
    workouts: z
      .array(z.object({ name: z.string(), exercises }))
      .length(daysPerWeek),
  });
}

/**
 * JSON Schema form of `buildPlanSchema`, for providers (like Gemini's
 * `responseJsonSchema`) that take a request-time schema instead of a Zod
 * object. `$schema` is stripped — it's metadata about the schema dialect,
 * not part of the shape, and some providers reject unrecognized top-level
 * keywords.
 */
export function buildPlanJsonSchema(
  daysPerWeek: number,
  slugs: string[],
): Record<string, unknown> {
  const jsonSchema = z.toJSONSchema(buildPlanSchema(daysPerWeek, slugs)) as Record<
    string,
    unknown
  >;
  delete jsonSchema.$schema;
  return jsonSchema;
}

/**
 * Builds the user-turn prompt: goal/experience/equipment plus the full
 * closed list of exercises (slug + name + muscle group + equipment) the
 * model may choose from.
 */
export function buildUserPrompt(input: GeneratePlanRequest): string {
  const exerciseLines = input.exercises
    .map((e) => {
      const equipmentPart = e.equipment ? `, ${e.equipment}` : "";
      return `- ${e.slug}: ${e.name} (${e.muscleGroup}${equipmentPart})`;
    })
    .join("\n");
  const equipmentLine = input.availableEquipment.length > 0
    ? input.availableEquipment.join(", ")
    : "nenhum informado";

  return (
    `Objetivo: ${input.goal}\n` +
    `Dias por semana: ${input.daysPerWeek}\n` +
    `Nível de experiência: ${input.experienceLevel}\n` +
    `Equipamento disponível: ${equipmentLine}\n\n` +
    `Exercícios disponíveis (escolha só destes, pelo slug exato):\n${exerciseLines}`
  );
}

// Concrete, checkable rules rather than vague encouragement ("monte um bom
// treino") — a schema bound can only reject a bad plan after the fact
// (see buildPlanSchema above), this is what steers generation toward a
// sensible one in the first place. Each rule below maps to a real failure
// mode worth avoiding, not decoration:
//  - the closed-slug/exact-day-count rules are the hard requirements the
//    schema also enforces, stated plainly so the model doesn't have to
//    infer them from the JSON Schema alone;
//  - sets/reps ranges by goal and no-repeat-exercise-per-day are the two
//    most common ways a generated plan "feels wrong" to someone who
//    actually trains, even when it's structurally valid;
//  - rest-time and level-appropriate volume guidance keep a beginner's
//    first plan from being copy-pasted advanced programming.
export const SYSTEM_PROMPT =
  "Você é um personal trainer experiente que monta planos de treino " +
  "estruturados e realistas, prontos para alguém seguir na academia.\n\n" +
  "Regras obrigatórias:\n" +
  "1. Escolha exercícios apenas da lista fornecida pelo usuário, " +
  "referenciando cada um pelo campo slug exato — nunca invente um slug " +
  "que não esteja na lista.\n" +
  "2. Gere exatamente o número de dias de treino pedido, um objeto por " +
  "dia.\n" +
  "3. Nunca repita o mesmo exercício duas vezes no mesmo dia.\n" +
  "4. Distribua os grupos musculares de forma equilibrada ao longo da " +
  "semana — evite treinar o mesmo grupo em dias consecutivos sem motivo " +
  "(a menos que o objetivo ou a quantidade de dias realmente peçam " +
  "full body todo dia).\n\n" +
  "Diretrizes de bom senso (ajuste conforme o objetivo e nível " +
  "informados, mas fique dentro destas faixas):\n" +
  "- Séries por exercício: normalmente 3 a 5; até 2 para aquecimento ou " +
  "exercícios muito isolados, até 6 só em treinos avançados de alto " +
  "volume.\n" +
  "- Repetições: força/hipertrofia pesada 4-8, hipertrofia geral 8-12, " +
  "resistência/emagrecimento 12-20.\n" +
  "- Descanso entre séries: 90-180s em exercícios compostos pesados " +
  "(agachamento, terra, supino), 45-90s em exercícios isolados ou de " +
  "menor carga.\n" +
  "- Iniciantes: menos exercícios por dia (4-6), priorizando movimentos " +
  "compostos básicos. Avançados: mais volume e variedade (6-9 " +
  "exercícios por dia) são aceitáveis.\n" +
  "- Use o campo notes só para uma dica curta e útil (ex: cadência, " +
  "ponto de atenção na execução); deixe null se não houver nada relevante " +
  "a acrescentar.";
