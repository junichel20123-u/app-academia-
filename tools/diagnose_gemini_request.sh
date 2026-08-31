#!/usr/bin/env bash
#
# Descobre, em UMA execucao, tudo que ainda nao sabemos sobre por que a
# Edge Function nao consegue gerar um plano.
#
# Existe porque o ambiente onde este codigo e desenvolvido nao alcanca uma
# chave valida do Gemini: sem isto, cada hipotese so pode ser testada com
# um deploy + teste manual, que foi exatamente o ciclo que travou a
# depuracao deste bug. Aqui a chave real fala com o Google direto, fora do
# app, e cada etapa isola uma variavel:
#
#   0. qual header autentica esta chave (os dois formatos nao sao
#      intercambiaveis, e o app so pode mandar um)
#   1. quais modelos esta chave enxerga
#   2. qual campo do corpo, se algum, e recusado
#   3. se thinkingConfig e aceito (corta latencia quando e)
#
# Cada chamada mostra o tempo decorrido — e o que responde se o timeout
# de 60s da funcao e suficiente.
#
# Uso:
#   export GEMINI_KEY=<a chave, do jeito que esta no secret do Supabase>
#   bash tools/diagnose_gemini_request.sh
#
# A chave nunca aparece na saida: o resultado pode ser colado inteiro.
set -u

if [ -z "${GEMINI_KEY:-}" ]; then
  echo "Defina GEMINI_KEY antes de rodar:" >&2
  echo "  export GEMINI_KEY=sua-chave    (cole a chave no lugar de 'sua-chave')" >&2
  exit 1
fi

# O free tier do Gemini tem um limite baixo de requisicoes por minuto, e
# este script faz mais de dez chamadas. Sem pausa, as ultimas voltam todas
# com 429 RESOURCE_EXHAUSTED e a execucao inteira vira ruido — foi o que
# aconteceu na primeira vez que a secao 4 rodou. PAUSA e o intervalo entre
# chamadas; SO permite rodar uma secao isolada, sem gastar cota repetindo
# etapas ja respondidas (ex.: SO=4 bash tools/diagnose_gemini_request.sh).
PAUSA="${PAUSA:-7}"
SO="${SO:-tudo}"
MODEL="${GEMINI_MODEL:-gemini-3.6-flash}"
BASE="https://generativelanguage.googleapis.com/v1beta"
URL="$BASE/models/$MODEL:generateContent"
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT

# Resume uma resposta da API em uma linha, sem vazar nada sensivel.
summarize() {
  python3 -c '
import json, os, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    print("resposta nao-JSON:", raw[:80]); raise SystemExit
if "error" in d:
    e = d["error"]
    reason = (e.get("details") or [{}])[0].get("reason", "-")
    extra = " <- cota por minuto estourada, espere e repita" if e.get("code") == 429 else ""
    detalhe = (e.get("message") or "")[:70] if os.environ.get("VERBOSO") else ""
    print("ERRO", e.get("code"), e.get("status"), reason, detalhe, extra)
else:
    c = (d.get("candidates") or [{}])[0]
    parts = c.get("content", {}).get("parts", [])
    text = "".join(p.get("text", "") for p in parts)
    print("OK  finishReason=" + str(c.get("finishReason")),
          "| caracteres de texto:", len(text))
'
}

# Faz uma chamada cronometrada e imprime "<rotulo> -> <resumo> (<N>s)".
call() {
  local label="$1" header="$2" body_file="$3"
  local start end out
  sleep "$PAUSA"
  start=$(date +%s)
  out=$(curl -sS -m 120 -X POST "$URL" \
        -H "Content-Type: application/json" \
        -H "$header" \
        -d @"$body_file" 2>&1)
  end=$(date +%s)
  printf '%s -> %s (%ss)\n' "$label" "$(printf '%s' "$out" | summarize)" \
    "$((end - start))"
}

