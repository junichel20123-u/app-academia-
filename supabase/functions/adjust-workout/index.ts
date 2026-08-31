import {
  buildAdjustJsonSchema,
  buildAdjustSchema,
  buildUserPrompt,
  RequestSchema,
  SYSTEM_PROMPT,
} from "./adjust.ts";
import { GeminiTextGenerationProvider } from "../_shared/providers/gemini_text_generation_provider.ts";
import { TextGenerationError } from "../_shared/providers/text_generation_provider.ts";

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Same taxonomy->status mapping as generate-plan/index.ts.
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

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return jsonResponse(
      { error: "Server misconfigured: missing GEMINI_API_KEY" },
      500,
    );
  }

  const slugs = input.exercises.map((e) => e.slug);
  const provider = new GeminiTextGenerationProvider(
    apiKey,
    Deno.env.get("GEMINI_MODEL") || undefined,
    // Unset by default: gemini-3.6-flash 400s on a thinkingConfig here.
    // See the note in gemini_text_generation_provider.ts.
    Deno.env.get("GEMINI_THINKING_LEVEL") || undefined,
  );

  try {
    const raw = await provider.generateStructured({
      systemPrompt: SYSTEM_PROMPT,
      userPrompt: buildUserPrompt(input),
      jsonSchema: buildAdjustJsonSchema(slugs),
    });

    // Same posture as generate-plan/index.ts: reject the whole proposal
    // rather than salvage a partial one — the schema/enum bounds sent as
    // the required response shape are a safety net, not the primary
    // guarantee, and an on-demand adjustment that comes back malformed
    // should surface as an error, not a silently patched result.
    const parsed = buildAdjustSchema(slugs).safeParse(raw);
    if (!parsed.success) {
      return jsonResponse(
        { error: "A IA não retornou um ajuste válido." },
        502,
      );
    }

    return jsonResponse(parsed.data, 200);
  } catch (error) {
    console.error("adjust-workout error", error);
    if (error instanceof TextGenerationError) {
      // `kind` acompanha a mensagem: e a categoria ja sanitizada do
      // erro (nunca o texto cru do provedor, nunca a chave), e e o que
      // permite ao app dizer o que houve em vez de so ecoar um codigo
      // HTTP — sem isso, cada falha exigia abrir os logs do painel.
      return jsonResponse(
        { error: "Falha ao gerar o ajuste.", kind: error.kind },
        statusForError(error),
      );
    }
    return jsonResponse({ error: "Falha ao gerar o ajuste." }, 502);
  }
});
