# syntax=docker/dockerfile:1
# ---------- Stage 1: build ----------
FROM golang:1.22-alpine AS build
WORKDIR /src
# Dependências primeiro (aproveita cache de camadas)
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
# go mod tidy garante o go.sum completo; binário estático, sem CGO, sem símbolos de debug
RUN go mod tidy && CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/app .

# ---------- Stage 2: runtime ----------
# distroless: sem shell, sem gerenciador de pacotes, usuário não-root (UID 65532)
FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/app /app/app
ENV PORT=8004
EXPOSE 8004
USER nonroot:nonroot
ENTRYPOINT ["/app/app"]
