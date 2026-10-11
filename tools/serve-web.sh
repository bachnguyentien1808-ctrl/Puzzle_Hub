#!/usr/bin/env bash
# Build web release va chay o MOT cong duy nhat (3414), mo ca qua IP trong mang
# LAN de test tren dien thoai. Tat server cu o cong nay truoc, nen khong bao
# gio co hai link. SKIP_BUILD=1 de chi chay lai server, khong build.
set -e
PORT=3414
cd "$(dirname "$0")/.."
pid=$(lsof -nP -tiTCP:$PORT -sTCP:LISTEN || true)
[ -n "$pid" ] && kill $pid
[ -z "$SKIP_BUILD" ] && flutter build web --release
echo "May nay:   http://localhost:$PORT"
for ip in $(ifconfig | awk '/inet /{print $2}' | grep -v '^127\.'); do
  echo "Dien thoai: http://$ip:$PORT"
done
exec python3 tools/serve_nocache.py $PORT build/web
