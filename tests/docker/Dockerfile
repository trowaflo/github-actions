FROM alpine:3.23
# Test fixture for docker.yml — minimal image for CI validation
RUN apk update && apk upgrade --no-cache && \
    adduser -D appuser
USER appuser
HEALTHCHECK NONE
CMD ["echo", "hello world"]
