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
 * of exactly the slugs the client sent. Claude cannot reference an exercise
 * outside that list because the enum constrains generation itself, not just
 * a downstream check on the response.
 */
export function buildPlanSchema(daysPerWeek: number, slugs: string[]) {
  if (slugs.length === 0) {
    throw new Error("slugs must be non-empty");
  }
  const [first, ...rest] = slugs;
  const exerciseSlug = z.enum([first, ...rest]);
  return z.object({
    workouts: z
      .array(
        z.object({
          name: z.string(),
          exercises: z
            .array(
              z.object({
                exerciseSlug,
                targetSets: z.number().int().positive(),
                targetReps: z.number().int().positive().nullable(),
                targetRestSeconds: z.number().int().positive().nullable(),
                notes: z.string().nullable(),
              }),
            )
            .min(1),
        }),
      )
      .length(daysPerWeek),
  });
}

/**
 * Builds the user-turn prompt: goal/experience/equipment plus the full
 * closed list of exercises (slug + name + muscle group + equipment) Claude
 * may choose from.
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

export const SYSTEM_PROMPT =
  "Você é um personal trainer que monta planos de treino. Escolha exercícios " +
  "apenas da lista fornecida pelo usuário, referenciando cada um pelo campo " +
  "slug exato — nunca invente um slug que não esteja na lista. Gere exatamente " +
  "o número de dias de treino pedido.";
