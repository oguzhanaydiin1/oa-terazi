#!/usr/bin/env bash
# Windows ve Android klasörlerini üretir ve Terazi ayarlarını uygular.
# Kullanım (proje kökünde): bash scripts/platform_hazirla.sh windows,android
set -euo pipefail

PLATFORMS="${1:-windows,android}"

flutter create --platforms="$PLATFORMS" --org dev.oalabs --project-name terazi .
# flutter create varsayılan bir test dosyası ekler; bizim uygulamamıza uymuyor.
rm -f test/widget_test.dart

MAIN=windows/runner/main.cpp
if [[ -f "$MAIN" ]]; then
  # Pencere başlığı ve açılış boyutu
  sed -i 's/window.Create(L"terazi"/window.Create(L"Terazi"/' "$MAIN"
  sed -i 's/Win32Window::Size size(1280, 720);/Win32Window::Size size(1280, 820);/' "$MAIN"
  grep -q 'L"Terazi"' "$MAIN" || { echo "::error::main.cpp pencere başlığı değiştirilemedi"; exit 1; }
fi

if [[ -f windows/runner/Runner.rc ]]; then
  sed -i 's/VALUE "CompanyName", "dev.oalabs"/VALUE "CompanyName", "OA Labs"/' windows/runner/Runner.rc
  sed -i 's/VALUE "FileDescription", "terazi"/VALUE "FileDescription", "Terazi: Gelir Gider Takibi"/' windows/runner/Runner.rc
  sed -i 's/VALUE "ProductName", "terazi"/VALUE "ProductName", "Terazi"/' windows/runner/Runner.rc
fi

if [[ -f android/app/src/main/AndroidManifest.xml ]]; then
  python3 scripts/android_ayarla.py
fi

echo "Platform ayarları uygulandı: $PLATFORMS"
