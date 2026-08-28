import { buildSystemPrompt, RequestSchema, toProviderMessages } from "./chat.ts";

function assert(condition: boolean, message = "assertion failed"): void {
  if (!condition) throw new Error(message);
}

function assertEquals<T>(actual: T, expected: T): void {
  if (actual !== expected) {
    throw new Error(`expected ${String(expected)}, got ${String(actual)}`);
  }
}

Deno.test("RequestSchema accepts a well-formed request", () => {
  const result = RequestSchema.safeParse({
    messages: [{ role: "user", content: "Como monto uma dieta?" }],
    profile: { goal: "emagrecimento", experienceLevel: "beginner" },
    activitySummary: "Nenhum treino registrado ainda.",
  });
  assert(result.success);
});

Deno.test("RequestSchema accepts null profile and activitySummary", () => {
  const result = RequestSchema.safeParse({
    messages: [{ role: "user", content: "Oi" }],
    profile: null,
    activitySummary: null,
  });
  assert(result.success);
});

Deno.test("RequestSchema rejects an empty messages array", () => {
  const result = RequestSchema.safeParse({
    messages: [],
    profile: null,
    activitySummary: null,
  });
  assert(!result.success);
});

Deno.test("RequestSchema rejects more than 30 messages", () => {
  const messages = Array.from({ length: 31 }, (_, i) => ({
    role: "user" as const,
    content: `mensagem ${i}`,
  }));
  const result = RequestSchema.safeParse({
    messages,
    profile: null,
    activitySummary: null,
  });
  assert(!result.success);
});

Deno.test("RequestSchema rejects an empty message content", () => {
  const result = RequestSchema.safeParse({
    messages: [{ role: "user", content: "" }],
    profile: null,
    activitySummary: null,
  });
  assert(!result.success);
});

Deno.test("RequestSchema rejects an invalid role", () => {
  const result = RequestSchema.safeParse({
    messages: [{ role: "system", content: "oi" }],
    profile: null,
    activitySummary: null,
  });
  assert(!result.success);
});

Deno.test("buildSystemPrompt returns the base prompt with no context", () => {
  const prompt = buildSystemPrompt(null, null);
  assert(prompt.includes("coach especializado"));
  assert(!prompt.includes("Contexto do usuário"));
});

Deno.test("buildSystemPrompt includes goal, experience level and activity when present", () => {
  const prompt = buildSystemPrompt(
    { goal: "hipertrofia", experienceLevel: "intermediate" },
    "Sedentário nas últimas 2 semanas.",
  );
  assert(prompt.includes("Contexto do usuário"));
  assert(prompt.includes("hipertrofia"));
  assert(prompt.includes("intermediate"));
  assert(prompt.includes("Sedentário nas últimas 2 semanas."));
});

Deno.test("buildSystemPrompt omits profile fields that are null", () => {
  const prompt = buildSystemPrompt(
    { goal: null, experienceLevel: null },
    "Peso mais recente: 80 kg.",
  );
  assert(prompt.includes("Contexto do usuário"));
  assert(prompt.includes("Peso mais recente: 80 kg."));
  assert(!prompt.includes("Objetivo:"));
  assert(!prompt.includes("Nível de experiência:"));
});

Deno.test("toProviderMessages maps assistant to model and keeps user as-is", () => {
  const mapped = toProviderMessages([
    { role: "user", content: "Oi" },
    { role: "assistant", content: "Olá! Como posso ajudar?" },
  ]);
  assertEquals(mapped.length, 2);
  assertEquals(mapped[0], { role: "user", content: "Oi" });
  assertEquals(mapped[1], { role: "model", content: "Olá! Como posso ajudar?" });
});
