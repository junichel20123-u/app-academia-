#!/usr/bin/env bash
#
# Isola qual parte do corpo da requisicao a API do Gemini esta recusando.
#
# Existe porque a Edge Function so consegue registrar o que o Google
# devolve, e o Google responde "Request contains an invalid argument."
# sem dizer qual argumento. Este script sobe a requisicao campo a campo,
# da forma minima ate a forma exata que generate-plan monta hoje, e
# imprime so o status de cada uma — a primeira que falhar aponta o campo.
#
# Uso:
#   export GEMINI_KEY=<a chave que comeca com AIzaSy>
#   bash tools/diagnose_gemini_request.sh
#
# A chave nunca aparece na saida, entao o resultado pode ser colado inteiro.
set -u

if [ -z "${GEMINI_KEY:-}" ]; then
  echo "Defina GEMINI_KEY antes de rodar: export GEMINI_KEY=AIzaSy..." >&2
  exit 1
fi
# Cada formato de chave so autentica no seu proprio header: as novas
# "Auth keys" (AQ.Ab...) vao em Authorization: Bearer, as antigas
# "Standard keys" (AIza...) vao em x-goog-api-key. Trocar os dois da
# 401 ACCESS_TOKEN_TYPE_UNSUPPORTED por mais valida que a chave seja.
case "$GEMINI_KEY" in
  AQ.*) AUTH_HEADER="Authorization: Bearer $GEMINI_KEY"; FORMATO="AQ (auth key)" ;;
  *)    AUTH_HEADER="x-goog-api-key: $GEMINI_KEY";       FORMATO="AIza (standard key)" ;;
esac

MODEL="${GEMINI_MODEL:-gemini-3.6-flash}"
URL="https://generativelanguage.googleapis.com/v1beta/models/$MODEL:generateContent"
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT

echo "modelo: $MODEL"
echo "formato da chave: $FORMATO"
echo

# Reproduz o schema que generate-plan/plan.ts gera (5 dias, 78 exercicios).
python3 - "$DIR" <<'PY'
import json, sys, os
d = sys.argv[1]
slugs = [f"exercicio-{i+1}" for i in range(78)]
entry = {
  "type": "object",
  "properties": {
    "exerciseSlug": {"type": "string", "enum": slugs},
    "targetSets": {"type": "integer", "minimum": 1, "maximum": 8},
    "targetReps": {"anyOf": [{"type": "integer", "minimum": 1, "maximum": 50}, {"type": "null"}]},
    "targetRestSeconds": {"anyOf": [{"type": "integer", "minimum": 10, "maximum": 600}, {"type": "null"}]},
    "notes": {"anyOf": [{"type": "string"}, {"type": "null"}]},
  },
  "required": ["exerciseSlug", "targetSets", "targetReps", "targetRestSeconds", "notes"],
  "additionalProperties": False,
}
schema = {
  "type": "object",
  "properties": {"workouts": {"minItems": 5, "maxItems": 5, "type": "array", "items": {
      "type": "object",
      "properties": {"name": {"type": "string"},
                     "exercises": {"minItems": 1, "maxItems": 12, "type": "array", "items": entry}},
      "required": ["name", "exercises"], "additionalProperties": False}}},
  "required": ["workouts"], "additionalProperties": False,
}
contents = [{"parts": [{"text": "Monte um plano de 5 dias com os exercicios da lista."}]}]
sysi = {"parts": [{"text": "Voce e um treinador. Responda apenas com JSON."}]}
full = {"responseMimeType": "application/json", "responseJsonSchema": schema, "temperature": 0.4}

variants = [
  ("1 minimo (so contents)        ", {"contents": contents}),
  ("2 + responseMimeType          ", {"contents": contents, "generationConfig": {"responseMimeType": "application/json"}}),
  ("3 + responseJsonSchema        ", {"contents": contents, "generationConfig": {k: full[k] for k in ("responseMimeType", "responseJsonSchema")}}),
  ("4 + temperature               ", {"contents": contents, "generationConfig": full}),
  ("5 + systemInstruction (= hoje)", {"contents": contents, "systemInstruction": sysi, "generationConfig": full}),
]
names = []
for i, (label, body) in enumerate(variants):
    json.dump(body, open(os.path.join(d, f"body{i}.json"), "w"))
    names.append(label)
open(os.path.join(d, "labels.txt"), "w").write("\n".join(names) + "\n")
PY

i=0
while IFS= read -r label; do
  out=$(curl -sS -m 90 -X POST "$URL" \
        -H "Content-Type: application/json" \
        -H "$AUTH_HEADER" \
        -d @"$DIR/body$i.json")
  printf '%s -> %s\n' "$label" "$(printf '%s' "$out" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("resposta nao-JSON"); raise SystemExit
if "error" in d:
    e = d["error"]
    print("ERRO", e.get("code"), e.get("status"), "|", (e.get("message") or "")[:100])
else:
    c = (d.get("candidates") or [{}])[0]
    parts = c.get("content", {}).get("parts", [])
    print("OK   finishReason=" + str(c.get("finishReason")), "| partes de texto:", len(parts))
')"
  i=$((i + 1))
done < "$DIR/labels.txt"
