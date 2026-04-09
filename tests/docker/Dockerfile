FROM alpine:3.21
# Test fixture for docker.yml — minimal image for CI validation
RUN adduser -D appuser
USER appuser
HEALTHCHECK NONE
CMD ["echo", "hello world"]
