#!/usr/bin/env bash
# wyoming-camoes - start the official wyoming-faster-whisper server with AMALIA's CAMOES model.
#
# On the first start it downloads CAMOES (Whisper large-v3 fine-tuned for European Portuguese) from
# Hugging Face, converts it to CTranslate2 with the converter already in the image, and keeps only the
# converted model in /data. The weights are never part of this image: the model card declares no licence.
set -euo pipefail

SOURCE="${CAMOES_SOURCE:-amalia-llm/CAMOES-whisper-asr}"
QUANT="${CAMOES_QUANTIZATION:-int8}"
MODEL_DIR="${CAMOES_MODEL_DIR:-/data/camoes-ct2-${QUANT}}"
PREPROCESSOR_SOURCE="${CAMOES_PREPROCESSOR_SOURCE:-openai/whisper-large-v3}"
VENV=/usr/src/.venv/bin

if [ ! -f "${MODEL_DIR}/model.bin" ]; then
    echo "[wyoming-camoes] first start: converting ${SOURCE} to CTranslate2 (${QUANT}) into ${MODEL_DIR}"
    echo "[wyoming-camoes] about 6 GB to download and 8 GB of RAM for a few minutes; later starts skip this"
    partial="${MODEL_DIR}.partial"
    rm -rf "${partial}"
    "${VENV}/python" - "${SOURCE}" "${partial}" "${QUANT}" "${PREPROCESSOR_SOURCE}" <<'PY'
import sys
import transformers
from ctranslate2.converters.transformers import TransformersConverter


class Converter(TransformersConverter):
    # CTranslate2 4.8 passes dtype=, a name transformers accepts only from 4.56; the base image has 4.52.
    def load_model(self, model_class, model_name_or_path, **kwargs):
        version = tuple(int(x) for x in transformers.__version__.split(".")[:2])
        if version < (4, 56) and "dtype" in kwargs:
            kwargs["torch_dtype"] = kwargs.pop("dtype")
        return model_class.from_pretrained(model_name_or_path, **kwargs)

    # CAMOES's tokenizer_config.json is in a format transformers 4.52 cannot read; it is large-v3's
    # tokenizer, so the vocabulary is read from the base model (the card loads its processor from there).
    def load_tokenizer(self, tokenizer_class, model_name_or_path, **kwargs):
        return tokenizer_class.from_pretrained(base, **kwargs)


source, output, quantization, base = sys.argv[1:5]
Converter(source, copy_files=["tokenizer.json"], low_cpu_mem_usage=True).convert(
    output, quantization=quantization, force=True
)
PY
    # CAMOES ships no preprocessor config; large-v3's (128 mel bins) is the one it was trained with.
    "${VENV}/python" - "${PREPROCESSOR_SOURCE}" "${partial}" <<'PY'
import shutil, sys
from huggingface_hub import hf_hub_download
shutil.copy(hf_hub_download(sys.argv[1], "preprocessor_config.json"), sys.argv[2] + "/preprocessor_config.json")
PY
    mv "${partial}" "${MODEL_DIR}"
    if [ "${CAMOES_KEEP_SOURCE:-0}" != "1" ]; then
        rm -rf "${HF_HOME:-/data}/hub/models--${SOURCE//\//--}"
    fi
    echo "[wyoming-camoes] model ready in ${MODEL_DIR}"
fi

# The server reads every --some-option from WYO_WHISPER_SOME_OPTION, and the command line wins over the
# environment. So the defaults are given the way the base image's docker_run.sh gives its own: as
# variables, each set only when unset, never as arguments that a user's variable could not override.
export WYO_WHISPER_MODEL="${MODEL_DIR}"
export WYO_WHISPER_STT_LIBRARY="${WYO_WHISPER_STT_LIBRARY:-faster-whisper}"
export WYO_WHISPER_LANGUAGE="${WYO_WHISPER_LANGUAGE:-pt}"
export WYO_WHISPER_COMPUTE_TYPE="${WYO_WHISPER_COMPUTE_TYPE:-${QUANT}}"
export WYO_WHISPER_BEAM_SIZE="${WYO_WHISPER_BEAM_SIZE:-1}"
export WYO_WHISPER_LOCAL_FILES_ONLY="${WYO_WHISPER_LOCAL_FILES_ONLY:-true}"

# docker_run.sh is the base image's own start script (it adds --uri, --data-dir and --device).
exec bash /usr/src/docker_run.sh "$@"
