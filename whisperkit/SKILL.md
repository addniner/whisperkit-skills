---
name: whisperkit
description: Apple Silicon 네이티브 음성 트랜스크립션 + 화자 분리 (WhisperKit CLI 기반)
---

# WhisperKit 트랜스크립션 + 화자 분리

Apple Silicon Neural Engine 최적화 음성-텍스트 변환 도구.
WhisperKit CLI 기반으로 화자 분리(SpeakerKit) 내장.

## 언제 사용

- 오디오/비디오 파일 트랜스크립션
- 화자 분리 (누가 말했는지 구분)
- 회의록, 인터뷰, 팟캐스트 등 음성 → 텍스트 변환

**트리거 키워드:**
"트랜스크립션", "음성 변환", "화자 분리", "회의록", "transcribe", "diarize",
"자막", "누가 말했는지", "스크립트", "speech to text", "녹음", "inbox"

## 요구사항

- macOS 13+ (Apple Silicon)
- `brew install whisperkit-cli`
- ffmpeg/ffprobe (`brew install ffmpeg`)

## 환경 사전 검사

트랜스크립션 실행 전, 아래 명령으로 핵심 의존성을 확인한다:

```bash
which whisperkit-cli && which ffprobe
```

둘 중 하나라도 없으면 **setup 스킬**을 먼저 실행한다.

## 플로우

1. 사용자가 `inbox/`에 음성파일을 넣음
2. 에이전트가 `inbox/` 내 파일을 감지
3. ffprobe로 `creation_time` 메타데이터에서 녹음 날짜 추출
4. `rec_{YYYY-MM-DD}_{NNN}/` 폴더 생성 (같은 날짜면 넘버링 증가)
5. 오디오 파일을 해당 폴더로 이동 (`audio.{ext}`)
6. `whisperkit-cli`로 트랜스크립션 + 화자 분리 실행
7. stdout에서 SPEAKER 라인 파싱 → `transcript.txt` 생성
8. 트랜스크립트 내용 기반으로 `summary.md` 요약 생성

## 프로젝트 구조

```
project/
├── inbox/                      # 음성파일 드롭 (처리 전)
├── rec_2026-03-30_001/         # 처리 완료된 녹음
│   ├── audio.m4a
│   ├── transcript.txt
│   ├── summary.md
│   └── data/                   # 중간 파일
│       ├── raw.txt
│       ├── audio.json
│       └── audio.srt
└── .gitignore
```

## 에이전트 실행 가이드

### Step 1: inbox 파일 확인

```bash
ls inbox/
```

### Step 2: 녹음 날짜 추출

```bash
ffprobe -v quiet -show_entries format_tags=creation_time -of csv=p=0 "inbox/파일명"
```

### Step 3: 폴더명 결정

- 추출된 날짜로 `YYYY-MM-DD` 형식
- 같은 날짜 폴더가 이미 있으면 넘버링 증가 (`_001`, `_002`, ...)
- 예: `rec_2026-03-30_001/`

### Step 4: 폴더 생성 + 오디오 이동

```bash
mkdir -p "rec_2026-03-30_001/data"
mv "inbox/파일명.m4a" "rec_2026-03-30_001/audio.m4a"
```

### Step 5: 트랜스크립션 + 화자 분리

```bash
whisperkit-cli transcribe \
  --audio-path "rec_2026-03-30_001/audio.m4a" \
  --model large-v3 \
  --language ko \
  --diarization \
  --report \
  --report-path "rec_2026-03-30_001/data/"
```

- stdout을 캡처하여 임시 파일에 저장
- `---- Speaker Diarization Results ----` 이후의 SPEAKER 라인을 파싱

### Step 6: transcript.txt 생성

SPEAKER 라인 파싱 규칙:
```
SPEAKER 파일명 채널 시작시간 길이 텍스트 <NA> 화자라벨 <NA> <NA>
```

변환 형식:
```
[화자 A] (HH:MM:SS)
텍스트 내용
```

- 시작시간(초)을 `HH:MM:SS`로 변환
- 화자가 바뀔 때만 새 라벨 출력
- macOS에서는 `grep -P` 대신 `sed` 사용

### Step 7: summary.md 생성

transcript.txt를 읽고 다음을 포함하는 요약 작성:
- 참석자 목록 (화자별 역할 추정)
- 주요 안건별 정리 (타임스탬프 포함)
- 핵심 액션 아이템
- 일정/마감일

## 주의사항

- 화자 분리 결과는 JSON/SRT에 포함되지 않음 — stdout의 SPEAKER 라인에서만 추출 가능
- `--report-path`의 디렉토리가 미리 존재해야 함 (mkdir 필수)
- 한국어가 기본이지만, 다른 언어면 `--language` 변경
- 45분 오디오 기준 약 12분 소요 (Apple Silicon, 모델 캐시 후)
- 첫 실행 시 모델 다운로드 ~1.5GB
