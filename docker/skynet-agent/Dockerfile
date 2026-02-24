FROM alpine:3.20

# Phase 2: Add bc for floating point math calculations (sync rate, trends)
RUN apk add --no-cache bash curl jq docker-cli bc

COPY combined-start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["bash", "/start.sh"]
