# Third-party components

## wyoming-faster-whisper (base image and patched file)

The image builds on `rhasspy/wyoming-whisper`, from
[OHF-Voice/wyoming-faster-whisper](https://github.com/OHF-Voice/wyoming-faster-whisper).
`patches/faster_whisper_handler.py` is that project's file from version 3.8.1 with one line added
(`"without_timestamps": True`). It is used under the MIT licence:

> MIT License — Copyright (c) 2025 Michael Hansen

## The CAMÕES model (not included)

[amalia-llm/CAMOES-whisper-asr](https://huggingface.co/amalia-llm/CAMOES-whisper-asr) is a fine-tune of
[openai/whisper-large-v3](https://huggingface.co/openai/whisper-large-v3) (Apache-2.0) for European
Portuguese, from the [AMALIA](https://amaliallm.pt) project and the CAMÕES benchmark (ASRU 2025).
**Its model card declares no licence** (no `license` field and no licence section, checked on 2026-10-16). This image
therefore never contains the weights: the container downloads them from Hugging Face on its first start, on the
user's behalf, and converts them locally. The card lists as intended uses European-Portuguese speech-to-text, ASR
research, ASR evaluation, and transcription demos and prototypes; check the terms with its authors for anything else.

`preprocessor_config.json` is fetched from `openai/whisper-large-v3` (Apache-2.0).
