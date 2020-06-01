# Multistage Dockerfile to build small, secure Docker image
# Based on info from:
# https://rollout.io/blog/building-minimal-docker-containers-for-go-applications/
# https://medium.com/@chemidy/create-the-smallest-and-secured-golang-docker-image-based-on-scratch-4752223b7324

# Step 1. Build executable
# Use golang alpine3.11 from dockerhub and specify digest for verification
FROM golang@sha256:911ebd34ce76d69beac233711215ece09b81f9000bb0fc4615ef3ee732a1c495 as builder

# install Git as required for Go packages
RUN apk update && apk add --no-cache git 

# Create appuser
ENV USER=appuser
ENV UID=10001

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"

WORKDIR /app
ADD ./ /app

# Fetch (download and verify) dependencies for our Go program.
RUN go get -d -v

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' -a \
    -o /go/bin/golang-test .

# Step2.  Build small, secure image with only our executable and appuser 
FROM scratch

# Import from builder.
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy our static executable
COPY --from=builder /go/bin/golang-test /go/bin/golang-test

# Use an unprivileged user.
USER appuser:appuser

# Run the golang-test binary.
ENTRYPOINT ["/go/bin/golang-test"]

# Expose the server port.
EXPOSE 8000
