import Anthropic from "npm:@anthropic-ai/sdk@^0.120.0";
import { zodOutputFormat } from "npm:@anthropic-ai/sdk@^0.120.0/helpers/zod";
import {
  buildPlanSchema,
  buildUserPrompt,
  RequestSchema,
  SYSTEM_PROMPT,
} from "./plan.ts";

// Configurable without a redeploy — see the app's M15 plan note.
const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5";

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
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

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return jsonResponse(
      { error: "Server misconfigured: missing ANTHROPIC_API_KEY" },
      500,
    );
  }

  const client = new Anthropic({ apiKey });
  const planSchema = buildPlanSchema(
    input.daysPerWeek,
    input.exercises.map((e) => e.slug),
  );

  try {
    const response = await client.messages.parse({
      model: MODEL,
      max_tokens: 4096,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: buildUserPrompt(input) }],
      output_config: { format: zodOutputFormat(planSchema) },
    });

    // A plan with any exerciseSlug outside the closed list, or the wrong
    // number of days, fails Zod validation inside messages.parse() itself
    // (the enum/length constraints are part of planSchema) — parsed_output
    // is null in that case. Reject the whole plan rather than salvage a
    // partial one: unlike the free, curated template catalog (which skips
    // one bad entry and warns), this is a paid, on-demand generation, so a
    // structural failure should be visible, not silently patched over.
    if (!response.parsed_output) {
      return jsonResponse({ error: "A IA não retornou um plano válido." }, 502);
    }

    return jsonResponse(response.parsed_output, 200);
  } catch (error) {
    console.error("generate-plan error", error);
    return jsonResponse({ error: "Falha ao gerar o plano." }, 502);
  }
});
