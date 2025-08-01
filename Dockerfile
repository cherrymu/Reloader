ARG BUILDER_IMAGE
ARG BASE_IMAGE

# Build the manager binary
FROM --platform=${BUILDPLATFORM} ${BUILDER_IMAGE:-golang:1.24.4} AS builder

ARG TARGETOS
ARG TARGETARCH
ARG GOPROXY
ARG GOPRIVATE

ARG COMMIT
ARG VERSION
ARG BUILD_DATE

WORKDIR /workspace

# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY main.go main.go
COPY internal/ internal/
COPY pkg/ pkg/

# Build
RUN CGO_ENABLED=0 \
    GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH} \
    GOPROXY=${GOPROXY} \
    GOPRIVATE=${GOPRIVATE} \
    GO111MODULE=on \
    go build -ldflags="-s -w -X github.com/stakater/Reloader/pkg/common.Version=${VERSION} \
         -X github.com/stakater/Reloader/pkg/common.Commit=${COMMIT} \
         -X github.com/stakater/Reloader/pkg/common.BuildDate=${BUILD_DATE}" \
        -installsuffix 'static' -mod=mod -a -o manager ./

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM ${BASE_IMAGE:-gcr.io/distroless/static:nonroot}
WORKDIR /
COPY --from=builder /workspace/manager .
USER 65532:65532

# Port for metrics and probes
EXPOSE 9090

ENTRYPOINT ["/manager"]
