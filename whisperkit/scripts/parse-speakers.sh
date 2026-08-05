#!/bin/bash
# WhisperKit stdout에서 SPEAKER 라인을 파싱하여 transcript.txt 형식으로 변환
#
# 사용법:
#   bash parse-speakers.sh raw.txt > transcript.txt
#
# 입력: whisperkit-cli stdout 캡처 파일 (raw.txt)
# 출력: [화자 A] (HH:MM:SS)\n텍스트 형식
#
# SPEAKER 라인 형식:
#   SPEAKER audio 1 시작시간 길이 텍스트 <NA> 화자라벨 <NA> <NA>

set -euo pipefail

RAW_FILE="${1:?사용법: bash parse-speakers.sh <raw.txt 경로>}"

if [ ! -f "$RAW_FILE" ]; then
    echo "오류: 파일을 찾을 수 없습니다: $RAW_FILE" >&2
    exit 1
fi

# SPEAKER 라인이 있는지 확인
if ! grep -q "^SPEAKER " "$RAW_FILE"; then
    echo "오류: SPEAKER 라인을 찾을 수 없습니다. 화자 분리 결과가 없는 파일입니다." >&2
    echo "힌트: whisperkit-cli 실행 시 --diarization 플래그를 확인하세요." >&2
    exit 1
fi

PREV_SPEAKER=""

# "---- Speaker Diarization Results ----" 이후의 SPEAKER 라인만 파싱
sed -n '/Speaker Diarization Results/,$ { /^SPEAKER /p; }' "$RAW_FILE" | while IFS= read -r line; do
    # SPEAKER 파일명 채널 시작시간 길이 텍스트 <NA> 화자라벨 <NA> <NA>
    START_SEC=$(echo "$line" | awk '{print $4}')
    SPEAKER_LABEL=$(echo "$line" | awk -F'<NA>' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    TEXT=$(echo "$line" | awk '{
        # 필드 6부터 <NA> 직전까지가 텍스트
        result = ""
        for (i = 6; i <= NF; i++) {
            if ($i == "<NA>") break
            if (result != "") result = result " "
            result = result $i
        }
        print result
    }')

    # 빈 텍스트 스킵
    if [ -z "$TEXT" ]; then
        continue
    fi

    # 시작시간(초) → HH:MM:SS 변환
    HOURS=$(echo "$START_SEC" | awk '{printf "%02d", int($1/3600)}')
    MINUTES=$(echo "$START_SEC" | awk '{printf "%02d", int(($1%3600)/60)}')
    TS_SECONDS=$(echo "$START_SEC" | awk '{printf "%02d", int($1%60)}')
    TIMESTAMP="${HOURS}:${MINUTES}:${TS_SECONDS}"

    # 화자가 바뀔 때만 라벨 출력
    if [ "$SPEAKER_LABEL" != "$PREV_SPEAKER" ]; then
        # 첫 줄이 아니면 빈 줄 추가
        if [ -n "$PREV_SPEAKER" ]; then
            echo ""
        fi
        echo "[화자 ${SPEAKER_LABEL}] (${TIMESTAMP})"
    fi

    echo "$TEXT"
    PREV_SPEAKER="$SPEAKER_LABEL"
done
