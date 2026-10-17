# wyoming-camoes

Speech-to-text in **European Portuguese** for Home Assistant: the [CAMÕES](https://huggingface.co/amalia-llm/CAMOES-whisper-asr)
Whisper model from the [AMALIA](https://amaliallm.pt) project, served over [Wyoming](https://github.com/OHF-Voice/wyoming) by the
official [wyoming-faster-whisper](https://github.com/OHF-Voice/wyoming-faster-whisper) server.

[Português](#português) · [English](#english)

---

## Português

### O que é

O Whisper genérico tende para o português do Brasil (*umidade*, não *humidade*). O CAMÕES é o Whisper large-v3 afinado para
**português europeu**: em seis frases sintéticas com *estores*, o large-v3 original ouviu *toques*, *históricos*, *torres* e
*estouros*, e o CAMÕES ouviu *estores* nas seis.

Esta imagem é a do servidor oficial (`rhasspy/wyoming-whisper:3.8.1`) com duas coisas a mais:

- **no primeiro arranque**, descarrega o CAMÕES do Hugging Face, converte-o para CTranslate2 int8 com o conversor que a imagem já
  traz e guarda só o modelo convertido (1,5 GB) no volume `/data`. Os arranques seguintes demoram segundos;
- **transcreve sem timestamps**: com eles (o padrão do faster-whisper), o CAMÕES escreve lixo antes da primeira palavra
  (*", fechem…"*, *"rar o banheiro…"*). É um argumento acrescentado ao ficheiro do servidor durante o build
  ([`patches/without_timestamps.py`](patches/without_timestamps.py)).

Português por omissão, int8, beam 1 (como no exemplo do próprio cartão do modelo).

### Arranque rápido

```bash
docker run -d --name wyoming-camoes -p 10300:10300 -v wyoming-camoes:/data \
  -e WYO_WHISPER_CPU_THREADS=8 --restart unless-stopped ghcr.io/jnmanso/wyoming-camoes:latest
```

Ou com [`compose.example.yaml`](compose.example.yaml). Para construir a imagem localmente: `docker build -t wyoming-camoes .`

O primeiro arranque descarrega cerca de 6 GB e precisa de **8 GB de RAM livres** durante a conversão; espere pelo
`INFO:__main__:Ready` nos logs (`docker logs -f wyoming-camoes`).

### Ligar ao Home Assistant

1. **Settings → Devices & services → Add integration → Wyoming Protocol** (os menus em inglês), com o IP da máquina e a porta
   `10300`.
2. **Settings → Voice assistants**, no assistente: **Speech-to-text** → a nova entidade, língua `pt`.

⚠️ O Wyoming não tem autenticação: quem chegar à porta 10300 pode usá-la. Limite-a ao endereço do Home Assistant. As portas
publicadas pelo Docker passam ao lado de firewalls como o `ufw`; com `--network host` é o firewall da máquina que decide (é assim
que o autor o corre).

### Configuração

O servidor lê cada opção `--alguma-opcao` da variável `WYO_WHISPER_ALGUMA_OPCAO`; argumentos passados ao `docker run` ganham às
variáveis. As mais úteis:

| Variável | Por omissão | |
|---|---|---|
| `WYO_WHISPER_CPU_THREADS` | `4` | núcleos físicos que lhe quer dar |
| `WYO_WHISPER_URI` | `tcp://0.0.0.0:10300` | outra porta (o healthcheck segue esta variável, não um `--uri`) |
| `WYO_WHISPER_BEAM_SIZE` | `1` | |
| `WYO_WHISPER_LANGUAGE` | `pt` | |
| `WYO_WHISPER_COMPUTE_TYPE` | `int8` | |

E as do primeiro arranque:

| Variável | Por omissão | |
|---|---|---|
| `CAMOES_SOURCE` | `amalia-llm/CAMOES-whisper-asr` | repositório do modelo no Hugging Face |
| `CAMOES_QUANTIZATION` | `int8` | quantização da conversão |
| `CAMOES_MODEL_DIR` | `/data/camoes-ct2-<quantização>` | onde fica o modelo convertido |
| `CAMOES_PREPROCESSOR_SOURCE` | `openai/whisper-large-v3` | o modelo base, de onde vêm o vocabulário e o `preprocessor_config.json` (128 mels) |
| `CAMOES_KEEP_SOURCE` | `0` | `1` guarda os 6 GB descarregados em `/data/hub` |

### Medições

Ryzen 9 9900X, CPU, 12 threads, 2026-10-16:

- **~2 s por comando curto**, ida e volta pelo Home Assistant.
- **Doze frases sintéticas** (seis frases, duas vozes TTS `pt-PT`), directamente pelo Wyoming: 8 de 12 exactas, a voz do Google
  6 de 6, *estores* 6 de 6. O Whisper large-v3 original, nas mesmas: 2 de 12 e *estores* 0 de 6.
- **Memória**: 1,6 GiB com o modelo carregado, até ~2,3 GiB a transcrever; 7 GiB de pico na conversão.
- **Primeiro arranque**: 66 s numa linha de 10 Gbps, cerca de 40 s deles a converter; numa linha mais lenta, pesa o download de
  6 GB.

A imagem é construída para `amd64` e `arm64`; só a `amd64` foi testada. Num Raspberry Pi, um modelo do tamanho do large-v3 deverá
ser lento demais para comandos de voz (não medido).

### Actualizar

- **Versão nova do servidor oficial** (`rhasspy/wyoming-whisper`): muda `WYOMING_WHISPER_VERSION` no
  [Dockerfile](Dockerfile) e reconstrói (`docker build -t wyoming-camoes .`). O build volta a acrescentar o
  `without_timestamps` ao ficheiro da versão nova. Se esse ficheiro tiver mudado e o patch já não encaixar, o build
  pára e diz porquê. Se a versão nova já passar a opção, diz que não há nada a mudar.
- **Antes de trocar**, experimenta o primeiro arranque com um volume vazio, porque é aí que a conversão corre e
  depende das versões do transformers e do CTranslate2 da imagem:
  `docker run --rm -e WYO_WHISPER_URI=tcp://0.0.0.0:10301 -p 10301:10301 wyoming-camoes` — espera pelo
  `INFO:__main__:Ready`.
- **Trocar**: `docker compose up -d` com a imagem nova (`docker compose pull` antes, se usares a publicada). O volume
  guarda o modelo convertido: não volta a descarregar nem a converter.
- **Um CAMÕES novo** (se o AMALIA publicar outra versão): apaga o modelo convertido e reinicia; o arranque seguinte
  converte outra vez (6 GB, 8 GB de RAM):
  `docker run --rm -v wyoming-camoes:/data --entrypoint rm wyoming-camoes -rf /data/camoes-ct2-int8`
- **Publicar** (quem mantém o repositório): uma tag `vX.Y.Z` faz o [workflow](.github/workflows/image.yml)
  construir as duas arquitecturas e enviar para o `ghcr.io`.

### Licença e créditos

O código deste repositório (Dockerfile, entrypoint, patch, documentação) é [MIT](LICENSE). A imagem de base é a do
wyoming-faster-whisper, MIT. Ver [THIRD_PARTY.md](THIRD_PARTY.md).

⚠️ **O cartão do CAMÕES não declara licença** (verificado a 2026-10-16). Por isso a imagem **nunca inclui os pesos**: é o seu
contentor que os descarrega do Hugging Face no primeiro arranque. O cartão indica como usos previstos a transcrição de português
europeu, investigação e avaliação de ASR, demonstrações e protótipos; para outros usos, confirme os termos com os autores.

O CAMÕES é do projecto AMALIA e do benchmark CAMÕES (ASRU 2025) — a citação está no
[cartão do modelo](https://huggingface.co/amalia-llm/CAMOES-whisper-asr). Este projecto não é afiliado ao AMALIA, à Open Home
Foundation nem à OpenAI.

---

## English

### What it is

Generic Whisper leans towards Brazilian Portuguese (*umidade*, not *humidade*). CAMÕES is Whisper large-v3 fine-tuned for
**European Portuguese**: in six synthetic phrases with *estores* ("blinds"), the original large-v3 heard *toques*, *históricos*,
*torres* and *estouros*, and CAMÕES heard *estores* all six times.

This image is the official server's (`rhasspy/wyoming-whisper:3.8.1`) with two additions:

- **on its first start** it downloads CAMÕES from Hugging Face, converts it to CTranslate2 int8 with the converter the image
  already carries, and keeps only the converted model (1.5 GB) in the `/data` volume. Later starts take seconds;
- **it transcribes without timestamps**: with them on (faster-whisper's default) CAMÕES writes junk before the first word
  (*", fechem…"*, *"rar o banheiro…"*). One argument added to the server's file at build time
  ([`patches/without_timestamps.py`](patches/without_timestamps.py)).

Portuguese by default, int8, beam 1 (as in the model card's own example).

### Quick start

```bash
docker run -d --name wyoming-camoes -p 10300:10300 -v wyoming-camoes:/data \
  -e WYO_WHISPER_CPU_THREADS=8 --restart unless-stopped ghcr.io/jnmanso/wyoming-camoes:latest
```

Or with [`compose.example.yaml`](compose.example.yaml). To build the image yourself: `docker build -t wyoming-camoes .`

The first start downloads about 6 GB and needs **8 GB of free RAM** while converting; wait for `INFO:__main__:Ready` in the
logs (`docker logs -f wyoming-camoes`).

### Connecting Home Assistant

1. **Settings → Devices & services → Add integration → Wyoming Protocol**, with the machine's IP and port `10300`.
2. **Settings → Voice assistants**, in the assistant: **Speech-to-text** → the new entity, language `pt`.

⚠️ Wyoming has no authentication: anyone who reaches port 10300 can use it. Restrict it to Home Assistant's address. Docker's
published ports bypass firewalls such as `ufw`; with `--network host` the host's firewall decides (that is how the author runs it).

### Configuration

The server reads every `--some-option` from the variable `WYO_WHISPER_SOME_OPTION`; arguments given to `docker run` win over
variables. The useful ones:

| Variable | Default | |
|---|---|---|
| `WYO_WHISPER_CPU_THREADS` | `4` | physical cores to give it |
| `WYO_WHISPER_URI` | `tcp://0.0.0.0:10300` | another port (the health check follows this variable, not a `--uri`) |
| `WYO_WHISPER_BEAM_SIZE` | `1` | |
| `WYO_WHISPER_LANGUAGE` | `pt` | |
| `WYO_WHISPER_COMPUTE_TYPE` | `int8` | |

And the first start's:

| Variable | Default | |
|---|---|---|
| `CAMOES_SOURCE` | `amalia-llm/CAMOES-whisper-asr` | the model's Hugging Face repository |
| `CAMOES_QUANTIZATION` | `int8` | the conversion's quantization |
| `CAMOES_MODEL_DIR` | `/data/camoes-ct2-<quantization>` | where the converted model lives |
| `CAMOES_PREPROCESSOR_SOURCE` | `openai/whisper-large-v3` | the base model, where the vocabulary and `preprocessor_config.json` (128 mels) come from |
| `CAMOES_KEEP_SOURCE` | `0` | `1` keeps the 6 GB download in `/data/hub` |

### Measurements

Ryzen 9 9900X, CPU, 12 threads, 2026-10-16:

- **~2 s per short command**, round trip through Home Assistant.
- **Twelve synthetic phrases** (six phrases, two `pt-PT` TTS voices), straight over Wyoming: 8 of 12 exact, Google's voice 6 of
  6, *estores* 6 of 6. The original Whisper large-v3 on the same: 2 of 12, *estores* 0 of 6.
- **Memory**: 1.6 GiB with the model loaded, up to ~2.3 GiB while transcribing; a 7 GiB peak while converting.
- **First start**: 66 s on a 10 Gbps line, about 40 s of it converting; on a slower line the 6 GB download dominates.

The image is built for `amd64` and `arm64`; only `amd64` has been tested. On a Raspberry Pi a model the size of large-v3 is likely
too slow for voice commands (not measured).

### Updating

- **A new version of the official server** (`rhasspy/wyoming-whisper`): change `WYOMING_WHISPER_VERSION` in the
  [Dockerfile](Dockerfile) and rebuild (`docker build -t wyoming-camoes .`). The build adds `without_timestamps` to
  the new version's file again. If that file changed and the patch no longer fits, the build stops and says why; if
  the new version already passes the option, it says there is nothing to change.
- **Before switching**, try the first start on an empty volume, because that is where the conversion runs, and it
  depends on the image's transformers and CTranslate2 versions:
  `docker run --rm -e WYO_WHISPER_URI=tcp://0.0.0.0:10301 -p 10301:10301 wyoming-camoes` — wait for
  `INFO:__main__:Ready`.
- **Switching**: `docker compose up -d` with the new image (`docker compose pull` first, if you use the published
  one). The volume keeps the converted model: nothing is downloaded or converted again.
- **A new CAMÕES** (if AMALIA publishes another version): delete the converted model and restart; the next start
  converts again (6 GB, 8 GB of RAM):
  `docker run --rm -v wyoming-camoes:/data --entrypoint rm wyoming-camoes -rf /data/camoes-ct2-int8`
- **Publishing** (whoever maintains the repository): a `vX.Y.Z` tag makes the [workflow](.github/workflows/image.yml)
  build both architectures and push them to `ghcr.io`.

### Licence and credits

This repository's code (Dockerfile, entrypoint, patch, documentation) is [MIT](LICENSE). The base image is
wyoming-faster-whisper's, MIT. See [THIRD_PARTY.md](THIRD_PARTY.md).

⚠️ **The CAMÕES model card declares no licence** (checked 2026-10-16). So the image **never contains the weights**: your container
downloads them from Hugging Face on its first start. The card lists as intended uses European-Portuguese speech-to-text, ASR
research and evaluation, demos and prototypes; for anything else, check the terms with its authors.

CAMÕES comes from the AMALIA project and the CAMÕES benchmark (ASRU 2025) — the citation is on the
[model card](https://huggingface.co/amalia-llm/CAMOES-whisper-asr). This project is not affiliated with AMALIA, the Open Home
Foundation or OpenAI.
