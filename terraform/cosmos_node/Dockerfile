FROM golang:1.22.3-alpine3.19 AS build
WORKDIR /cosmos
RUN apk add --no-cache curl make git file libc-dev bash gcc linux-headers eudev-dev

ENV GO111MODULE=on

RUN git clone https://github.com/cosmos/gaia.git . && \
    git checkout v18.0.0-rc3

ARG WASMVM_VERSION=v1.5.0
ADD https://github.com/CosmWasm/wasmvm/releases/download/${WASMVM_VERSION}/libwasmvm_muslc.x86_64.a /lib/libwasmvm_muslc.x86_64.a
RUN sha256sum /lib/libwasmvm_muslc.x86_64.a | grep 465e3a088e96fd009a11bfd234c69fb8a0556967677e54511c084f815cf9ce63
RUN cp "/lib/libwasmvm_muslc.$(uname -m).a" /lib/libwasmvm_muslc.a

RUN CGO_ENABLED=1 LEDGER_ENABLED=true LINK_STATICALLY=true BUILD_TAGS=muslc make build
RUN echo "Ensuring binary is statically linked ..."  \
    && file /cosmos/build/gaiad | grep "statically linked"

FROM alpine:3.19
RUN apk add --no-cache build-base bash curl wget jq gzip

COPY --from=build /cosmos/build/gaiad /usr/local/bin/

EXPOSE 26656 26657 1317 9090
USER 0

ENTRYPOINT ["gaiad", "start"]
