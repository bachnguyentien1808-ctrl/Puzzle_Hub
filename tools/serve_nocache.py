#!/usr/bin/env python3
"""Server tinh cho ban web: moi phan hoi kem Cache-Control: no-store de Chrome
khong giu ban cu trong bo nho dem (hay bi o che do chay thu tren localhost).

Dung: python3 tools/serve_nocache.py <cong> <thu-muc>
"""
import functools
import http.server
import sys


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()

    def send_head(self):
        # Bo qua dieu kien If-Modified-Since / If-None-Match: luon tra 200.
        for h in ("If-Modified-Since", "If-None-Match"):
            if h in self.headers:
                del self.headers[h]
        return super().send_head()


def main() -> None:
    port = int(sys.argv[1])
    directory = sys.argv[2]
    handler = functools.partial(NoCacheHandler, directory=directory)
    server = http.server.ThreadingHTTPServer(("0.0.0.0", port), handler)
    print(f"Serving no-cache on 0.0.0.0:{port} from {directory}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
