// Provider abstraction for generative-text calls, analogous to the
// Flutter app's `VideoGenerationProvider`/`ProviderRegistry` (see
// lib/features/video_generation/domain/video_generation_provider.dart) but
// for the Edge Function's server-side LLM calls. The rest of this function
// depends only on this interface, never on a specific vendor SDK — swapping
// providers later (e.g. back to Anthropic, or to Vertex) means adding one
// new file here, not touching index.ts's request/response handling.

/** Coarse failure categories the caller maps to HTTP responses. */
export type TextGenerationErrorKind =
  | "invalid_request"
  | "auth"
  | "rate_limited"
  | "timeout"
  | "unavailable"
  | "invalid_response"
  | "unknown";

export class TextGenerationError extends Error {
  constructor(
    public readonly kind: TextGenerationErrorKind,
    message: string,
    public override readonly cause?: unknown,
  ) {
    super(message);
    this.name = "TextGenerationError";
  }
}

export interface StructuredGenerationRequest {
  systemPrompt: string;
  userPrompt: string;
  /** A JSON Schema object describing the required response shape. */
  jsonSchema: unknown;
}

/** One turn of a chat-style conversation. `"model"` (not `"assistant"`) to
 * match Gemini's own role naming directly — the ai-coach endpoint maps its
 * public `"assistant"` role to this at the boundary, so this provider-facing
 * type never has to know about any one endpoint's public API shape. */
export interface ChatMessage {
  role: "user" | "model";
  content: string;
}

export interface TextGenerationRequest {
  systemPrompt: string;
  /** Full conversation so far, in chronological order, ending with the
   * latest `"user"` turn. */
  messages: ChatMessage[];
}

export interface TextGenerationProvider {
  readonly id: string;
  /**
   * Returns the model's response already parsed as JSON (`unknown` — the
   * caller re-validates it against the same Zod schema the request schema
   * was derived from, exactly like the free template catalog and every
   * other cross-boundary payload in this app). Throws [TextGenerationError]
   * on any request/response/network failure.
   */
  generateStructured(request: StructuredGenerationRequest): Promise<unknown>;

  /**
   * Free-form conversational reply (no response schema) — for the
   * ai-coach chat endpoint, which produces prose, not structured data.
   * Throws [TextGenerationError] on any request/response/network failure.
   */
  generateText(request: TextGenerationRequest): Promise<string>;
}
