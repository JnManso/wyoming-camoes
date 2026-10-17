# wyoming-camoes

Speech-to-text in **European Portuguese** for Home Assistant: the
[CAMÕES](https://huggingface.co/amalia-llm/CAMOES-whisper-asr) model (Whisper fine-tuned by the [AMALIA](https://amaliallm.pt)
project), served by the official [wyoming-faster-whisper](https://github.com/OHF-Voice/wyoming-faster-whisper) over the
[Wyoming](https://github.com/OHF-Voice/wyoming) protocol.

[Português](README.pt.md)

## What it is

Generic Whisper leans towards Brazilian Portuguese. CAMÕES is Whisper large-v3 fine-tuned for European Portuguese: the
original large-v3 hears *estores* ("blinds") as *toques*, *torres* or *estouros*; CAMÕES gets it right.

This image is the official server (`rhasspy/wyoming-whisper:3.8.1`) with two additions:

- **First start**: downloads CAMÕES from Hugging Face, converts it to CTranslate2 int8 and keeps only the converted model
  (1.5 GB) in the `/data` volume. Later starts take seconds.
- **No timestamps**: with timestamps on (faster-whisper's default) CAMÕES writes junk before the first word. The build
  adds `without_timestamps=True` to the server ([patch](patches/without_timestamps.py)).

Defaults: Portuguese, int8, beam size 1. Runs on the CPU; no GPU needed.

## Quick start

```bash
git clone https://github.com/jnmanso/wyoming-camoes.git
cd wyoming-camoes
docker build -t wyoming-camoes .
docker run -d --name wyoming-camoes -p 10300:10300 -v wyoming-camoes:/data \
  -e WYO_WHISPER_CPU_THREADS=8 --restart unless-stopped wyoming-camoes
```

Or copy [`compose.example.yaml`](compose.example.yaml) to `compose.yaml` and run `docker compose up -d`.

The first start downloads about 6 GB and needs 8 GB of free RAM while converting. Wait for `INFO:__main__:Ready` in
`docker logs -f wyoming-camoes`.

## Connecting Home Assistant

1. **Settings → Devices & services → Add integration → Wyoming Protocol**, with the server's IP and port `10300`.
2. **Settings → Voice assistants** → your assistant → **Speech-to-text**: the new entity, language `pt`.

⚠️ Wyoming has no authentication: anyone who can reach port 10300 can use the server. Restrict the port to Home
Assistant's address. Docker's published ports bypass host firewalls such as `ufw`; with `--network host` the host
firewall applies.

## Configuration

Every server option `--some-option` can be set with the variable `WYO_WHISPER_SOME_OPTION`; command-line arguments win
over variables. The useful ones:

| Variable | Default | Purpose |
|---|---|---|
| `WYO_WHISPER_CPU_THREADS` | `4` | threads for inference; use the machine's physical cores |
| `WYO_WHISPER_URI` | `tcp://0.0.0.0:10300` | listen address (the health check follows this variable, not a `--uri` argument) |
| `WYO_WHISPER_BEAM_SIZE` | `1` | 1 is the fastest |
| `WYO_WHISPER_LANGUAGE` | `pt` | `auto` detects the language |
| `WYO_WHISPER_COMPUTE_TYPE` | `int8` | CTranslate2 compute type; int8 for CPU |

First-start variables:

| Variable | Default | Purpose |
|---|---|---|
| `CAMOES_SOURCE` | `amalia-llm/CAMOES-whisper-asr` | model repository on Hugging Face |
| `CAMOES_QUANTIZATION` | `int8` | conversion quantization |
| `CAMOES_KEEP_SOURCE` | `0` | `1` keeps the 6 GB download in `/data/hub` |

## Measurements

Ryzen 9 9900X, 12 threads, 2026-10:

- About 2 s per short voice command, round trip through Home Assistant.
- Memory: 1.6 GiB with the model loaded, up to 2.3 GiB while transcribing; 7 GiB peak during the first-start
  conversion.
- First start: about one minute on a fast connection, most of it the 6 GB download.

The image is built for `amd64` and `arm64`; only `amd64` has been tested.

## Updating

- **New version of the official server**: change `WYOMING_WHISPER_VERSION` in the [Dockerfile](Dockerfile) and build
  (`docker compose build`, or `docker build -t wyoming-camoes .`). The build adds `without_timestamps` to the new
  version's file again; it stops with a message if the file changed and the patch no longer fits, and does nothing if
  upstream already passes the option.
- **Test the first start** before switching, in a throwaway container with no volume, because the conversion depends
  on the image's transformers and CTranslate2 versions:

  ```bash
  docker run --rm wyoming-camoes
  ```

  Wait for `INFO:__main__:Ready`.
- **Switch**: `docker compose up -d` (without compose: `docker rm -f wyoming-camoes`, then the quick start's `docker
  run`). The volume keeps the converted model: nothing is downloaded or converted again.
- **New CAMÕES release**: delete the converted model and restart; the next start converts again (6 GB download, 8 GB
  RAM):

  ```bash
  docker run --rm -v wyoming-camoes:/data --entrypoint rm wyoming-camoes -rf /data/camoes-ct2-int8
  ```

- **Publishing** (maintainers): a `vX.Y.Z` tag makes the [workflow](.github/workflows/image.yml) build both
  architectures and push them to `ghcr.io`.

## Licence and credits

This repository's code (Dockerfile, entrypoint, patch, documentation) is [MIT](LICENSE). The base image is
wyoming-faster-whisper's, MIT. See [THIRD_PARTY.md](THIRD_PARTY.md).

⚠️ **The CAMÕES model card declares no licence** (checked 2026-10-16). So the image **never contains the weights**: your
container downloads them from Hugging Face on its first start. The card lists as intended uses European-Portuguese
speech-to-text, ASR research and evaluation, demos and prototypes; for anything else, check the terms with its authors.

CAMÕES comes from the AMALIA project and the CAMÕES benchmark (ASRU 2025) — the citation is on the
[model card](https://huggingface.co/amalia-llm/CAMOES-whisper-asr). This project is not affiliated with AMALIA, the Open Home
Foundation or OpenAI.
