#!/bin/bash
# WhisperKit 트랜스크립션 환경의 단일 검사 진입점
# 이 스크립트는 읽기 전용이며 설치나 디렉토리 생성을 수행하지 않는다.
#
# 사용법:
#   bash check-env.sh          # 검사만 수행
#   bash check-env.sh --json   # JSON 형식 출력 (에이전트용)
#
# 종료 코드:
#   0 — 모든 필수 항목 통과
#   1 — 필수 항목 중 FAIL 있음
#   2 — 플랫폼 비호환 (Apple Silicon 아님 또는 macOS 14 미만)

set -euo pipefail

JSON_MODE=false
[ "${1:-}" = "--json" ] && JSON_MODE=true

# 색상 (터미널용)
if [ "$JSON_MODE" = false ]; then
    GREEN="\033[0;32m"
    RED="\033[0;31m"
    YELLOW="\033[0;33m"
    NC="\033[0m"
    PASS="${GREEN}PASS${NC}"
    FAIL="${RED}FAIL${NC}"
    WARN="${YELLOW}WARN${NC}"
    printf "| %-22s | %-4s | %s |\n" "항목" "상태" "비고"
    printf "|------------------------|------|-------------------------------|\n"
fi

HAS_FAIL=false
PLATFORM_OK=true

# 결과 저장용
declare -a RESULTS=()

add_result() {
    local name="$1" status="$2" detail="$3"
    if [ "$JSON_MODE" = true ]; then
        RESULTS+=("{\"name\":\"$name\",\"status\":\"$status\",\"detail\":\"$detail\"}")
    else
        case "$status" in
            pass) printf "| %-22s | %b | %s |\n" "$name" "$PASS" "$detail" ;;
            fail) printf "| %-22s | %b | %s |\n" "$name" "$FAIL" "$detail" ;;
            warn) printf "| %-22s | %b | %s |\n" "$name" "$WARN" "$detail" ;;
        esac
    fi
    if [ "$status" = "fail" ]; then HAS_FAIL=true; fi
}

# ─── 1. Apple Silicon ───
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    add_result "Apple Silicon" "pass" "$ARCH"
else
    add_result "Apple Silicon" "fail" "$ARCH — Apple Silicon 전용입니다"
    PLATFORM_OK=false
fi

# ─── 2. macOS 버전 ───
if command -v sw_vers &>/dev/null; then
    MACOS_VER=$(sw_vers -productVersion)
    MAJOR=$(echo "$MACOS_VER" | cut -d. -f1)
    if [ "$MAJOR" -ge 14 ]; then
        add_result "macOS 버전" "pass" "$MACOS_VER"
    else
        add_result "macOS 버전" "fail" "$MACOS_VER — macOS 14 이상 필요"
        PLATFORM_OK=false
    fi
else
    add_result "macOS 버전" "fail" "macOS가 아닙니다"
    PLATFORM_OK=false
fi

# 플랫폼 비호환이면 나머지 스킵
if [ "$PLATFORM_OK" = false ]; then
    if [ "$JSON_MODE" = true ]; then
        printf '{"schema_version":1,"platform_ok":false,"has_fail":true,"results":[%s]}\n' "$(IFS=,; echo "${RESULTS[*]}")"
    else
        echo ""
        echo "플랫폼이 호환되지 않아 나머지 검사를 건너뜁니다."
    fi
    exit 2
fi

# ─── 3. Homebrew ───
if command -v brew &>/dev/null; then
    add_result "Homebrew" "pass" "$(command -v brew)"
elif [ -x "/opt/homebrew/bin/brew" ]; then
    add_result "Homebrew" "warn" "설치됨, PATH 미설정 — brew shellenv 적용 필요"
else
    add_result "Homebrew" "warn" "미설치 — 기존 명령이 있으면 실행 가능"
fi

# ─── 4. Homebrew 로그인 셸 설정 ───
if [ -x "/opt/homebrew/bin/brew" ]; then
    LOGIN_SHELL_BREW=$(
        PATH="/usr/bin:/bin" /bin/zsh -lic 'command -v brew' 2>/dev/null \
            | grep -Fx "/opt/homebrew/bin/brew" \
            | tail -n 1 || true
    )
    if [ "$LOGIN_SHELL_BREW" = "/opt/homebrew/bin/brew" ]; then
        add_result "Homebrew 로그인 셸" "pass" "$LOGIN_SHELL_BREW"
    else
        add_result "Homebrew 로그인 셸" "warn" "새 zsh에서 brew를 찾지 못함 — 셸 설정 필요"
    fi
fi

# ─── 5. whisperkit-cli ───
if command -v whisperkit-cli &>/dev/null; then
    add_result "whisperkit-cli" "pass" "$(command -v whisperkit-cli)"
else
    add_result "whisperkit-cli" "fail" "미설치 — brew install whisperkit-cli"
fi

# ─── 6. ffmpeg / ffprobe ───
if command -v ffmpeg &>/dev/null && command -v ffprobe &>/dev/null; then
    add_result "ffmpeg/ffprobe" "pass" "$(command -v ffmpeg)"
else
    add_result "ffmpeg/ffprobe" "fail" "미설치 — brew install ffmpeg"
fi

# ─── 7. WhisperKit 모델 캐시 ───
MODEL_FOUND=false
for CACHE_DIR in \
    "$HOME/Library/Caches/huggingface/hub/models--argmaxinc--whisperkit-coreml" \
    "$HOME/.cache/huggingface/hub/models--argmaxinc--whisperkit-coreml"; do
    if [ -d "$CACHE_DIR" ]; then
        MODEL_FOUND=true
        break
    fi
done

if [ "$MODEL_FOUND" = true ]; then
    add_result "WhisperKit 모델 캐시" "pass" "다운로드 완료"
else
    add_result "WhisperKit 모델 캐시" "warn" "첫 실행 시 ~1.5GB 다운로드"
fi

# ─── 출력 ───
if [ "$JSON_MODE" = true ]; then
    printf '{"schema_version":1,"platform_ok":true,"has_fail":%s,"results":[%s]}\n' "$HAS_FAIL" "$(IFS=,; echo "${RESULTS[*]}")"
else
    echo ""
    if [ "$HAS_FAIL" = true ]; then
        echo "필수 항목 중 미설치 항목이 있습니다."
    else
        echo "모든 필수 항목이 설치되어 있습니다."
    fi
fi

# 종료 코드
if [ "$HAS_FAIL" = true ]; then
    exit 1
else
    exit 0
fi
