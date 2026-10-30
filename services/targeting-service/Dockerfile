# syntax=docker/dockerfile:1
# ---------- Stage 1: build (instala dependências em um prefixo isolado) ----------
FROM python:3.11-slim AS build
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- Stage 2: runtime ----------
FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8003
WORKDIR /app
# usuário sem privilégios
RUN groupadd -r app --gid 10001 && useradd -r -g app --uid 10001 -d /app app
COPY --from=build /install /usr/local
COPY --chown=app:app app.py .
USER 10001
EXPOSE 8003
# --worker-tmp-dir /tmp permite rodar com readOnlyRootFilesystem no Kubernetes (emptyDir em /tmp)
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT} --workers 2 --timeout 60 --worker-tmp-dir /tmp --access-logfile - app:app"]
