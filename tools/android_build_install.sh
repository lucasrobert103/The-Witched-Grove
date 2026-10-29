#!/usr/bin/env bash
# Gera o APK de depuração de The Witched Grove e instala no celular conectado por USB.
# Feito para macOS (funciona no Linux também). Na primeira vez baixa o Godot 4.7.2
# e os export templates (~1 GB); nas próximas é rápido.
#
# Uso:  bash tools/android_build_install.sh
# Variáveis opcionais: GODOT (caminho do executável), ANDROID_HOME, JAVA_HOME.
set -euo pipefail

VERSION="4.7.2"
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
APK="$PROJ/build/the-witched-grove.apk"
PACKAGE="com.lucasrobert.witchedgrove"
REL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"

if [[ "$(uname)" == "Darwin" ]]; then
  GODOT_DATA="$HOME/Library/Application Support/Godot"
  : "${ANDROID_HOME:=$HOME/Library/Android/sdk}"
else
  GODOT_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/godot"
  : "${ANDROID_HOME:=$HOME/Android/Sdk}"
fi
export ANDROID_HOME
ADB="$ANDROID_HOME/platform-tools/adb"

echo "==> Projeto: $PROJ"
[[ -x "$ADB" ]] || { echo "adb não encontrado em $ADB (instale o Android SDK pelo Android Studio)"; exit 1; }

# --- Java (o apksigner precisa dele) -------------------------------------
if [[ -z "${JAVA_HOME:-}" ]]; then
  for j in "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
           "/Applications/Android Studio.app/Contents/jre/Contents/Home"; do
    [[ -d "$j" ]] && JAVA_HOME="$j" && break
  done
  if [[ -z "${JAVA_HOME:-}" && -x /usr/libexec/java_home ]]; then
    JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || true)"
  fi
fi
[[ -n "${JAVA_HOME:-}" && -d "$JAVA_HOME" ]] || { echo "Java não encontrado. Defina JAVA_HOME."; exit 1; }
export JAVA_HOME
echo "==> Java: $JAVA_HOME"

# --- Godot -----------------------------------------------------------------
if [[ -z "${GODOT:-}" ]]; then
  if [[ "$(uname)" == "Darwin" ]]; then
    for g in "/Applications/Godot.app/Contents/MacOS/Godot" "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
      if [[ -x "$g" ]] && "$g" --version 2>/dev/null | grep -q "^${VERSION}\.stable"; then GODOT="$g"; break; fi
    done
    if [[ -z "${GODOT:-}" ]]; then
      echo "==> Baixando Godot ${VERSION} para ~/Applications/Godot.app"
      mkdir -p "$HOME/Applications"
      TMP="$(mktemp -d)"
      curl -fL --progress-bar -o "$TMP/godot.zip" "$REL/Godot_v${VERSION}-stable_macos.universal.zip"
      unzip -q "$TMP/godot.zip" -d "$TMP"
      rm -rf "$HOME/Applications/Godot.app"
      mv "$TMP/Godot.app" "$HOME/Applications/Godot.app"
      xattr -dr com.apple.quarantine "$HOME/Applications/Godot.app" 2>/dev/null || true
      rm -rf "$TMP"
      GODOT="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
    fi
  else
    GODOT="$(command -v godot || true)"
    [[ -n "$GODOT" ]] || { echo "Defina GODOT com o caminho do Godot ${VERSION}."; exit 1; }
  fi
fi
echo "==> Godot: $GODOT"

# --- Export templates --------------------------------------------------------
TPL_DIR="$GODOT_DATA/export_templates/${VERSION}.stable"
if [[ ! -f "$TPL_DIR/android_debug.apk" ]]; then
  echo "==> Baixando export templates ${VERSION} (~1 GB, só na primeira vez)"
  TMP="$(mktemp -d)"
  curl -fL --progress-bar -o "$TMP/templates.tpz" "$REL/Godot_v${VERSION}-stable_export_templates.tpz"
  unzip -q "$TMP/templates.tpz" -d "$TMP"
  mkdir -p "$TPL_DIR"
  cp -R "$TMP/templates/." "$TPL_DIR/"
  rm -rf "$TMP"
fi

# --- Keystore de depuração -----------------------------------------------------
KEYSTORE="$HOME/.android/debug.keystore"
if [[ ! -f "$KEYSTORE" ]]; then
  echo "==> Criando keystore de depuração"
  mkdir -p "$HOME/.android"
  "$JAVA_HOME/bin/keytool" -genkeypair -v -keystore "$KEYSTORE" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
fi
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

# --- Importa o projeto (gera .godot/ e as configurações do editor) ------------
echo "==> Importando o projeto"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Garante os caminhos do SDK e do Java nas configurações do editor.
SETTINGS="$(ls "$GODOT_DATA"/editor_settings-4*.tres 2>/dev/null | head -n1 || true)"
if [[ -n "$SETTINGS" ]]; then
  for kv in "export/android/android_sdk_path|$ANDROID_HOME" "export/android/java_sdk_path|$JAVA_HOME"; do
    key="${kv%%|*}"; val="${kv#*|}"
    if grep -q "^$key = " "$SETTINGS"; then
      KEY="$key" VAL="$val" perl -i -pe 's/^\Q$ENV{KEY}\E = .*/$ENV{KEY} = "$ENV{VAL}"/' "$SETTINGS"
    else
      KEY="$key" VAL="$val" perl -i -pe 'if(/^\[resource\]/){$_ .= "$ENV{KEY} = \"$ENV{VAL}\"\n"}' "$SETTINGS"
    fi
  done
fi

# --- Exporta o APK -------------------------------------------------------------
echo "==> Gerando APK"
mkdir -p "$PROJ/build"
rm -f "$APK"
"$GODOT" --headless --path "$PROJ" --export-debug "Android" "$APK"
[[ -f "$APK" ]] || { echo "Falha ao gerar o APK (veja as mensagens acima)."; exit 1; }
echo "==> APK: $APK ($(du -h "$APK" | cut -f1))"

# --- Instala e abre no celular ------------------------------------------------------
echo "==> Instalando no celular (aceite o aviso na tela do aparelho se aparecer)"
"$ADB" install -r "$APK"
"$ADB" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
echo "==> Pronto! The Witched Grove instalado."
