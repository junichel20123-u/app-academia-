import {
  buildPlanJsonSchema,
  buildPlanSchema,
  buildUserPrompt,
  RequestSchema,
  SYSTEM_PROMPT,
} from "./plan.ts";
import { GeminiTextGenerationProvider } from "../_shared/providers/gemini_text_generation_provider.ts";
import { TextGenerationError } from "../_shared/providers/text_generation_provider.ts";

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Maps our provider-agnostic error taxonomy to an HTTP status. Kept here
// (not in the provider) since "what status code a client sees" is a
// decision for this endpoint, not for any one vendor's SDK.
function statusForError(error: TextGenerationError): number {
  switch (error.kind) {
    case "invalid_request":
      return 400;
    case "rate_limited":
      return 429;
    // Split, not both 503: these two are indistinguishable to the client
    // otherwise, and telling them apart is exactly what cost a round trip
    // through the Edge Function logs the first time this fired. 504 means
    // "Gemini was still working when we gave up" (our own abort), 503
    // means "Gemini itself was unreachable or erroring".
    case "timeout":
      return 504;
    case "unavailable":
      return 503;
    case "auth":
    case "invalid_response":
    case "unknown":
      return 502;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let input;
  try {
    input = RequestSchema.parse(await req.json());
  } catch (error) {
    return jsonResponse(
      { error: "Invalid request", details: `${error}` },
      400,
    );
  }

  // GEMINI_API_KEY only ever lives as an Edge Function secret (`supabase
  // secrets set`) — never in this source, never on the client, never in
  // the local SQLite database. See the app's M17 plan note (provider
  // switch from Anthropic to Gemini for free-tier prototyping).
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return jsonResponse(
      { error: "Server misconfigured: missing GEMINI_API_KEY" },
      500,
    );
  }

  const slugs = input.exercises.map((e) => e.slug);
  const planSchema = buildPlanSchema(input.daysPerWeek, slugs);
  const provider = new GeminiTextGenerationProvider(
    apiKey,
    Deno.env.get("GEMINI_MODEL") || undefined,
  );

  try {
    const raw = await provider.generateStructured({
      systemPrompt: SYSTEM_PROMPT,
      userPrompt: buildUserPrompt(input),
      jsonSchema: buildPlanJsonSchema(input.daysPerWeek, slugs),
    });

    // A plan with any exerciseSlug outside the closed list, or the wrong
    // number of days, fails this Zod validation (the enum/length
    // constraints are part of planSchema — the same schema already sent to
    // the provider as the required response shape, so this is a safety net
    // rather than the primary guarantee). Reject the whole plan rather than
    // salvage a partial one: unlike the free, curated template catalog
    // (which skips one bad entry and warns), this is an on-demand
    // generation, so a structural failure should be visible, not silently
    // patched over.
    const parsed = planSchema.safeParse(raw);
    if (!parsed.success) {
      return jsonResponse({ error: "A IA não retornou um plano válido." }, 502);
    }

    return jsonResponse(parsed.data, 200);
  } catch (error) {
    console.error("generate-plan error", error);
    if (error instanceof TextGenerationError) {
      return jsonResponse(
        { error: "Falha ao gerar o plano." },
        statusForError(error),
      );
    }
    return jsonResponse({ error: "Falha ao gerar o plano." }, 502);
  }
});
