import { z } from "npm:zod@^4.0.0";

import {
  buildExercisesSchema,
  CatalogExerciseSchema,
} from "../_shared/exercise_plan_schema.ts";

const CurrentExerciseSchema = z.object({
  exerciseSlug: z.string().min(1),
  targetSets: z.number().int().min(1),
  targetReps: z.number().int().min(1).nullable(),
  targetRestSeconds: z.number().int().min(1).nullable(),
  notes: z.string().nullable(),
});

const ContextSchema = z.object({
  goal: z.string().nullable(),
  experienceLevel: z.string().nullable(),
  sedentary: z.boolean(),
  latestWeightKg: z.number().nullable(),
  weightTrend: z.enum(["up", "down", "stable"]).nullable(),
});

export const RequestSchema = z.object({
  instructions: z.string().min(1).max(1000),
  currentExercises: z.array(CurrentExerciseSchema),
  availableEquipment: z.array(z.string()),
  exercises: z.array(CatalogExerciseSchema).min(1),
  context: ContextSchema,
});

export type AdjustWorkoutRequest = z.infer<typeof RequestSchema>;

/**
 * Builds the structured-output schema for the response: a short `summary`
 * explaining the adjustment plus the revised exercise list, constrained to
 * the same closed slug enum and sets/reps/rest bounds as `generate-plan`
 * (via the shared `buildExercisesSchema` — see
 * _shared/exercise_plan_schema.ts) so an adjustment can't drift into an
 * exercise this install doesn't have or an implausible prescription any
 * more than a freshly generated plan can.
 */
export function buildAdjustSchema(slugs: string[]) {
  return z.object({
    summary: z.string().min(1),
    exercises: buildExercisesSchema(slugs),
  });
}

/** JSON Schema form of `buildAdjustSchema`, for the provider's
 * `responseJsonSchema` — same convention as `buildPlanJsonSchema` in
 * generate-plan/plan.ts, `$schema` stripped for the same reason. */
export function buildAdjustJsonSchema(
  slugs: string[],
): Record<string, unknown> {
  const jsonSchema = z.toJSONSchema(buildAdjustSchema(slugs)) as Record<
    string,
    unknown
  >;
  delete jsonSchema.$schema;
  return jsonSchema;
}

function contextLines(context: AdjustWorkoutRequest["context"]): string {
  const lines: string[] = [];
  if (context.goal) lines.push(`Objetivo: ${context.goal}`);
  if (context.experienceLevel) {
    lines.push(`Nível de experiência: ${context.experienceLevel}`);
  }
  lines.push(
    context.sedentary
      ? "Atividade recente: sem treinos completados nas últimas 2 semanas (sedentário no momento)."
      : "Atividade recente: treinando com regularidade.",
  );
  if (context.latestWeightKg != null) {
    const trendLabel = context.weightTrend === "up"
      ? "em alta"
      : context.weightTrend === "down"
      ? "em queda"
      : "estável";
    lines.push(
      `Peso mais recente: ${context.latestWeightKg}kg (tendência ${trendLabel}).`,
    );
  }
  return lines.join("\n");
}

/**
 * Builds the user-turn prompt: the current exercises in this workout, the
 * user's free-text request, their context (goal/level/activity/weight),
 * and the full closed catalog to choose replacements/additions from — same
 * "closed list, exact slug" convention as generate-plan/plan.ts's
 * `buildUserPrompt`.
 */
export function buildUserPrompt(input: AdjustWorkoutRequest): string {
  const currentLines = input.currentExercises.length > 0
    ? input.currentExercises
      .map((e) =>
        `- ${e.exerciseSlug}: ${e.targetSets}x${e.targetReps ?? "-"}` +
        (e.notes ? ` (${e.notes})` : "")
      )
      .join("\n")
    : "(este treino ainda não tem exercícios)";

  const equipmentLine = input.availableEquipment.length > 0
    ? input.availableEquipment.join(", ")
    : "nenhum informado";

  const exerciseLines = input.exercises
    .map((e) => {
      const equipmentPart = e.equipment ? `, ${e.equipment}` : "";
      return `- ${e.slug}: ${e.name} (${e.muscleGroup}${equipmentPart})`;
    })
    .join("\n");

  return (
    `Treino atual:\n${currentLines}\n\n` +
    `Pedido do usuário: ${input.instructions}\n\n` +
    `Contexto:\n${contextLines(input.context)}\n\n` +
    `Equipamento disponível: ${equipmentLine}\n\n` +
    `Exercícios disponíveis (escolha só destes, pelo slug exato):\n${exerciseLines}`
  );
}

// Same sets/reps/rest guidance as generate-plan/plan.ts's SYSTEM_PROMPT
// (kept consistent so an adjusted workout doesn't read as a different
// program's rules), plus the two things this endpoint adds that
// generate-plan has no notion of: it edits an existing workout instead of
// creating one, and it must react to sedentarismo/peso instead of ignoring
// them.
export const SYSTEM_PROMPT =
  "Você é um personal trainer experiente ajustando um treino que o " +
  "usuário JÁ TEM, a partir de um pedido específico dele — você não está " +
  "criando um plano do zero.\n\n" +
  "Regras obrigatórias:\n" +
  "1. Escolha exercícios apenas da lista fornecida pelo usuário, " +
  "referenciando cada um pelo campo slug exato — nunca invente um slug " +
  "que não esteja na lista.\n" +
  "2. Parta do treino atual: mantenha o que já faz sentido para o pedido, " +
  "troque, adicione ou remova só o necessário para atender o que foi " +
  "pedido — evite reescrever o treino inteiro sem motivo.\n" +
  "3. Nunca repita o mesmo exercício duas vezes na lista.\n" +
  "4. Se o contexto indicar sedentarismo (sem treinos recentes), priorize " +
  "consistência e progressão conservadora em vez de saltos de " +
  "intensidade — um treino mais curto e sustentável vale mais que um " +
  "muito exigente que a pessoa não vai manter.\n" +
  "5. Se houver uma tendência de peso, você pode mencioná-la no raciocínio " +
  "do campo summary, mas nunca faça diagnóstico médico nem prescreva " +
  "suplementação ou dieta específica — isso é fora do escopo deste ajuste.\n\n" +
  "Diretrizes de bom senso (mesmas faixas do montador de planos):\n" +
  "- Séries por exercício: normalmente 3 a 5; até 2 para aquecimento ou " +
  "exercícios muito isolados, até 6 só em treinos avançados de alto " +
  "volume.\n" +
  "- Repetições: força/hipertrofia pesada 4-8, hipertrofia geral 8-12, " +
  "resistência/emagrecimento 12-20.\n" +
  "- Descanso entre séries: 90-180s em exercícios compostos pesados, " +
  "45-90s em exercícios isolados ou de menor carga.\n" +
  "- Use o campo notes só para uma dica curta e útil; deixe null se não " +
  "houver nada relevante a acrescentar.\n\n" +
  "No campo summary, explique em 1 a 3 frases por que o ajuste proposto " +
  "atende ao pedido do usuário.";
