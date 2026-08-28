import { z } from "npm:zod@^4.0.0";

import { ChatMessage as ProviderChatMessage } from "../_shared/providers/text_generation_provider.ts";

// The public request uses "assistant" (the term every chat API/UI already
// uses) rather than Gemini's "model" — toProviderMessages below is the one
// place that translates between the two, so the provider abstraction
// (_shared/providers) never has to know about this endpoint's naming.
export const ChatMessageSchema = z.object({
  role: z.enum(["user", "assistant"]),
  content: z.string().min(1).max(4000),
});

export const RequestSchema = z.object({
  messages: z.array(ChatMessageSchema).min(1).max(30),
  profile: z.object({
    goal: z.string().nullable(),
    experienceLevel: z.string().nullable(),
  }).nullable(),
  // A short, already-summarized description of the user's recent activity
  // (session frequency, latest weigh-in) — built client-side from the local
  // database (see AiCoachRepository.buildContext in the Flutter app), never
  // a raw data dump, to keep the prompt small and avoid sending more of the
  // user's history than a coaching reply needs.
  activitySummary: z.string().nullable(),
});

export type ChatRequest = z.infer<typeof RequestSchema>;

/**
 * Appends an optional "Contexto do usuário" section to SYSTEM_PROMPT when
 * `profile`/`activitySummary` are present — kept as a separate function
 * (rather than always baked into SYSTEM_PROMPT) so the base persona/rules
 * stay testable on their own and the context section is easy to omit for a
 * user who hasn't set a goal or logged anything yet.
 */
export function buildSystemPrompt(
  profile: ChatRequest["profile"],
  activitySummary: ChatRequest["activitySummary"],
): string {
  const contextLines: string[] = [];
  if (profile?.goal) contextLines.push(`Objetivo: ${profile.goal}`);
  if (profile?.experienceLevel) {
    contextLines.push(`Nível de experiência: ${profile.experienceLevel}`);
  }
  if (activitySummary) contextLines.push(activitySummary);

  if (contextLines.length === 0) return SYSTEM_PROMPT;

  return `${SYSTEM_PROMPT}\n\nContexto do usuário:\n${
    contextLines.join("\n")
  }`;
}

/** Maps the public `"assistant"` role to the provider's `"model"` role —
 * the only translation needed between this endpoint's request shape and
 * `TextGenerationProvider.generateText`'s `ChatMessage[]`. */
export function toProviderMessages(
  messages: ChatRequest["messages"],
): ProviderChatMessage[] {
  return messages.map((message) => ({
    role: message.role === "assistant" ? "model" : "user",
    content: message.content,
  }));
}

// Concrete guardrails rather than a vague "seja útil e amigável" — each
// rule maps to a real failure mode a fitness/nutrition chatbot can hit:
//  - no diagnosis/prescription is the one hard safety boundary — this app
//    has no way to know about an injury, medication, or condition beyond
//    what the user types, so deferring to a real professional is the only
//    responsible default;
//  - staying on-topic keeps the "especialista" framing honest instead of
//    the model quietly answering unrelated questions;
//  - short/actionable replies match how someone actually wants coaching
//    advice on a phone, not a wall of text.
export const SYSTEM_PROMPT =
  "Você é um coach especializado em treino, vida fit e nutrição, parte de " +
  "um app de academia. Converse em português do Brasil, de forma direta, " +
  "prática e motivadora.\n\n" +
  "Regras obrigatórias:\n" +
  "1. Nunca diagnostique condições médicas, nunca prescreva medicação ou " +
  "suplementação específica. Para dor, lesão ou qualquer condição de " +
  "saúde, sempre recomende procurar um médico ou nutricionista.\n" +
  "2. Mantenha o foco em treino, nutrição, recuperação e hábitos " +
  "saudáveis. Para perguntas fora desse escopo, recuse educadamente e " +
  "traga a conversa de volta para esses temas.\n" +
  "3. Respostas curtas e práticas (poucos parágrafos ou uma lista curta) " +
  "— evite textos longos demais para ler no celular.\n" +
  "4. Quando o contexto do usuário (objetivo, nível, atividade recente, " +
  "peso) estiver disponível, use-o para personalizar a resposta em vez de " +
  "dar conselhos genéricos.";
