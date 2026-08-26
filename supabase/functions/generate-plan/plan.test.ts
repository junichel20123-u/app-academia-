import { buildPlanSchema, buildUserPrompt, RequestSchema } from "./plan.ts";

// No external assertion library — a handful of throwing checks is simpler
// than pulling in a dependency (and avoids relying on a registry beyond
// npm, which is all these Edge Function files otherwise need).
function assert(condition: boolean, message = "assertion failed"): void {
  if (!condition) throw new Error(message);
}

function assertEquals<T>(actual: T, expected: T): void {
  if (actual !== expected) {
    throw new Error(`expected ${String(expected)}, got ${String(actual)}`);
  }
}

function assertThrows(fn: () => unknown): void {
  try {
    fn();
  } catch {
    return;
  }
  throw new Error("expected function to throw, but it did not");
}

const sampleExercises = [
  { slug: "supino-reto-com-barra", name: "Supino reto com barra", muscleGroup: "chest", equipment: "barbell" },
  { slug: "agachamento-livre", name: "Agachamento livre", muscleGroup: "legs", equipment: "barbell" },
];

Deno.test("RequestSchema accepts a well-formed request", () => {
  const result = RequestSchema.safeParse({
    goal: "hypertrophy",
    daysPerWeek: 3,
    experienceLevel: "beginner",
    availableEquipment: ["barbell", "dumbbell"],
    exercises: sampleExercises,
  });
  assert(result.success);
});

Deno.test("RequestSchema rejects daysPerWeek out of range", () => {
  const result = RequestSchema.safeParse({
    goal: "hypertrophy",
    daysPerWeek: 8,
    experienceLevel: "beginner",
    availableEquipment: [],
    exercises: sampleExercises,
  });
  assert(!result.success);
});

Deno.test("RequestSchema rejects an empty exercise list", () => {
  const result = RequestSchema.safeParse({
    goal: "hypertrophy",
    daysPerWeek: 3,
    experienceLevel: "beginner",
    availableEquipment: [],
    exercises: [],
  });
  assert(!result.success);
});

Deno.test("buildPlanSchema throws on an empty slug list", () => {
  assertThrows(() => buildPlanSchema(3, []));
});

Deno.test("buildPlanSchema accepts a plan with the right day count and known slugs", () => {
  const schema = buildPlanSchema(2, ["supino-reto-com-barra", "agachamento-livre"]);
  const result = schema.safeParse({
    workouts: [
      {
        name: "Push",
        exercises: [
          {
            exerciseSlug: "supino-reto-com-barra",
            targetSets: 3,
            targetReps: 10,
            targetRestSeconds: 90,
            notes: null,
          },
        ],
      },
      {
        name: "Legs",
        exercises: [
          {
            exerciseSlug: "agachamento-livre",
            targetSets: 4,
            targetReps: 8,
            targetRestSeconds: 120,
            notes: null,
          },
        ],
      },
    ],
  });
  assert(result.success);
});

Deno.test("buildPlanSchema rejects a plan with the wrong number of workout days", () => {
  const schema = buildPlanSchema(3, ["supino-reto-com-barra"]);
  const result = schema.safeParse({
    workouts: [
      {
        name: "Push",
        exercises: [
          {
            exerciseSlug: "supino-reto-com-barra",
            targetSets: 3,
            targetReps: 10,
            targetRestSeconds: 90,
            notes: null,
          },
        ],
      },
    ],
  });
  assert(!result.success);
});

Deno.test("buildPlanSchema rejects an exerciseSlug outside the closed list", () => {
  const schema = buildPlanSchema(1, ["supino-reto-com-barra"]);
  const result = schema.safeParse({
    workouts: [
      {
        name: "Push",
        exercises: [
          {
            exerciseSlug: "exercicio-inventado-pela-ia",
            targetSets: 3,
            targetReps: 10,
            targetRestSeconds: 90,
            notes: null,
          },
        ],
      },
    ],
  });
  assert(!result.success);
});

Deno.test("buildUserPrompt includes the goal, days, equipment and every exercise slug", () => {
  const prompt = buildUserPrompt({
    goal: "emagrecimento",
    daysPerWeek: 4,
    experienceLevel: "intermediate",
    availableEquipment: ["dumbbell"],
    exercises: sampleExercises,
  });

  assert(prompt.includes("emagrecimento"));
  assert(prompt.includes("4"));
  assert(prompt.includes("intermediate"));
  assert(prompt.includes("dumbbell"));
  assert(prompt.includes("supino-reto-com-barra"));
  assert(prompt.includes("agachamento-livre"));
});

Deno.test("buildUserPrompt falls back to a placeholder with no equipment listed", () => {
  const prompt = buildUserPrompt({
    goal: "hypertrophy",
    daysPerWeek: 3,
    experienceLevel: "beginner",
    availableEquipment: [],
    exercises: sampleExercises,
  });

  assert(prompt.includes("nenhum informado"));
});

Deno.test("buildUserPrompt shows exercises with no equipment without a trailing comma", () => {
  const prompt = buildUserPrompt({
    goal: "hypertrophy",
    daysPerWeek: 1,
    experienceLevel: "beginner",
    availableEquipment: [],
    exercises: [
      { slug: "flexao-de-braco", name: "Flexão de braço", muscleGroup: "chest", equipment: null },
    ],
  });

  assertEquals(
    prompt.includes("flexao-de-braco: Flexão de braço (chest)"),
    true,
  );
});
