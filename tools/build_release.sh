#!/usr/bin/env bash
# build_release.sh — gera AAB (Play) e APK assinados com a upload key de produção.
#
# A chave e as senhas ficam FORA do repositório, em
#   ~/.mentall-pro-keys/release.env  (chmod 600)
# e são lidas por variáveis de ambiente (MENTALL_*), conforme
# android/app/build.gradle.kts. Nunca commitar esse arquivo.
#
# Uso:
#   bash tools/build_release.sh            # analyze + tests + AAB + APK + verificação
#   SKIP_CHECKS=1 bash tools/build_release.sh   # só os builds
#
# Saídas:
#   build/app/outputs/bundle/release/app-release.aab
#   build/app/outputs/flutter-apk/app-release.apk
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${MENTALL_RELEASE_ENV:-$HOME/.mentall-pro-keys/release.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "ERRO: $ENV_FILE não encontrado." >&2
  echo "Crie o arquivo com MENTALL_KEYSTORE_FILE, MENTALL_KEYSTORE_PASSWORD," >&2
  echo "MENTALL_KEY_ALIAS e MENTALL_KEY_PASSWORD (ver docs/RELEASE_ANDROID.md)." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

for variavel in MENTALL_KEYSTORE_FILE MENTALL_KEYSTORE_PASSWORD MENTALL_KEY_ALIAS MENTALL_KEY_PASSWORD; do
  if [ -z "${!variavel:-}" ]; then
    echo "ERRO: $variavel não definida em $ENV_FILE" >&2
    exit 1
  fi
done

if [ ! -f "$MENTALL_KEYSTORE_FILE" ]; then
  echo "ERRO: keystore não encontrado em $MENTALL_KEYSTORE_FILE" >&2
  exit 1
fi

if [ "${SKIP_CHECKS:-0}" != "1" ]; then
  echo "==> flutter analyze --no-pub"
  flutter analyze --no-pub
  echo "==> flutter test --no-pub"
  flutter test --no-pub
fi

echo "==> flutter build appbundle --release (AAB para a Play Store)"
flutter build appbundle --release

echo "==> flutter build apk --release (APK assinado para teste no aparelho)"
flutter build apk --release

AAB="build/app/outputs/bundle/release/app-release.aab"
APK="build/app/outputs/flutter-apk/app-release.apk"
APKSIGNER="${ANDROID_HOME:-$HOME/Android/sdk}/build-tools/36.0.0/apksigner"

echo "==> Verificando a assinatura do APK"
if [ -x "$APKSIGNER" ]; then
  "$APKSIGNER" verify --print-certs "$APK" | head -8
else
  keytool -printcert -jarfile "$APK" | head -8
fi

echo "==> Artefatos"
ls -lh "$AAB" "$APK"
echo "OK. AAB: $AAB"
echo "OK. APK: $APK"
