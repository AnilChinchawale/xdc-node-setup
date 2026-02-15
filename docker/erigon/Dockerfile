FROM golang:1.22-alpine AS builder

RUN apk add --no-cache make gcc musl-dev linux-headers git bash

WORKDIR /build

RUN git clone https://github.com/AnilChinchawale/erigon-xdc.git . && make erigon

FROM alpine:3.19

RUN apk add --no-cache ca-certificates libstdc++ libgcc wget

COPY --from=builder /build/build/bin/erigon /usr/local/bin/erigon

ENTRYPOINT ["erigon"]
