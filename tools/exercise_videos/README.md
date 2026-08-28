# Download de vídeos de exercício (Pexels)

Script utilitário, **local e offline**, para baixar candidatos de vídeo de
estoque (gratuitos para uso comercial) de cada exercício já seedado no app,
via a API da [Pexels](https://www.pexels.com/api/). Não faz parte do app
Flutter — não precisa de build/APK depois de rodar.

Isso substitui a geração de vídeo por IA sob demanda (que tem custo
recorrente por chamada) por uma biblioteca pré-baixada, escolhida uma vez.
A etapa seguinte (hospedar os vídeos escolhidos e o app consumi-los) é um
marco separado, feito depois que os candidatos aqui forem revisados.

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
   nada para aparelhos bem específicos de academia).

## Licença dos vídeos da Pexels

Todo conteúdo da Pexels é gratuito para uso pessoal e comercial, sem
exigência de atribuição, incluindo redistribuição dentro de um app — mas os
termos proíbem "cópia em massa ou sistemática" do catálogo sem permissão
explícita. Este script fica claramente dentro do uso normal da API: uma
busca pontual por exercício (não uma varredura do catálogo inteiro), com
pausa entre chamadas, resultando em bem menos que 100 requisições no total.

## Fora de escopo deste script

- Comprimir/recortar os `chosen.mp4` (ex.: via `ffmpeg`).
- Subir os vídeos escolhidos para hospedagem (ex.: Supabase Storage).
- Qualquer mudança no app Flutter para consumir esses vídeos.

Esses passos ficam para um marco seguinte, depois que os candidatos aqui
forem revisados e escolhidos.
