import {
  extractResponseText,
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
