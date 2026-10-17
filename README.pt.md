# wyoming-camoes

Reconhecimento de voz em **português europeu** para o Home Assistant: o modelo Whisper [CAMÕES](https://huggingface.co/amalia-llm/CAMOES-whisper-asr)
do projecto [AMALIA](https://amaliallm.pt), servido por [Wyoming](https://github.com/OHF-Voice/wyoming) pelo servidor oficial
[wyoming-faster-whisper](https://github.com/OHF-Voice/wyoming-faster-whisper).

[English](README.md)

## O que é

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

## Arranque rápido

```bash
docker run -d --name wyoming-camoes -p 10300:10300 -v wyoming-camoes:/data \
  -e WYO_WHISPER_CPU_THREADS=8 --restart unless-stopped ghcr.io/jnmanso/wyoming-camoes:latest
```

Ou com [`compose.example.yaml`](compose.example.yaml). Para construir a imagem localmente: `docker build -t wyoming-camoes .`

O primeiro arranque descarrega cerca de 6 GB e precisa de **8 GB de RAM livres** durante a conversão; espere pelo
`INFO:__main__:Ready` nos logs (`docker logs -f wyoming-camoes`).

## Ligar ao Home Assistant

1. **Settings → Devices & services → Add integration → Wyoming Protocol** (os menus em inglês), com o IP da máquina e a porta
   `10300`.
2. **Settings → Voice assistants**, no assistente: **Speech-to-text** → a nova entidade, língua `pt`.

⚠️ O Wyoming não tem autenticação: quem chegar à porta 10300 pode usá-la. Limite-a ao endereço do Home Assistant. As portas
publicadas pelo Docker passam ao lado de firewalls como o `ufw`; com `--network host` é o firewall da máquina que decide (é assim
que o autor o corre).

## Configuração

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

## Medições

Ryzen 9 9900X, CPU, 12 threads, 2026-10-16:

- **~2 s por comando curto**, ida e volta pelo Home Assistant.
- **Doze frases sintéticas** (seis frases, duas vozes TTS `pt-PT`), directamente pelo Wyoming: 8 de 12 exactas, a voz do Google
  6 de 6, *estores* 6 de 6. O Whisper large-v3 original, nas mesmas: 2 de 12 e *estores* 0 de 6.
- **Memória**: 1,6 GiB com o modelo carregado, até ~2,3 GiB a transcrever; 7 GiB de pico na conversão.
- **Primeiro arranque**: 66 s numa linha de 10 Gbps, cerca de 40 s deles a converter; numa linha mais lenta, pesa o download de
  6 GB.

A imagem é construída para `amd64` e `arm64`; só a `amd64` foi testada. Num Raspberry Pi, um modelo do tamanho do large-v3 deverá
ser lento demais para comandos de voz (não medido).

## Actualizar

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

## Licença e créditos

O código deste repositório (Dockerfile, entrypoint, patch, documentação) é [MIT](LICENSE). A imagem de base é a do
wyoming-faster-whisper, MIT. Ver [THIRD_PARTY.md](THIRD_PARTY.md).

⚠️ **O cartão do CAMÕES não declara licença** (verificado a 2026-10-16). Por isso a imagem **nunca inclui os pesos**: é o seu
contentor que os descarrega do Hugging Face no primeiro arranque. O cartão indica como usos previstos a transcrição de português
europeu, investigação e avaliação de ASR, demonstrações e protótipos; para outros usos, confirme os termos com os autores.

O CAMÕES é do projecto AMALIA e do benchmark CAMÕES (ASRU 2025) — a citação está no
[cartão do modelo](https://huggingface.co/amalia-llm/CAMOES-whisper-asr). Este projecto não é afiliado ao AMALIA, à Open Home
Foundation nem à OpenAI.
