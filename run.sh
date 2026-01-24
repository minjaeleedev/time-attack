#!/bin/bash
set -e

swift build

# App Bundle 구조 생성 (최초 1회)
mkdir -p .build/debug/TimeAttackApp.app/Contents/MacOS
mkdir -p .build/debug/TimeAttackApp.app/Contents/Resources

# 바이너리 복사
cp .build/debug/TimeAttackApp .build/debug/TimeAttackApp.app/Contents/MacOS/

# Info.plist 복사
cp Sources/Resources/Info.plist .build/debug/TimeAttackApp.app/Contents/

# PkgInfo 생성
echo "APPL????" > .build/debug/TimeAttackApp.app/Contents/PkgInfo

# 실행
open .build/debug/TimeAttackApp.app
