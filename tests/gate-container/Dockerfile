# The complete-gate image for tests/gate-container/gate.sh. It mirrors the
# pinned toolchain .github/workflows/check.yml installs, read from the
# framework.json pins, built for the build host's architecture (aarch64 or
# x86_64). The build context is this file plus framework.json and nothing else:
# the checkout, including its git-ignored local inputs, is copied into the
# running container by gate.sh and never reaches an image layer.
FROM python:3.12-slim-bookworm
ENV OPENSPEC_TELEMETRY=0 OPENSPEC_NO_UPDATE_CHECK=1 OPENWIKI_TELEMETRY_DISABLED=1 DO_NOT_TRACK=1 \
    UV_CACHE_DIR=/opt/uv-cache UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin \
    PATH=/opt/node/bin:$PATH
COPY framework.json /opt/framework.json
RUN apt-get update && apt-get install -y --no-install-recommends bash curl ca-certificates git xz-utils \
    && rm -rf /var/lib/apt/lists/*
# Release asset names differ by architecture; CI's x86_64 names are kept
# exactly (musl ripgrep and fd), and aarch64 uses the published gnu builds.
RUN set -eu; f=/opt/framework.json; \
    case "$(uname -m)" in \
      aarch64) a=aarch64; t=arm64; n=arm64; rgt=aarch64-unknown-linux-gnu; fdt=aarch64-unknown-linux-gnu ;; \
      x86_64) a=x86_64; t=amd64; n=x64; rgt=x86_64-unknown-linux-musl; fdt=x86_64-unknown-linux-musl ;; \
      *) echo "unsupported architecture: $(uname -m)" >&2; exit 2 ;; \
    esac; \
    p="$(python -c "import json; print(json.load(open('$f'))['tools']['jq']['min'])")"; \
    curl -fLsS "https://github.com/jqlang/jq/releases/download/jq-$p/jq-linux-$t" -o /usr/local/bin/jq; chmod +x /usr/local/bin/jq; \
    p="$(jq -r .tools.yq.version $f)"; \
    curl -fLsS "https://github.com/mikefarah/yq/releases/download/v$p/yq_linux_$t" -o /usr/local/bin/yq; \
    p="$(jq -r .tools.rg.version $f)"; \
    curl -fLsS "https://github.com/BurntSushi/ripgrep/releases/download/$p/ripgrep-$p-$rgt.tar.gz" | tar -xz -C /tmp; \
    cp "/tmp/ripgrep-$p-$rgt/rg" /usr/local/bin/; \
    p="$(jq -r .tools.fd.version $f)"; \
    curl -fLsS "https://github.com/sharkdp/fd/releases/download/v$p/fd-v$p-$fdt.tar.gz" | tar -xz -C /tmp; \
    cp "/tmp/fd-v$p-$fdt/fd" /usr/local/bin/; \
    p="$(jq -r .tools.shellcheck.version $f)"; \
    curl -fLsS "https://github.com/koalaman/shellcheck/releases/download/v$p/shellcheck-v$p.linux.$a.tar.xz" | tar -xJ -C /tmp; \
    cp "/tmp/shellcheck-v$p/shellcheck" /usr/local/bin/; \
    p="$(jq -r .tools.uv.version $f)"; \
    curl -fLsS "https://github.com/astral-sh/uv/releases/download/$p/uv-$a-unknown-linux-gnu.tar.gz" | tar -xz -C /tmp; \
    cp "/tmp/uv-$a-unknown-linux-gnu/uv" /usr/local/bin/; \
    p="$(jq -r .tools.node.min $f)"; mkdir -p /opt/node; \
    curl -fLsS "https://nodejs.org/dist/v$p/node-v$p-linux-$n.tar.xz" | tar -xJ -C /opt/node --strip-components=1; \
    chmod +x /usr/local/bin/*; rm -rf /tmp/*; \
    for tool in jq yq rg fd shellcheck uv node; do "$tool" --version >/dev/null; done
# The validator runs check-jsonschema with `uv run --offline`, so the pinned
# package is resolved once here into a cache every user can read.
RUN set -eu; f=/opt/framework.json; \
    uv run --no-project --with "check-jsonschema==$(jq -r '.tools["check-jsonschema"].version' $f)" check-jsonschema --version; \
    for tool in openspec openwiki; do \
      npm install -g "$(jq -r --arg t "$tool" '.tools[$t].package' $f)@$(jq -r --arg t "$tool" '.tools[$t].version' $f)"; \
    done; \
    uv tool install --from "$(jq -r '.tools["skills-ref"].install' $f)" "$(jq -r '.tools["skills-ref"].package' $f)"; \
    for tool in openspec openwiki skills-ref; do command -v "$tool" >/dev/null; done; \
    chmod -R a+rwX /opt/uv-cache /opt/uv-tools
RUN useradd -m tester \
    && git config --system user.name tester \
    && git config --system user.email tester@example.invalid \
    && git config --system --add safe.directory '*'
USER tester
WORKDIR /work
