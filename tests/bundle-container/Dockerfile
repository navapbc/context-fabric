# Build-time downloads prepare pinned tools. Acceptance itself has no network.
FROM python:3.12-slim-bookworm
COPY bundle.tar.gz /opt/bundle.tar.gz
COPY bundle-smoke.sh /opt/bundle-smoke.sh
COPY bundle-entrypoint.sh /opt/bundle-entrypoint.sh
RUN apt-get update && apt-get install -y --no-install-recommends bash curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/metadata /workspace \
    && tar -xzf /opt/bundle.tar.gz -C /opt/metadata framework.json \
    && case "$(uname -m)" in aarch64) tool_arch=arm64; uv_arch=aarch64 ;; x86_64) tool_arch=amd64; uv_arch=x86_64 ;; *) exit 2 ;; esac \
    && jq_pin="$(python -c 'import json; print(json.load(open("/opt/metadata/framework.json"))["tools"]["jq"]["min"])')" \
    && curl -fLsS "https://github.com/jqlang/jq/releases/download/jq-${jq_pin}/jq-linux-${tool_arch}" -o /usr/local/bin/jq \
    && chmod +x /usr/local/bin/jq \
    && yq_pin="$(jq -r '.tools.yq.version' /opt/metadata/framework.json)" \
    && curl -fLsS "https://github.com/mikefarah/yq/releases/download/v${yq_pin}/yq_linux_${tool_arch}" -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && uv_pin="$(jq -r '.tools.uv.version' /opt/metadata/framework.json)" \
    && curl -fLsS "https://github.com/astral-sh/uv/releases/download/${uv_pin}/uv-${uv_arch}-unknown-linux-gnu.tar.gz" -o /opt/uv.tar.gz \
    && tar -xzf /opt/uv.tar.gz -C /opt \
    && cp "/opt/uv-${uv_arch}-unknown-linux-gnu/uv" /usr/local/bin/uv \
    && UV_CACHE_DIR=/opt/schema-cache UV_PYTHON=/usr/local/bin/python3.12 \
       uv --no-config run --no-project --with "check-jsonschema==$(jq -r '.tools["check-jsonschema"].version' /opt/metadata/framework.json)" check-jsonschema --version \
    && ! command -v git \
    && chmod +x /opt/bundle-entrypoint.sh
WORKDIR /workspace
ENTRYPOINT ["/opt/bundle-entrypoint.sh"]