# Monta todos os corpos de requisicao de uma vez. O schema reproduz o que
# generate-plan/plan.ts gera para 5 dias e um catalogo de 78 exercicios.
python3 - "$DIR" <<'PY'
import json, os, sys
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
contents = [{"parts": [{"text": "Monte um plano de treino de 5 dias usando apenas os exercicios da lista."}]}]
sysi = {"parts": [{"text": "Voce e um treinador de musculacao. Responda apenas com JSON."}]}
full = {"responseMimeType": "application/json", "responseJsonSchema": schema, "temperature": 0.4}

bodies = {
    "ping": {"contents": [{"parts": [{"text": "oi"}]}]},
    "v1": {"contents": contents},
    "v2": {"contents": contents, "generationConfig": {"responseMimeType": "application/json"}},
    "v3": {"contents": contents, "generationConfig": {k: full[k] for k in ("responseMimeType", "responseJsonSchema")}},
    "v4": {"contents": contents, "generationConfig": full},
    "v5": {"contents": contents, "systemInstruction": sysi, "generationConfig": full},
    "v6": {"contents": contents, "systemInstruction": sysi,
           "generationConfig": {**full, "thinkingConfig": {"thinkingLevel": "low"}}},
}

# Bissecao do schema: a etapa 2 mostra que responseJsonSchema e recusado,
# mas nao QUAL construcao dentro dele. Cada variante abaixo acrescenta uma
# unica construcao ao schema trivial, entao a primeira que falhar e a
# culpada. A ultima testa o campo legado responseSchema como alternativa.
trivial = {"type": "object", "properties": {"nome": {"type": "string"}},
           "required": ["nome"]}

def com(**extra):
    base = json.loads(json.dumps(trivial))
    base.update(extra)
    return base

schema_variants = {
    "s1": ("schema trivial              ", {"responseJsonSchema": trivial}),
    "s2": ("+ additionalProperties:false", {"responseJsonSchema": com(additionalProperties=False)}),
    "s3": ("+ array minItems/maxItems   ", {"responseJsonSchema": com(properties={
        "nome": {"type": "string"},
        "lista": {"type": "array", "minItems": 1, "maxItems": 3, "items": {"type": "string"}}})}),
    "s4": ("+ enum com 78 valores       ", {"responseJsonSchema": com(properties={
        "nome": {"type": "string"}, "slug": {"type": "string", "enum": slugs}})}),
    "s5": ("+ anyOf com null            ", {"responseJsonSchema": com(properties={
        "nome": {"type": "string"},
        "reps": {"anyOf": [{"type": "integer"}, {"type": "null"}]}})}),
    "s6": ("+ minimum/maximum           ", {"responseJsonSchema": com(properties={
        "nome": {"type": "string"},
        "series": {"type": "integer", "minimum": 1, "maximum": 8}})}),
    "s7": ("responseSchema legado (OpenAPI)", {"responseSchema": {
        "type": "OBJECT", "properties": {"nome": {"type": "STRING"}}, "required": ["nome"]}}),
}
# Bissecao do schema REAL: a secao 4 mostrou que nenhuma construcao
# isolada e recusada, entao a causa esta na combinacao — o schema de
# plan.ts tem cinco niveis (objeto > array > objeto > array > objeto) com
# o enum no fundo, enquanto a secao 4 so testou profundidade 2. Estas
# variantes crescem ate a forma real, uma camada por vez.
def plano(exercicio_props, exercicio_required):
    return {
        "type": "object",
        "properties": {"workouts": {
            "type": "array", "minItems": 5, "maxItems": 5,
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "exercises": {
                        "type": "array", "minItems": 1, "maxItems": 12,
                        "items": {"type": "object",
                                  "properties": exercicio_props,
                                  "required": exercicio_required,
                                  "additionalProperties": False}},
                },
                "required": ["name", "exercises"], "additionalProperties": False}}},
        "required": ["workouts"], "additionalProperties": False,
    }

