#!/bin/bash
# Compila, instala y arranca la app en el iPhone conectado.
# Uso:  ./deploy.sh          → al iPhone
#       ./deploy.sh sim      → al simulador
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ID="com.teodorpachev.GymApp"
# Fuera del proyecto a propósito: esta carpeta vive en el Escritorio, que
# iCloud Drive sincroniza y marca con `com.apple.FinderInfo`. Ese atributo hace
# que `codesign` rechace el bundle con "resource fork... not allowed".
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/GymApp-deploy"

cd "$PROJECT_DIR"

if [ "$1" = "sim" ]; then
    SIM="iPhone 17 Pro"
    echo "▸ Compilando para el simulador…"
    build_log=$(mktemp)
    xcodebuild -project GymApp.xcodeproj -scheme GymApp -configuration Debug \
        -sdk iphonesimulator -destination "platform=iOS Simulator,name=$SIM" \
        -derivedDataPath "$DERIVED" build > "$build_log" 2>&1 || true
    grep -E "error:|BUILD" "$build_log" || true
    if ! grep -q "BUILD SUCCEEDED" "$build_log"; then
        echo "✗ La compilación ha fallado: no se instala nada."
        exit 1
    fi

    xcrun simctl boot "$SIM" 2>/dev/null || true
    open -a Simulator
    xcrun simctl install "$SIM" "$DERIVED/Build/Products/Debug-iphonesimulator/GymApp.app"
    xcrun simctl launch "$SIM" "$BUNDLE_ID"
    echo "▸ Listo en el simulador."
    exit 0
fi

# Coge el primer iPhone conectado. Se busca el identificador por su forma de
# UUID: las columnas de `devicectl` llevan nombres con espacios ("iPhone 16
# Pro"), así que contar campos con awk da el número del modelo, no el id.
UDID=$(xcrun devicectl list devices 2>/dev/null \
    | grep -i iPhone | grep -i connected \
    | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' \
    | head -1)

if [ -z "$UDID" ]; then
    echo "✗ No hay ningún iPhone conectado. Enchúfalo y desbloquéalo."
    exit 1
fi

echo "▸ Compilando y firmando para el iPhone…"
build_log=$(mktemp)
xcodebuild -project GymApp.xcodeproj -scheme GymApp -configuration Debug \
    -destination "platform=iOS,id=$UDID" -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates build > "$build_log" 2>&1 || true
grep -E "error:|BUILD" "$build_log" || true
if ! grep -q "BUILD SUCCEEDED" "$build_log"; then
    echo "✗ La compilación ha fallado: no se instala nada."
    exit 1
fi

echo "▸ Instalando…"
xcrun devicectl device install app --device "$UDID" \
    "$DERIVED/Build/Products/Debug-iphoneos/GymApp.app" > /dev/null

echo "▸ Arrancando…"
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" > /dev/null

echo "▸ Listo en el iPhone."
