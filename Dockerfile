# wyoming-camoes: speech-to-text in European Portuguese for Home Assistant (Wyoming protocol),
# AMALIA's CAMOES model served by the official wyoming-faster-whisper image.
FROM rhasspy/wyoming-whisper:3.8.1

LABEL org.opencontainers.image.title="wyoming-camoes" \
      org.opencontainers.image.description="European-Portuguese speech-to-text for Home Assistant: AMALIA's CAMOES Whisper on wyoming-faster-whisper" \
      org.opencontainers.image.source="https://github.com/jnmanso/wyoming-camoes" \
      org.opencontainers.image.licenses="MIT"

# The one change to the server: transcribe without timestamps (CAMOES writes junk before the first word otherwise).
COPY patches/faster_whisper_handler.py /usr/src/wyoming_faster_whisper/faster_whisper_handler.py
COPY entrypoint.sh /usr/src/wyoming-camoes-entrypoint.sh

# The defaults are WYO_WHISPER_* variables set in the entrypoint; `docker run -e` and arguments override them.
ENTRYPOINT ["bash", "/usr/src/wyoming-camoes-entrypoint.sh"]