real_variants = {
    "r1": ("aninhado, slug texto simples", plano({"exerciseSlug": {"type": "string"}}, ["exerciseSlug"])),
    "r2": ("+ enum de 78 no fundo      ", plano({"exerciseSlug": {"type": "string", "enum": slugs}}, ["exerciseSlug"])),
    "r3": ("+ inteiros com bounds      ", plano({
        "exerciseSlug": {"type": "string", "enum": slugs},
        "targetSets": {"type": "integer", "minimum": 1, "maximum": 8}},
        ["exerciseSlug", "targetSets"])),
    "r4": ("= schema real completo     ", plano({
        "exerciseSlug": {"type": "string", "enum": slugs},
        "targetSets": {"type": "integer", "minimum": 1, "maximum": 8},
        "targetReps": {"anyOf": [{"type": "integer", "minimum": 1, "maximum": 50}, {"type": "null"}]},
        "targetRestSeconds": {"anyOf": [{"type": "integer", "minimum": 10, "maximum": 600}, {"type": "null"}]},
        "notes": {"anyOf": [{"type": "string"}, {"type": "null"}]}},
        ["exerciseSlug", "targetSets", "targetReps", "targetRestSeconds", "notes"])),
}
for name, (_, sch) in real_variants.items():
    json.dump({"contents": contents,
               "generationConfig": {"responseMimeType": "application/json",
                                    "responseJsonSchema": sch}},
              open(os.path.join(d, name + ".json"), "w"))
open(os.path.join(d, "real_labels.txt"), "w").write(
    "\n".join(f"{k}\t{v[0]}" for k, v in real_variants.items()) + "\n")

for name, (_, cfg) in schema_variants.items():
    json.dump({"contents": [{"parts": [{"text": "Devolva um objeto com o campo nome."}]}],
               "generationConfig": {"responseMimeType": "application/json", **cfg}},
              open(os.path.join(d, name + ".json"), "w"))
open(os.path.join(d, "schema_labels.txt"), "w").write(
    "\n".join(f"{k}\t{v[0]}" for k, v in schema_variants.items()) + "\n")
for name, body in bodies.items():
    json.dump(body, open(os.path.join(d, name + ".json"), "w"))
PY

echo "modelo alvo: $MODEL"
echo

# Uma chave truncada ou com espaco/quebra de linha grudada na copia falha
# com a MESMA mensagem de uma chave bloqueada, entao vale conferir a forma
# antes de culpar o projeto do Google. Nada aqui revela a chave: so o
# tamanho, o prefixo (que e igual para todas) e se ha lixo invisivel.
echo "== credencial (conferencia de forma, nada sensivel)"
printf '   tamanho: %s caracteres\n' "${#GEMINI_KEY}"
printf '   prefixo: %s...\n' "$(printf '%s' "$GEMINI_KEY" | cut -c1-5)"
case "$GEMINI_KEY" in
  *[[:space:]]*) echo "   ATENCAO: contem espaco ou quebra de linha — provavelmente lixo da copia" ;;
  *)             echo "   sem espacos ou quebras de linha" ;;
esac
echo

# Definidos fora do bloco da secao 0: as etapas seguintes tambem os usam
# quando so uma secao e pedida.
H_KEY="x-goog-api-key: $GEMINI_KEY"
H_BEARER="Authorization: Bearer $GEMINI_KEY"

if [ "$SO" = "tudo" ] || [ "$SO" = "0" ]; then
echo "== 0. Autenticacao — qual header esta chave aceita"
# Os dois formatos de chave do Gemini nao sao intercambiaveis entre
# headers, e a funcao so pode mandar um. Testar os dois aqui e o que
# evita concluir errado a partir de uma escolha feita por prefixo.
call "   x-goog-api-key       " "$H_KEY"    "$DIR/ping.json"
call "   Authorization: Bearer" "$H_BEARER" "$DIR/ping.json"
fi

# Segue com o header que autenticou, para as etapas seguintes medirem o
# corpo e nao a autenticacao.
# Com uma secao isolada, nao vale gastar cota re-descobrindo o header:
# ja sabemos, por teste com chave valida, que e x-goog-api-key.
WORKING=""
if [ "$SO" != "tudo" ]; then
  WORKING="$H_KEY"
else
for h in "$H_KEY" "$H_BEARER"; do
  if curl -sS -m 60 -X POST "$URL" -H "Content-Type: application/json" \
       -H "$h" -d @"$DIR/ping.json" | grep -q '"candidates"'; then
    WORKING="$h"
    break
  fi
