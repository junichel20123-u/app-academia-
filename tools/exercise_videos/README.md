# Vídeos de exercício: busca, download e upload (Pexels + Supabase Storage)

Scripts utilitários, **locais**, para montar a biblioteca de vídeos
ilustrativos de execução de exercícios: buscar/baixar candidatos gratuitos
da Pexels, e depois subir os escolhidos pro Supabase Storage, de onde o app
os consome. Nenhum dos dois faz parte do app Flutter em si — não precisam
de build/APK pra rodar (só o app consumindo os vídeos já hospedados precisa
de um novo build).

Isso substitui a geração de vídeo por IA sob demanda (que tem custo
recorrente por chamada) por uma biblioteca pré-baixada, escolhida uma vez e
hospedada estaticamente.

## Passo a passo

1. **Crie uma chave de API grátis**: acesse
   [pexels.com/api](https://www.pexels.com/api/), crie uma conta (não pede
   cartão de crédito) e copie a chave gerada.

2. **Instale as dependências** (Python 3.10+):

   ```bash
   cd tools/exercise_videos
   pip install -r requirements.txt
   ```

3. **Exporte sua chave** (nunca cole a chave em nenhum arquivo commitado):

   ```bash
   export PEXELS_API_KEY=sua-chave-aqui
   ```

4. **Rode o script**:

   ```bash
   python search_and_download.py
   ```

   Para cada um dos ~69 exercícios já seedados no app, o script busca até 3
   vídeos candidatos e baixa a renderização de qualidade `hd` de cada um em
   `output/<slug-do-exercicio>/candidate_1.mp4`, `candidate_2.mp4`,
   `candidate_3.mp4` (mais um `.meta.json` por candidato, com o id/link/nome
   do fotógrafo na Pexels). Exercícios sem nenhum resultado relevante ficam
   listados em `output/_sem_resultado.txt` para busca manual depois.

   Leva uns minutos (pausa de ~1.5s entre exercícios, de propósito — bem
   abaixo do limite de 200 requisições/hora da API). **Pode ser interrompido
   e rodado de novo a qualquer momento**: qualquer pasta que já tenha um
   `candidate_*.mp4` é pulada, então retomar não duplica nem gasta cota à
   toa.

5. **Revise os candidatos**: abra cada pasta em `output/<slug>/`, assista os
   candidatos e renomeie o melhor para `chosen.mp4`. Exercícios em
   `_sem_resultado.txt` precisam de uma busca manual direta no site da
   Pexels (o termo de busca em inglês gerado automaticamente pode não achar
   nada para aparelhos bem específicos de academia). Não precisa ter
   `chosen.mp4` em 100% das pastas — um exercício sem vídeo escolhido
   simplesmente não terá vídeo no app (fallback gracioso já existente).

6. **Suba os vídeos escolhidos pro Supabase Storage**: precisa de um projeto
   Supabase já criado (mesmo usado pelo catálogo/montador de IA) com a
   migration `supabase/migrations/..._create_exercise_videos_bucket.sql`
   aplicada (`supabase db push`), e a **service_role key** do projeto
   (Project Settings → API Keys — não é a `anon`/`publishable`; essa chave
   ignora RLS e nunca deve ser colada no chat nem commitada):

   ```bash
   export SUPABASE_URL=https://<seu-project-ref>.supabase.co
   export SUPABASE_SERVICE_ROLE_KEY=sua-service-role-key

   python upload_to_supabase.py
   ```

   Sobe cada `output/<slug>/chosen.mp4` existente pro bucket público
   `exercise-videos`, em `exercise-videos/<slug>.mp4`. Reexecutável sem
   duplicar (usa upsert — sobrescreve com o arquivo local atual). O app
   Flutter (feature `video_generation`) já sabe verificar e tocar um vídeo
   hospedado aqui automaticamente, com prioridade sobre a geração por IA.

## Licença dos vídeos da Pexels

Todo conteúdo da Pexels é gratuito para uso pessoal e comercial, sem
exigência de atribuição, incluindo redistribuição dentro de um app — mas os
termos proíbem "cópia em massa ou sistemática" do catálogo sem permissão
explícita. Este script fica claramente dentro do uso normal da API: uma
busca pontual por exercício (não uma varredura do catálogo inteiro), com
pausa entre chamadas, resultando em bem menos que 100 requisições no total.

## Fora de escopo destes scripts

- Comprimir/recortar os `chosen.mp4` (ex.: via `ffmpeg`) antes do upload.

O app Flutter consumindo os vídeos hospedados (`StockVideoProvider` em
`lib/features/video_generation/data/`) já está implementado e não precisa
de nenhum passo manual adicional além do upload acima.
