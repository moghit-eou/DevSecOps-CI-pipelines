FROM python:3.10@sha256:70c9cc6756056ca7e438a3198af44b7791a958438594a0b5348603c77763d312
WORKDIR /app
# uv binary from its digest-pinned distroless image instead of an unpinned `pip install uv`
COPY --from=ghcr.io/astral-sh/uv:0.12.9@sha256:8b940d3a9d65bed080436972241af2e21c84b5e8c9193f7014ed71479ee795ff /uv /usr/local/bin/uv
COPY requirements.txt .
# --require-hashes: every requirement must match one of its pinned SHA256 hashes
RUN uv pip install --system --no-cache --require-hashes -r requirements.txt
COPY . .
EXPOSE 8080
CMD ["gunicorn", "-b", "0.0.0.0:8080", "app:app"]


# docker  build -t drive_application_v2 
# docker run -p 8080:8080 drive_application_v2


