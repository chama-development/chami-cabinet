"""Check the API event loop over loopback, without external services or proxies."""
import json
import os
import urllib.request


def check() -> None:
    port = int(os.environ.get("APP_PORT", "5000"))
    if not 1 <= port <= 65535:
        raise ValueError("invalid APP_PORT")
    client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with client.open(f"http://127.0.0.1:{port}/healthz", timeout=3) as response:
        if response.status != 200 or json.loads(response.read(4096)).get("status") != "ok":
            raise RuntimeError("API health check failed")


if __name__ == "__main__":
    check()
