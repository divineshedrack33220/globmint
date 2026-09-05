# ---- build ----
FROM golang:1.24-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/globmint-server ./cmd/server

# ---- runtime ----
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
COPY --from=build /out/globmint-server /usr/local/bin/globmint-server
ENV GLOBMINT_HTTP_ADDR=:8081
EXPOSE 8081
ENTRYPOINT ["globmint-server"]