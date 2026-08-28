import {
  buildAdjustJsonSchema,
  buildAdjustSchema,
  buildUserPrompt,
  RequestSchema,
} from "./adjust.ts";

function assert(condition: boolean, message = "assertion failed"): void {
  if (!condition) throw new Error(message);
}

function assertEquals<T>(actual: T, expected: T): void {
  if (actual !== expected) {
    throw new Error(`expected ${String(expected)}, got ${String(actual)}`);
  }
}

const sampleExercises = [
  { slug: "supino-reto-com-barra", name: "Supino reto com barra", muscleGroup: "chest", equipment: "barbell" },
  { slug: "agachamento-livre", name: "Agachamento livre", muscleGroup: "legs", equipment: "barbell" },
];

const baseContext = {
  goal: "hipertrofia",
  experienceLevel: "intermediate",
  sedentary: false,
  latestWeightKg: null,
  weightTrend: null,
};

Deno.test("RequestSchema accepts a well-formed request", () => {
  const result = RequestSchema.safeParse({
    instructions: "quero mais foco em resistência",
    currentExercises: [
      {
        exerciseSlug: "supino-reto-com-barra",
        targetSets: 3,
        targetReps: 10,
        targetRestSeconds: 90,
        notes: null,
      },
    ],
    availableEquipment: ["barbell"],
    exercises: sampleExercises,
    context: baseContext,
  });
  assert(result.success);
});

Deno.test("RequestSchema accepts an empty currentExercises list", () => {
  const result = RequestSchema.safeParse({
    instructions: "monte algo novo aqui",
    currentExercises: [],
    availableEquipment: [],
    exercises: sampleExercises,
    context: baseContext,
  });
  assert(result.success);
});

Deno.test("RequestSchema rejects empty instructions", () => {
  const result = RequestSchema.safeParse({
    instructions: "",
    currentExercises: [],
    availableEquipment: [],
    exercises: sampleExercises,
    context: baseContext,
  });
  assert(!result.success);
});

Deno.test("RequestSchema rejects an empty exercises catalog", () => {
  const result = RequestSchema.safeParse({
    instructions: "ajuste isso",
    currentExercises: [],
    availableEquipment: [],
    exercises: [],
    context: baseContext,
  });
  assert(!result.success);
});

Deno.test("RequestSchema rejects an invalid weightTrend", () => {
  const result = RequestSchema.safeParse({
    instructions: "ajuste isso",
    currentExercises: [],
    availableEquipment: [],
    exercises: sampleExercises,
    context: { ...baseContext, weightTrend: "sideways" },
  });
  assert(!result.success);
});

Deno.test("buildAdjustSchema accepts a well-formed response", () => {
  const schema = buildAdjustSchema(["supino-reto-com-barra", "agachamento-livre"]);
  const result = schema.safeParse({
    summary: "Adicionei agachamento para dar mais foco em pernas.",
    exercises: [
      {
        exerciseSlug: "supino-reto-com-barra",
        targetSets: 3,
        targetReps: 10,
        targetRestSeconds: 90,
        notes: null,
      },
      {
        exerciseSlug: "agachamento-livre",
        targetSets: 4,
        targetReps: 8,
        targetRestSeconds: 120,
        notes: null,
      },
    ],
  });
  assert(result.success);
});

Deno.test("buildAdjustSchema rejects an exerciseSlug outside the closed list", () => {
  const schema = buildAdjustSchema(["supino-reto-com-barra"]);
  const result = schema.safeParse({
    summary: "ajuste",
    exercises: [
      {
        exerciseSlug: "exercicio-inventado",
        targetSets: 3,
        targetReps: 10,
        targetRestSeconds: 90,
        notes: null,
      },
    ],
  });
  assert(!result.success);
});

Deno.test("buildAdjustSchema rejects a repeated exerciseSlug", () => {
  const schema = buildAdjustSchema(["supino-reto-com-barra"]);
  const result = schema.safeParse({
    summary: "ajuste",
    exercises: [
      {
        exerciseSlug: "supino-reto-com-barra",
        targetSets: 3,
        targetReps: 10,
        targetRestSeconds: 90,
        notes: null,
      },
      {
        exerciseSlug: "supino-reto-com-barra",
        targetSets: 4,
        targetReps: 8,
        targetRestSeconds: 90,
        notes: null,
      },
    ],
  });
  assert(!result.success);
});

Deno.test("buildAdjustSchema rejects a missing summary", () => {
  const schema = buildAdjustSchema(["supino-reto-com-barra"]);
  const result = schema.safeParse({
    exercises: [
      {
        exerciseSlug: "supino-reto-com-barra",
        targetSets: 3,
        targetReps: 10,
        targetRestSeconds: 90,
        notes: null,
      },
    ],
  });
  assert(!result.success);
});

Deno.test("buildAdjustJsonSchema strips $schema and matches buildAdjustSchema's shape", () => {
  const jsonSchema = buildAdjustJsonSchema([
    "supino-reto-com-barra",
    "agachamento-livre",
  ]);

  assert(!("$schema" in jsonSchema), "$schema should be stripped");
  assertEquals(jsonSchema.type, "object");

  const properties = jsonSchema.properties as Record<string, unknown>;
  assert("summary" in properties);
  const exercises = properties.exercises as Record<string, unknown>;
  const exerciseItems = exercises.items as Record<string, unknown>;
  const exerciseProps = exerciseItems.properties as Record<string, unknown>;
  const exerciseSlug = exerciseProps.exerciseSlug as Record<string, unknown>;
  assertEquals(
    JSON.stringify(exerciseSlug.enum),
    JSON.stringify(["supino-reto-com-barra", "agachamento-livre"]),
  );
});

Deno.test("buildUserPrompt includes current exercises, instructions and context", () => {
  const prompt = buildUserPrompt({
    instructions: "quero mais foco em resistência",
    currentExercises: [
      {
        exerciseSlug: "supino-reto-com-barra",
        targetSets: 3,
        targetReps: 10,
        targetRestSeconds: 90,
        notes: null,
      },
    ],
    availableEquipment: ["barbell"],
    exercises: sampleExercises,
    context: {
      goal: "emagrecimento",
      experienceLevel: "beginner",
      sedentary: true,
      latestWeightKg: 82,
      weightTrend: "up",
    },
  });

  assert(prompt.includes("supino-reto-com-barra: 3x10"));
  assert(prompt.includes("quero mais foco em resistência"));
  assert(prompt.includes("emagrecimento"));
  assert(prompt.includes("beginner"));
  assert(prompt.includes("sedentário no momento"));
  assert(prompt.includes("82kg"));
  assert(prompt.includes("em alta"));
  assert(prompt.includes("agachamento-livre"));
});

Deno.test("buildUserPrompt handles an empty current-exercises list", () => {
  const prompt = buildUserPrompt({
    instructions: "monte algo novo aqui",
    currentExercises: [],
    availableEquipment: [],
    exercises: sampleExercises,
    context: baseContext,
  });

  assert(prompt.includes("ainda não tem exercícios"));
  assert(prompt.includes("nenhum informado"));
  assert(prompt.includes("treinando com regularidade"));
});
