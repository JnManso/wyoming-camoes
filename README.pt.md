# wyoming-camoes

Reconhecimento de voz em **português europeu** para o Home Assistant: o modelo Whisper
[CAMÕES](https://huggingface.co/amalia-llm/CAMOES-whisper-asr) do projecto [AMALIA](https://amaliallm.pt), servido pelo
servidor oficial [wyoming-faster-whisper](https://github.com/OHF-Voice/wyoming-faster-whisper) através do protocolo
[Wyoming](https://github.com/OHF-Voice/wyoming).

[English](README.md)

## O que é

O Whisper genérico tende para o português do Brasil. O CAMÕES é o Whisper large-v3 afinado para português europeu: onde
o large-v3 original ouviu *estores* como *toques*, *torres* ou *estouros*, o CAMÕES acertou em todas as frases de
teste.

Esta imagem é o servidor oficial (`rhasspy/wyoming-whisper:3.8.1`) com duas adições:

- **Primeiro arranque**: descarrega o CAMÕES do Hugging Face, converte-o para CTranslate2 int8 com o conversor que a
  imagem já traz e guarda apenas o modelo convertido (1,5 GB) no volume `/data`. Os arranques seguintes demoram
  segundos.
- **Sem timestamps**: com timestamps (a predefinição do faster-whisper), o CAMÕES escreve lixo antes da primeira
  palavra. Um argumento é acrescentado ao ficheiro do servidor durante o build
  ([`patches/without_timestamps.py`](patches/without_timestamps.py)).

Predefinições: português, int8, beam size 1.

## Início rápido

```bash
git clone https://github.com/jnmanso/wyoming-camoes.git
cd wyoming-camoes
docker build -t wyoming-camoes .
docker run -d --name wyoming-camoes -p 10300:10300 -v wyoming-camoes:/data \
  -e WYO_WHISPER_CPU_THREADS=8 --restart unless-stopped wyoming-camoes
```

Ou copie [`compose.example.yaml`](compose.example.yaml) para `compose.yaml` e execute `docker compose up -d`.

O primeiro arranque descarrega cerca de 6 GB e precisa de 8 GB de RAM livres durante a conversão. Aguarde pelo
`INFO:__main__:Ready` em `docker logs -f wyoming-camoes`.

## Ligar ao Home Assistant

1. **Settings → Devices & services → Add integration → Wyoming Protocol**, com o IP do servidor e a porta `10300`.
2. **Settings → Voice assistants** → o seu assistente → **Speech-to-text**: a nova entidade, língua `pt`.

⚠️ O Wyoming não tem autenticação: quem chegar à porta 10300 pode usar o servidor. Restrinja a porta ao endereço do
Home Assistant. As portas publicadas pelo Docker contornam firewalls do anfitrião como o `ufw`; com `--network host`
aplica-se a firewall do anfitrião.

## Configuração

Cada opção do servidor `--alguma-opcao` pode ser definida pela variável `WYO_WHISPER_ALGUMA_OPCAO`; os argumentos da
linha de comandos têm prioridade sobre as variáveis.

| Variável | Predefinição | Para quê |
|---|---|---|
| `WYO_WHISPER_CPU_THREADS` | `4` | threads de CPU para a inferência |
| `WYO_WHISPER_URI` | `tcp://0.0.0.0:10300` | endereço de escuta; o healthcheck segue esta variável, não um argumento `--uri` |
| `WYO_WHISPER_BEAM_SIZE` | `1` | beam size |
| `WYO_WHISPER_LANGUAGE` | `pt` | língua |
| `WYO_WHISPER_COMPUTE_TYPE` | `int8` | tipo de cálculo do CTranslate2 |

Variáveis do primeiro arranque:

| Variável | Predefinição | Para quê |
|---|---|---|
| `CAMOES_SOURCE` | `amalia-llm/CAMOES-whisper-asr` | repositório do modelo no Hugging Face |
| `CAMOES_QUANTIZATION` | `int8` | quantização da conversão |
| `CAMOES_MODEL_DIR` | `/data/camoes-ct2-<quantização>` | onde fica o modelo convertido |
| `CAMOES_PREPROCESSOR_SOURCE` | `openai/whisper-large-v3` | modelo base; origem do tokenizer e da configuração do pré-processador |
| `CAMOES_KEEP_SOURCE` | `0` | `1` mantém os pesos descarregados em `/data/hub` |

## Medições

Ryzen 9 9900X, 12 threads, 2026-10:

- Cerca de 2 s por comando de voz curto, ida e volta pelo Home Assistant.
- Memória: 1,6 GiB com o modelo carregado, até 2,3 GiB a transcrever; pico de 7 GiB na conversão do primeiro
  arranque.
- Primeiro arranque: cerca de um minuto numa ligação rápida, a maior parte no download de 6 GB.

A imagem é construída para `amd64` e `arm64`; só a `amd64` foi testada.

## Actualizar

- **Versão nova do servidor oficial**: altere `WYOMING_WHISPER_VERSION` no [Dockerfile](Dockerfile) e reconstrua. O
  build volta a acrescentar o `without_timestamps` ao ficheiro da versão nova; pára com uma mensagem se o ficheiro mudou
  e o patch já não encaixa, e não faz nada se a versão nova já passar a opção.
- **Teste o primeiro arranque** com um volume vazio antes de trocar, porque a conversão depende das versões do
  transformers e do CTranslate2 da imagem:

  ```bash
  docker run --rm -p 10301:10300 wyoming-camoes
  ```

  Aguarde pelo `INFO:__main__:Ready`.
- **Trocar**: `docker compose up -d` com a imagem nova. O volume guarda o modelo convertido: nada é descarregado ou
  convertido outra vez.
- **Versão nova do CAMÕES**: apague o modelo convertido e reinicie; o arranque seguinte converte de novo (6 GB de
  download, 8 GB de RAM):

  ```bash
  docker run --rm -v wyoming-camoes:/data --entrypoint rm wyoming-camoes -rf /data/camoes-ct2-int8
  ```

- **Publicar** (quem mantém o repositório): uma tag `vX.Y.Z` faz o [workflow](.github/workflows/image.yml) construir as
  duas arquitecturas e enviá-las para o `ghcr.io`.

## Licença e créditos

O código deste repositório (Dockerfile, entrypoint, patch, documentação) é [MIT](LICENSE). A imagem de base é a do
wyoming-faster-whisper, MIT. Ver [THIRD_PARTY.md](THIRD_PARTY.md).

⚠️ **O cartão do modelo CAMÕES não declara licença** (verificado a 2026-10-16). Por isso a imagem **nunca inclui os
pesos**: é o seu contentor que os descarrega do Hugging Face no primeiro arranque. O cartão indica como usos previstos
a transcrição de português europeu, investigação e avaliação de ASR, demonstrações e protótipos; para outros usos,
confirme os termos com os autores.

O CAMÕES é do projecto AMALIA e do benchmark CAMÕES (ASRU 2025) — a citação está no
[cartão do modelo](https://huggingface.co/amalia-llm/CAMOES-whisper-asr). Este projecto não é afiliado ao AMALIA, à Open
Home Foundation nem à OpenAI.
