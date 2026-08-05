#!/bin/bash
# 미디어의 첫 번째 오디오 스트림을 WhisperKit용 WAV로 정규화한다.
#
# 사용법:
#   bash prepare-media.sh <입력 미디어> <출력 audio.wav>

set -euo pipefail

INPUT_PATH="${1:?사용법: bash prepare-media.sh <입력 미디어> <출력 audio.wav>}"
OUTPUT_PATH="${2:?사용법: bash prepare-media.sh <입력 미디어> <출력 audio.wav>}"

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    echo "오류: ffmpeg와 ffprobe가 필요합니다. brew install ffmpeg를 실행하세요." >&2
    exit 1
fi

if [ ! -f "$INPUT_PATH" ]; then
    echo "오류: 입력 파일을 찾을 수 없습니다: $INPUT_PATH" >&2
    exit 1
fi

if [ "$INPUT_PATH" = "$OUTPUT_PATH" ]; then
    echo "오류: 입력 파일과 출력 파일은 달라야 합니다." >&2
    exit 1
fi

AUDIO_STREAM=$(ffprobe \
    -v error \
    -select_streams a:0 \
    -show_entries stream=index \
    -of csv=p=0 \
    "$INPUT_PATH" || true)

if [ -z "$AUDIO_STREAM" ]; then
    echo "오류: 오디오 스트림을 찾을 수 없습니다: $INPUT_PATH" >&2
    exit 2
fi

OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
mkdir -p "$OUTPUT_DIR"

TEMP_PATH="${OUTPUT_PATH}.tmp.$$"
cleanup() {
    if [ -f "$TEMP_PATH" ]; then
        rm -f "$TEMP_PATH"
    fi
}
trap cleanup EXIT INT TERM

ffmpeg \
    -hide_banner \
    -loglevel error \
    -nostdin \
    -i "$INPUT_PATH" \
    -map 0:a:0 \
    -vn \
    -ac 1 \
    -ar 16000 \
    -c:a pcm_s16le \
    -f wav \
    "$TEMP_PATH"

mv -f "$TEMP_PATH" "$OUTPUT_PATH"
trap - EXIT INT TERM

echo "$OUTPUT_PATH"
