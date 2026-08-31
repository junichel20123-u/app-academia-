import {
  extractResponseText,
  GeminiTextGenerationProvider,
  mapGeminiError,
  mapMessagesToContents,
} from "./gemini_text_generation_provider.ts";

function assert(condition: boolean, message = "assertion failed"): void {
  if (!condition) throw new Error(message);
}

function assertEquals<T>(actual: T, expected: T): void {
  if (actual !== expected) {
    throw new Error(`expected ${String(expected)}, got ${String(actual)}`);
  }
}

Deno.test("mapGeminiError maps HTTP status codes", () => {
  assertEquals(mapGeminiError(400), "invalid_request");
  assertEquals(mapGeminiError(401), "auth");
  assertEquals(mapGeminiError(403), "auth");
  assertEquals(mapGeminiError(429), "rate_limited");
  assertEquals(mapGeminiError(500), "unavailable");
  assertEquals(mapGeminiError(503), "unavailable");
});

Deno.test("mapGeminiError maps an AbortError to timeout regardless of status", () => {
  const error = new Error("aborted");
  error.name = "AbortError";
  assertEquals(mapGeminiError(undefined, error), "timeout");
});

Deno.test("mapGeminiError treats a statusless network error as unavailable", () => {
  assertEquals(mapGeminiError(undefined, new TypeError("network error")), "unavailable");
});

Deno.test("mapGeminiError falls back to unknown with no status and no error", () => {
  assertEquals(mapGeminiError(undefined), "unknown");
  assertEquals(mapGeminiError(200), "unknown");
});

Deno.test("extractResponseText pulls text from a well-formed response", () => {
  const payload = {
    candidates: [
      { content: { parts: [{ text: '{"workouts":[]}' }] } },
    ],
  };
  assertEquals(extractResponseText(payload), '{"workouts":[]}');
});

Deno.test("extractResponseText returns undefined for missing/malformed shapes", () => {
  assert(extractResponseText({}) === undefined);
  assert(extractResponseText({ candidates: [] }) === undefined);
  assert(extractResponseText({ candidates: [{}] }) === undefined);
  assert(
    extractResponseText({ candidates: [{ content: { parts: [] } }] }) ===
      undefined,
  );
  assert(
    extractResponseText({
      candidates: [{ content: { parts: [{ text: 123 }] } }],
    }) === undefined,
  );
});

Deno.test("mapMessagesToContents maps role and content in order", () => {
  const contents = mapMessagesToContents([
    { role: "user", content: "Quantas calorias devo comer?" },
    { role: "model", content: "Depende do seu objetivo e peso atual." },
  ]);

  assertEquals(contents.length, 2);
  assertEquals(contents[0].role, "user");
  assertEquals(contents[0].parts[0].text, "Quantas calorias devo comer?");
  assertEquals(contents[1].role, "model");
  assertEquals(
    contents[1].parts[0].text,
    "Depende do seu objetivo e peso atual.",
  );
});

Deno.test("mapMessagesToContents returns an empty array for no messages", () => {
  assertEquals(mapMessagesToContents([]).length, 0);
});

/// Captures the body of the single `generateContent` call `run` makes, by
/// swapping `globalThis.fetch` for a stub that answers with a minimal
/// well-formed Gemini response. Deno needs no mocking library for this,
/// and it's the only way to assert on what we actually send — the request
/// body is built inside a private method, so a pure-function test (the
/// convention for the rest of this file) can't reach it.
async function captureRequestBody(
  run: (provider: GeminiTextGenerationProvider) => Promise<unknown>,
): Promise<Record<string, unknown>> {
  const originalFetch = globalThis.fetch;
  let captured: Record<string, unknown> | undefined;
  globalThis.fetch = ((_url: string | URL | Request, init?: RequestInit) => {
    captured = JSON.parse(String(init?.body));
    return Promise.resolve(
      new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: '{"workouts":[]}' }] } }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
  }) as typeof globalThis.fetch;
  try {
    await run(new GeminiTextGenerationProvider("test-key"));
  } finally {
    globalThis.fetch = originalFetch;
  }
  if (captured === undefined) throw new Error("fetch was never called");
  return captured;
}

function thinkingLevelOf(body: Record<string, unknown>): unknown {
  const generationConfig = body.generationConfig as
    | { thinkingConfig?: { thinkingLevel?: unknown } }
    | undefined;
  return generationConfig?.thinkingConfig?.thinkingLevel;
}

// Regression guard: `gemini-3.6-flash` is a Gemini 3 model, which does
// extended thinking by default. Omitting thinkingConfig is what pushed
// every call past the provider's own abort, surfacing to the app as a
// blanket 503 on both the plan builder and the coach.
Deno.test("generateStructured asks for low thinking", async () => {
  const body = await captureRequestBody((provider) =>
    provider.generateStructured({
      systemPrompt: "system",
      userPrompt: "user",
      jsonSchema: { type: "object" },
    })
  );
  assertEquals(thinkingLevelOf(body), "low");
});

Deno.test("generateText asks for low thinking", async () => {
  const body = await captureRequestBody((provider) =>
    provider.generateText({
      systemPrompt: "system",
      messages: [{ role: "user", content: "oi" }],
    })
  );
  assertEquals(thinkingLevelOf(body), "low");
});

// The legacy thinkingBudget field is mutually exclusive with
// thinkingLevel — sending both makes Gemini reject the whole request.
Deno.test("neither call sends the legacy thinkingBudget field", async () => {
  for (
    const run of [
      (p: GeminiTextGenerationProvider) =>
        p.generateStructured({
          systemPrompt: "s",
          userPrompt: "u",
          jsonSchema: { type: "object" },
        }),
      (p: GeminiTextGenerationProvider) =>
        p.generateText({ systemPrompt: "s", messages: [] }),
    ]
  ) {
    const body = await captureRequestBody(run);
    assert(!JSON.stringify(body).includes("thinkingBudget"));
  }
});
