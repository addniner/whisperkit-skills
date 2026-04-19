---
name: whisperkit
description: "Apple Silicon 네이티브 음성-텍스트 변환 + 화자 분리. 사용자가 오디오/비디오 파일을 트랜스크립션하거나, 회의록/인터뷰/팟캐스트를 텍스트로 만들거나, 누가 말했는지 구분하거나, 자막을 생성하거나, inbox에 파일을 넣었을 때 사용한다. '트랜스크립션 해줘', '회의 녹음 정리해줘', '이 파일 텍스트로 변환해줘', 'inbox에 파일 넣었어', '화자 분리해줘' 등의 요청에 트리거된다."
---

# WhisperKit 트랜스크립션 + 화자 분리

WhisperKit CLI 기반 음성-텍스트 변환 도구. Apple Silicon Neural Engine에서 온디바이스로 동작하며, 화자 분리(SpeakerKit)를 내장하고 있어 별도 Python 의존성 없이 `brew install` 하나로 전체 파이프라인이 완성된다.

## 요구사항

- macOS 13+ (Apple Silicon 전용 — Intel Mac 미지원)
- `whisperkit-cli` (`brew install whisperkit-cli`)
- `ffmpeg`/`ffprobe` (`brew install ffmpeg`)

**CRITICAL:** 실행 전 반드시 의존성을 확인한다:

```bash
which whisperkit-cli && which ffprobe
```

둘 중 하나라도 없으면 **setup 스킬을 먼저 실행**한다. 의존성 없이 진행하면 안 된다.

## 플로우 요약

```
inbox/ → ffprobe 날짜 추출 → rec_{날짜}_{번호}/ 생성 → whisperkit-cli 실행
→ stdout SPEAKER 파싱 → transcript.txt → summary.md
```

## 출력 구조

```
rec_2026-03-30_001/
├── audio.m4a           # 원본 오디오 (inbox에서 이동)
├── transcript.txt      # 화자 분리된 최종 트랜스크립트
├── summary.md          # AI 요약 (참석자, 안건, 액션아이템)
└── data/               # 중간 산출물
    ├── raw.txt         # whisperkit-cli stdout 전체 캡처
    ├── audio.json      # 워드 단위 타임스탬프, 신뢰도 점수
    └── audio.srt       # SRT 자막 파일
```

## 에이전트 실행 가이드

### Step 1: inbox 파일 확인

```bash
ls inbox/
```

inbox가 비어 있으면 사용자에게 파일을 넣어달라고 안내한다.

### Step 2: 녹음 날짜 추출

```bash
ffprobe -v quiet -show_entries format_tags=creation_time -of csv=p=0 "inbox/파일명"
```

**IMPORTANT:** `creation_time` 메타데이터가 없는 파일이 있다. 이 경우:
1. 파일의 수정일(`stat -f "%Sm" -t "%Y-%m-%d"`)을 대신 사용
2. 그마저도 신뢰할 수 없으면 오늘 날짜 사용
3. 사용자에게 날짜를 확인받는다

### Step 3: 폴더명 결정

- 추출된 날짜로 `YYYY-MM-DD` 형식
- 같은 날짜 폴더가 이미 있으면 넘버링 증가 (`_001`, `_002`, ...)

```bash
# 예: rec_2026-03-30_001이 이미 있으면 _002로 생성
mkdir -p "rec_2026-03-30_002/data"
```

### Step 4: 오디오 이동

```bash
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
  --report-path "rec_2026-03-30_001/data/" \
  2>&1 | tee "rec_2026-03-30_001/data/raw.txt"
```

**CRITICAL:** stdout을 반드시 캡처해야 한다. 화자 분리 결과는 JSON/SRT에 포함되지 않고 **stdout에서만** 출력된다.

| 파라미터 | 설명 | 비고 |
|----------|------|------|
| `--model` | Whisper 모델 | `large-v3` 권장 (정확도 최고) |
| `--language` | 언어 코드 | `ko`, `en`, `ja`, `zh` 등 |
| `--diarization` | 화자 분리 활성화 | 없으면 화자 구분 불가 |
| `--report` | JSON/SRT 리포트 생성 | |
| `--report-path` | 리포트 저장 경로 | **디렉토리가 미리 존재해야 함** |

