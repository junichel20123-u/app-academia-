import { buildSystemPrompt, RequestSchema, toProviderMessages } from "./chat.ts";
import { GeminiTextGenerationProvider } from "../_shared/providers/gemini_text_generation_provider.ts";
import { TextGenerationError } from "../_shared/providers/text_generation_provider.ts";

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Same taxonomy->status mapping as generate-plan/index.ts — kept here (not
// in the provider) since "what status code a client sees" is a decision
// for this endpoint, not for any one vendor's SDK.
function statusForError(error: TextGenerationError): number {
  switch (error.kind) {
    case "invalid_request":
      return 400;
    case "rate_limited":
      return 429;
    case "timeout":
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
  // secrets set`) — never in this source, never on the client. Shared with
  // generate-plan, which sets the same secret for the same project.
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return jsonResponse(
      { error: "Server misconfigured: missing GEMINI_API_KEY" },
      500,
    );
  }

  const provider = new GeminiTextGenerationProvider(
    apiKey,
    Deno.env.get("GEMINI_MODEL") || undefined,
  );

  try {
    const reply = await provider.generateText({
      systemPrompt: buildSystemPrompt(input.profile, input.activitySummary),
      messages: toProviderMessages(input.messages),
    });

    return jsonResponse({ reply }, 200);
  } catch (error) {
    console.error("ai-coach error", error);
    if (error instanceof TextGenerationError) {
      return jsonResponse(
        { error: "Falha ao gerar a resposta." },
        statusForError(error),
      );
    }
    return jsonResponse({ error: "Falha ao gerar a resposta." }, 502);
  }
});
