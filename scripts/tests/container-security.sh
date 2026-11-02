#!/usr/bin/env bash
# Exercise production image users, old-volume migration, startup and HTTP probes.
set -euo pipefail
role="${1:?backend or frontend}"; image="${2:?image}"
prefix="cabinet-security-${RANDOM}-$$"
container="${prefix}-app"
volumes=()
cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  for volume in "${volumes[@]}"; do docker volume rm "$volume" >/dev/null 2>&1 || true; done
}
trap cleanup EXIT

if [ "$role" = backend ]; then
  mounts=()
  for name in assets logs backups; do
    volume="${prefix}-${name}"
    volumes+=("$volume")
    docker volume create "$volume" >/dev/null
    mounts+=(-v "${volume}:/opt/remnashop/${name}")
  done
  # Model an existing root-owned private config and a link outside the data tree.
  docker run --rm --user 0:0 "${mounts[@]}" --entrypoint sh "$image" -ec '
    echo preserved > assets/security-fixture.txt
    chmod 600 assets/security-fixture.txt
    ln -s /etc/passwd assets/security-link
  '
  docker run --rm --user 0:0 --network none --read-only \
    --cap-drop ALL --cap-add CHOWN --cap-add DAC_OVERRIDE \
    "${mounts[@]}" --entrypoint python "$image" scripts/prepare-runtime-dirs.py
  docker run --rm --network none "${mounts[@]}" --entrypoint sh "$image" -ec '
    test "$(id -u)" = 10001
    test "$(stat -c %u /etc/passwd)" = 0
    test ! -w src/__main__.py
    test ! -w .venv/lib/python3.12/site-packages/jwt/__init__.py
    test "$(cat assets/security-fixture.txt)" = preserved
    echo writable >> assets/security-fixture.txt
    touch logs/security-fixture backups/security-fixture
    mkdir -p assets/banners
    cp -a assets.default/banners/. assets/banners/
    ! /usr/local/bin/python -c "import pip" 2>/dev/null
  '
  docker run -d --name "$container" --env-file ci.env "${mounts[@]}" \
    --entrypoint uvicorn "$image" src.__main__:application --factory \
    --lifespan off --host 0.0.0.0 --port 5000 >/dev/null
  probe=(python /opt/remnashop/scripts/container-healthcheck.py)
elif [ "$role" = frontend ]; then
  docker run -d --name "$container" --network none \
    -e API_UPSTREAM=127.0.0.1:9 -e CABINET_BRAND='CI cabinet' "$image" >/dev/null
  probe=(wget -q -T 3 -O /dev/null http://127.0.0.1:8080/healthz)
else
  echo "unknown role: $role" >&2; exit 2
fi

ready=false
for attempt in $(seq 1 45); do
  if docker exec "$container" "${probe[@]}" >/dev/null 2>&1; then ready=true; break; fi
  sleep 1
done
if [ "$ready" != true ]; then docker logs "$container"; exit 1; fi
if [ "$role" = frontend ]; then
  docker exec "$container" sh -ec '
    test "$(id -u)" != 0
    test ! -w /etc/nginx/nginx.conf
    grep -q "CI cabinet" /usr/share/nginx/html/index.html
    nginx -t
  '
else
  # A closed API port must fail rather than report a running process as healthy.
  if docker exec -e APP_PORT=1 "$container" "${probe[@]}" >/dev/null 2>&1; then exit 1; fi
fi
echo "$role: non-root runtime, startup and health checks passed"
