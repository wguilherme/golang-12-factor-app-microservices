ARG ALPINE_VERSION=3.20
ARG GOLANG_VERSION=1.23
ARG MAKE_VERSION=4.4.1-r2
ARG DLV_VERSION=1.23.1

FROM golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION}
ARG MAKE_VERSION
ARG DLV_VERSION
WORKDIR /opt/app
RUN apk add --no-cache make=${MAKE_VERSION}; \
  go install github.com/go-delve/delve/cmd/dlv@v${DLV_VERSION}
ENTRYPOINT [ "make" ]
CMD [ "run" ]
