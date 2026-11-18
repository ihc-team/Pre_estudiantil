#!/bin/bash
set -e

echo "=== 1. Iniciando servidor API Node en segundo plano ==="
(cd servidor && nohup node servidor.js > ../api.log 2>&1 &)

echo "=== 2. Esperando que el servidor responda en http://127.0.0.1:3000/ping ==="
LISTO=0
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:3000/ping >/dev/null 2>&1; then
    echo "Servidor listo en el intento $i"
    LISTO=1
    break
  fi
  echo "Esperando servidor... intento $i"
  sleep 2
done

if [ "$LISTO" -eq 0 ]; then
  echo "=== ERROR: El servidor API no respondio a tiempo ==="
  if [ -f api.log ]; then
    echo "=== Contenido de api.log ==="
    cat api.log
  fi
  exit 1
fi

echo "=== 3. Verificando emulador Android conectado ==="
adb devices
DEVICE=$(adb devices | grep -m1 'emulator-' | awk '{print $1}')
DEVICE=${DEVICE:-emulator-5554}
echo "Emulador detectado: $DEVICE"

echo "=== Esperando que el emulador asiente sus servicios ==="
adb -s "$DEVICE" wait-for-device
sleep 5

echo "=== 4. Ejecutando pruebas E2E de Flutter (secuencial) ==="
for test_file in integration_test/*_test.dart; do
  echo "=== Ejecutando $test_file ==="
  flutter test "$test_file" -d "$DEVICE" --reporter expanded
done