done
fi

echo
if [ -n "$WORKING" ]; then
  echo "header que autenticou: ${WORKING%%:*}"
fi
echo

if [ "$SO" = "tudo" ] || [ "$SO" = "1" ]; then
echo "== 1. Modelos que esta chave enxerga"
# Roda mesmo quando generateContent falhou: e outro metodo da mesma API,
# entao um sucesso aqui provaria que a chave e valida e o bloqueio e
# especifico do metodo, enquanto uma falha igual aponta para a chave em si.
for h in "$H_KEY" "$H_BEARER"; do
  printf '   via %-22s -> ' "${h%%:*}"
  curl -sS -m 60 "$BASE/models" -H "$h" | MODEL="$MODEL" python3 -c '
import json, os, sys
alvo = os.environ["MODEL"]
try:
    d = json.load(sys.stdin)
except Exception:
    print("resposta nao-JSON"); raise SystemExit
if "error" in d:
    e = d["error"]
    reason = (e.get("details") or [{}])[0].get("reason", "-")
    print("ERRO", e.get("code"), e.get("status"), reason)
    raise SystemExit
nomes = [m.get("name", "").split("/")[-1] for m in d.get("models", [])]
flash = sorted(n for n in nomes if "flash" in n)
print(len(nomes), "modelos |", alvo, "disponivel?",
      "SIM" if alvo in nomes else "NAO", "| flash:",
      ", ".join(flash[:6]) if flash else "(nenhum)")
'
done
fi
echo

if [ -z "$WORKING" ]; then
  echo "Nenhum header autenticou em generateContent. Se a listagem de"
  echo "modelos acima tambem falhou, a chave nao esta sendo reconhecida"
  echo "(copia incompleta, ou chave de outro projeto). Se a listagem"
  echo "funcionou, a chave e valida e o bloqueio e especifico — restricao"
  echo "de API na chave, ou a Generative Language API desabilitada no"
  echo "projeto. As etapas 2-3 foram puladas."
  exit 0
fi

if [ "$SO" = "tudo" ] || [ "$SO" = "2" ]; then
echo "== 2. Corpo da requisicao, campo a campo (o tempo importa tanto quanto o status)"
call "   1 minimo                     " "$WORKING" "$DIR/v1.json"
call "   2 + responseMimeType         " "$WORKING" "$DIR/v2.json"
call "   3 + responseJsonSchema       " "$WORKING" "$DIR/v3.json"
call "   4 + temperature              " "$WORKING" "$DIR/v4.json"
call "   5 + systemInstruction (= hoje)" "$WORKING" "$DIR/v5.json"
fi
echo

if [ "$SO" = "tudo" ] || [ "$SO" = "3" ]; then
echo "== 3. Extra — thinkingConfig corta latencia ou e recusado?"
call "   6 = 5 + thinkingLevel low    " "$WORKING" "$DIR/v6.json"
fi

echo
if [ "$SO" = "tudo" ] || [ "$SO" = "4" ]; then
echo "== 4. Bissecao do schema — qual construcao o Gemini recusa"
# A etapa 2 prova que responseJsonSchema e recusado; esta etapa diz por
# que. Cada linha acrescenta UMA construcao a um schema trivial que
# funciona, entao a primeira falha aponta exatamente o que remover.
while IFS=$'\t' read -r file label; do
  call "   $label" "$WORKING" "$DIR/$file.json"
done < "$DIR/schema_labels.txt"
fi

if [ "$SO" = "tudo" ] || [ "$SO" = "5" ]; then
echo
echo "== 5. Bissecao do schema REAL — em qual camada ele quebra"
# A secao 4 provou que nenhuma construcao isolada e recusada. Estas
# variantes montam a forma real de plan.ts camada por camada, entao a
# primeira falha diz o que a combinacao tem de demais.
while IFS=$'\t' read -r file label; do
  VERBOSO=1 call "   $label" "$WORKING" "$DIR/$file.json"
done < "$DIR/real_labels.txt"
fi
