import {
  ChatMessage,
  StructuredGenerationRequest,
  TextGenerationError,
  TextGenerationErrorKind,
  TextGenerationProvider,
  TextGenerationRequest,
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
// 60s, not the original 30s: the 30s cap was chosen before this function
// ran on a Gemini 3 generation model, and it started firing on *every*
// call once `gemini-3.6-flash` became the model — the Edge Function logs
// showed the abort landing exactly 30.0s after each boot, so the request
// was still in flight, not failing. Well inside Supabase's own wall-clock
// budget for an Edge Function, and it only ever costs real time on a call
// that would otherwise have failed outright. DEFAULT_THINKING_LEVEL below
// is what actually brings the normal case back under a few seconds; this
// is the backstop for a slow tail, not the fix.
const DEFAULT_TIMEOUT_MS = 60_000;

// Gemini 3 models (this one included) do extended "thinking" by default
// — the API's default effort is medium — and that is what pushed every
// call past the old 30s abort. Asking for a lower level is the natural
// fix, but `gemini-3.6-flash` rejects a thinkingConfig on these calls
// with a bare 400 "Request contains an invalid argument" (the enum value
// itself is fine — the live API accepts "low" and rejects a bogus value
// at proto-parse time, before auth — so the rejection is semantic, most
// likely the combination with responseJsonSchema).
//
// So: no thinkingConfig unless GEMINI_THINKING_LEVEL is set. Unset (the
// default) reproduces the request shape that Gemini demonstrably accepts,
// and the knob makes it possible to probe a working value with
// `supabase secrets set` alone, without a code change and redeploy for
// each attempt — same reason GEMINI_MODEL is already an env var.
// Note: thinkingLevel and the legacy thinkingBudget are mutually
// exclusive — sending both fails the request.
// Lower than Gemini's default (1.0): this call is constrained structured
// generation against a closed exercise list and numeric bounds (see
// plan.ts's buildPlanSchema), not open-ended creative writing — a lower
// temperature makes the model follow SYSTEM_PROMPT's concrete rules (no
// repeated exercise per day, sane sets/reps ranges) more consistently,
// trading away variety it doesn't need for a slightly more predictable
// plan run to run.
const DEFAULT_TEMPERATURE = 0.4;
// Higher than DEFAULT_TEMPERATURE: the ai-coach chat endpoint is open-ended
// conversation (fitness/nutrition Q&A), not constrained structured
// generation against a closed list and numeric bounds — a bit more warmth
// reads as more natural coaching without the reply losing coherence.
const DEFAULT_CHAT_TEMPERATURE = 0.7;

/**
 * Picks the auth header that matches the credential's format. Google is
 * migrating Gemini API keys from the old "Standard" keys (`AIza...`) to
 * "Auth" keys (`AQ.Ab...`), and the two are not interchangeable across
 * headers — verified against the live API, where each format is only
 * recognized *as a key* in one of them:
 *
 *   AQ.  + Authorization: Bearer  -> API_KEY_SERVICE_BLOCKED  (recognized)
 *   AQ.  + x-goog-api-key         -> ACCESS_TOKEN_TYPE_UNSUPPORTED
 *   AIza + x-goog-api-key         -> API_KEY_INVALID           (recognized)
 *   AIza + Authorization: Bearer  -> ACCESS_TOKEN_TYPE_UNSUPPORTED
 *
 * (Those are the errors for deliberately fake keys of each shape: a
 * key-level complaint means the header parsed it as a key, a type
 * complaint means it did not.) Hardcoding `x-goog-api-key` meant an
 * AQ-format key could never authenticate, which is what surfaced in the
 * app as a 401 and then a bare 400.
 *
 * Sending both headers is not an option — the wrong one takes precedence
 * and fails the request — so the format has to pick. A pure function so
 * it is unit-testable without a real call, matching `mapGeminiError` and
 * `extractResponseText` below.
 */
export function buildAuthHeaders(apiKey: string): Record<string, string> {
  return apiKey.startsWith("AQ.")
    ? { "Authorization": `Bearer ${apiKey}` }
    : { "x-goog-api-key": apiKey };
}

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
    private readonly thinkingLevel: string | undefined = undefined,
    private readonly timeoutMs: number = DEFAULT_TIMEOUT_MS,
  ) {}

  async generateStructured(
    request: StructuredGenerationRequest,
  ): Promise<unknown> {
    const text = await this._generateContentText({
      contents: [{ parts: [{ text: request.userPrompt }] }],
      systemInstruction: { parts: [{ text: request.systemPrompt }] },
      generationConfig: this._generationConfig({
        responseMimeType: "application/json",
        responseJsonSchema: request.jsonSchema,
        temperature: DEFAULT_TEMPERATURE,
      }),
    });

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

  async generateText(request: TextGenerationRequest): Promise<string> {
    return await this._generateContentText({
      contents: mapMessagesToContents(request.messages),
      systemInstruction: { parts: [{ text: request.systemPrompt }] },
      generationConfig: this._generationConfig({
        temperature: DEFAULT_CHAT_TEMPERATURE,
      }),
    });
  }

  /** Adds a thinkingConfig to a generationConfig only when a level was
   * configured — see DEFAULT_MODEL's note above on why the default is to
   * send none at all. */
  private _generationConfig(base: Record<string, unknown>): unknown {
    if (this.thinkingLevel === undefined) return base;
    return { ...base, thinkingConfig: { thinkingLevel: this.thinkingLevel } };
  }

  /** Shared `:generateContent` call + response-text extraction behind
   * `generateStructured` and `generateText` — the only difference between
   * the two is what each does with the extracted text afterwards (parse as
   * JSON vs. return as-is). */
  private async _generateContentText(body: unknown): Promise<string> {
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
            ...buildAuthHeaders(this.apiKey),
          },
          body: JSON.stringify(body),
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
      const responseBody = await response.text().catch(() => "");
      throw new TextGenerationError(
        mapGeminiError(response.status),
        `Gemini returned HTTP ${response.status}: ${responseBody}`,
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
    return text;
  }
}

/**
 * Maps a chat history to Gemini's `contents` request field (`role`/`parts`).
 * A pure function, tested separately from the network call — mirrors
 * `extractResponseText` below.
 */
export function mapMessagesToContents(
  messages: ChatMessage[],
): Array<{ role: string; parts: Array<{ text: string }> }> {
  return messages.map((message) => ({
    role: message.role,
    parts: [{ text: message.content }],
  }));
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
