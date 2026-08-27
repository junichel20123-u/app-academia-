import {
  StructuredGenerationRequest,
  TextGenerationError,
  TextGenerationErrorKind,
  TextGenerationProvider,
} from "./text_generation_provider.ts";

// Plain REST calls, not the `@google/genai` npm SDK: that SDK pulls in
// `google-auth-library` -> `gcp-metadata` -> `google-logging-utils`, a
// dependency chain built for GCP service-account auth that reads env vars
// (e.g. GOOGLE_SDK_NODE_LOGGING) just on import — a documented source of
// permission errors in Deno/Supabase Edge Functions specifically, which
// don't grant the same broad Node-style env access a plain `deno run`
// would. A single JSON POST with an API key doesn't need any of that, and
// every other external call in this app (dio on the Flutter side, the
// Runway/HTTP job-based video providers) already prefers a direct HTTP call
// over a heavy SDK for exactly this kind of simple REST endpoint.
const BASE_URL = "https://generativelanguage.googleapis.com/v1beta";

// `gemini-2.5-flash` (the original M17 choice) was retired for new accounts
// — a live call now 404s with "This model ... is no longer available to new
// users. Please update your code to use models/gemini-3.6-flash" straight
// from Gemini's own API. Free-tier-eligible (no card required) with a
// similar quota to what 2.5-flash had; still more than enough for
// generation this constrained (see plan.ts's buildPlanSchema — the closed
// exerciseSlug enum and exact day count already guarantee structure).
const DEFAULT_MODEL = "gemini-3.6-flash";
const DEFAULT_TIMEOUT_MS = 30_000;

/**
 * Maps a REST error (an HTTP status code, from either a non-OK response or
 * a thrown fetch/abort error) to our provider-agnostic error taxonomy. A
 * pure function so it's unit-testable without a real network call —
 * mirrors `describeRunwayError` in the Flutter app's video_generation
 * feature.
 */
export function mapGeminiError(
  status: number | undefined,
  error?: unknown,
): TextGenerationErrorKind {
  if (error instanceof Error && error.name === "AbortError") {
    return "timeout";
  }
  if (status === 400) return "invalid_request";
  if (status === 401 || status === 403) return "auth";
  if (status === 429) return "rate_limited";
  if (status !== undefined && status >= 500) return "unavailable";
  if (status === undefined && error !== undefined) return "unavailable";
  return "unknown";
}

export class GeminiTextGenerationProvider implements TextGenerationProvider {
  readonly id = "gemini";

  constructor(
    private readonly apiKey: string,
    private readonly model: string = DEFAULT_MODEL,
    private readonly timeoutMs: number = DEFAULT_TIMEOUT_MS,
  ) {}

  async generateStructured(
    request: StructuredGenerationRequest,
  ): Promise<unknown> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);

    let response: Response;
    try {
      response = await fetch(
        `${BASE_URL}/models/${this.model}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": this.apiKey,
          },
          body: JSON.stringify({
            contents: [{ parts: [{ text: request.userPrompt }] }],
            systemInstruction: { parts: [{ text: request.systemPrompt }] },
            generationConfig: {
              responseMimeType: "application/json",
              responseJsonSchema: request.jsonSchema,
            },
          }),
          signal: controller.signal,
        },
      );
    } catch (error) {
      throw new TextGenerationError(
        mapGeminiError(undefined, error),
        `Gemini request failed: ${error}`,
        error,
      );
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      const body = await response.text().catch(() => "");
      throw new TextGenerationError(
        mapGeminiError(response.status),
        `Gemini returned HTTP ${response.status}: ${body}`,
      );
    }

    const payload = await response.json().catch((error) => {
      throw new TextGenerationError(
        "invalid_response",
        `Gemini response was not valid JSON: ${error}`,
        error,
      );
    });

    const text = extractResponseText(payload);
    if (!text) {
      throw new TextGenerationError(
        "invalid_response",
        "Gemini returned no text in its response.",
      );
    }

    try {
      return JSON.parse(text);
    } catch (error) {
      throw new TextGenerationError(
        "invalid_response",
        `Gemini's text was not valid JSON: ${error}`,
        error,
      );
    }
  }
}

/**
 * Pulls the generated text out of a `generateContent` response body
 * (`candidates[0].content.parts[0].text`). A pure function, tested
 * separately from the network call.
 */
export function extractResponseText(payload: unknown): string | undefined {
  const candidates = (payload as { candidates?: unknown })?.candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return undefined;
  const parts = (candidates[0] as { content?: { parts?: unknown } })?.content
    ?.parts;
  if (!Array.isArray(parts) || parts.length === 0) return undefined;
  const text = (parts[0] as { text?: unknown })?.text;
  return typeof text === "string" ? text : undefined;
}
