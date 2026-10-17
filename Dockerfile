# wyoming-camoes: speech-to-text in European Portuguese for Home Assistant (Wyoming protocol),
# AMALIA's CAMOES model served by the official wyoming-faster-whisper image.

# The official server's version - the one line to change on an update (README, "Updating").
ARG WYOMING_WHISPER_VERSION=3.8.1
FROM rhasspy/wyoming-whisper:${WYOMING_WHISPER_VERSION}
ARG WYOMING_WHISPER_VERSION

LABEL org.opencontainers.image.title="wyoming-camoes" \
      org.opencontainers.image.description="European-Portuguese speech-to-text for Home Assistant: AMALIA's CAMOES Whisper on wyoming-faster-whisper" \
      org.opencontainers.image.source="https://github.com/jnmanso/wyoming-camoes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.base.name="docker.io/rhasspy/wyoming-whisper:${WYOMING_WHISPER_VERSION}"

# The one change to the server: transcribe without timestamps (CAMOES writes junk before the first word
# otherwise). Applied to the base image's own file, so upstream's other changes are kept; the build stops
# if that file no longer looks as expected.
COPY patches/without_timestamps.py /tmp/without_timestamps.py
RUN /usr/src/.venv/bin/python /tmp/without_timestamps.py /usr/src/wyoming_faster_whisper/faster_whisper_handler.py \
    && rm /tmp/without_timestamps.py

COPY entrypoint.sh /usr/src/wyoming-camoes-entrypoint.sh

# The defaults are WYO_WHISPER_* variables set in the entrypoint; `docker run -e` and arguments override them.
ENTRYPOINT ["bash", "/usr/src/wyoming-camoes-entrypoint.sh"]