**다국어 처리:**
- 한국어가 기본. 다른 언어면 `--language` 변경
- 언어를 모르면 `--language auto`로 자동 감지 가능
- 다국어 혼용 음성은 주요 언어 하나를 지정하는 것이 정확도가 높다

**소요 시간 참고:**
- 45분 오디오 기준 약 12분 (Apple Silicon, 모델 캐시 후)
- 첫 실행 시 large-v3 모델 다운로드 ~1.5GB

### Step 6: transcript.txt 생성

`scripts/parse-speakers.sh`를 사용하거나, 아래 규칙에 따라 직접 파싱한다.

#### SPEAKER 라인 형식

stdout의 `---- Speaker Diarization Results ----` 이후에 나오는 라인:

```
SPEAKER audio 1 0.020 2.680 반려돌의 의미가 있으니까 <NA> A <NA> <NA>
│       │     │ │     │     │                          │    │
│       │     │ │     │     텍스트                     │    화자라벨
│       │     │ │     길이(초)                         구분자
│       │     │ 시작시간(초)
│       │     채널
│       파일명
식별자
```

#### 변환 규칙

```
[화자 A] (HH:MM:SS)
텍스트 내용
```

- 시작시간(초)을 `HH:MM:SS`로 변환
- **화자가 바뀔 때만** 새 라벨 출력 (같은 화자 연속이면 텍스트만 이어붙임)
- 화자 라벨은 원본 그대로 사용 (`A`, `B`, `C`, ...)

#### 파싱 스크립트 사용

```bash
bash scripts/parse-speakers.sh "rec_2026-03-30_001/data/raw.txt" > "rec_2026-03-30_001/transcript.txt"
```

### Step 7: summary.md 생성

transcript.txt를 읽고 아래 구조로 요약을 작성한다:

```markdown
# 회의 요약

- **일시:** YYYY-MM-DD
- **참석자:** 화자 A~N (N명)

## 참석자 역할 (추정)

| 화자 | 역할 추정 |
|------|-----------|
| A    | ...       |

## 주요 안건

### 1. 안건명 (HH:MM:SS~HH:MM:SS)
- 논의 내용 요약
- 결정 사항

## 액션 아이템

| 담당 | 내용 | 기한 |
|------|------|------|
| 화자 A | ... | ... |
```

## 실패 대응

| 상황 | 원인 | 대응 |
|------|------|------|
| `whisperkit-cli: command not found` | 미설치 | setup 스킬 실행 |
| `Error: Could not load model` | 모델 미다운로드 | 네트워크 확인 후 재실행 (자동 다운로드됨) |
| stdout에 SPEAKER 라인 없음 | 화자 1명이거나 diarization 실패 | `--diarization` 플래그 확인. 화자 1명이면 `[화자 A]`로 단일 처리 |
| `creation_time` 메타데이터 없음 | 녹음 앱이 메타데이터 미기록 | Step 2의 fallback 절차 따름 |
| 트랜스크립션 결과가 빈 텍스트 | 무음 파일 또는 지원하지 않는 코덱 | `ffprobe`로 오디오 스트림 존재 여부 확인 |
| 한국어인데 영어로 인식 | `--language` 미지정 | 명시적으로 `--language ko` 지정 |
| `--report-path` 에러 | 디렉토리 미존재 | `mkdir -p` 먼저 실행 |

## 하면 안 되는 것

- **`grep -P` 사용 금지** — macOS에는 PCRE 미지원. `sed` 또는 `awk` 사용
- **JSON/SRT에서 화자 정보 추출 시도 금지** — 화자 분리 결과는 stdout에만 존재
- **stdout 캡처 없이 실행 금지** — 화자 분리 결과가 유실됨
- **`--report-path`에 파일 경로 지정 금지** — 디렉토리 경로만 허용
- **inbox 원본 삭제 금지** — `mv`로 이동만 한다 (사용자가 원본을 다시 찾을 수 있어야 함. 이동 전 사용자에게 확인)
