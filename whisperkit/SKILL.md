---
name: whisperkit
description: "Apple Silicon에서 오디오·영상 파일을 WhisperKit용 오디오로 정규화한 뒤 음성-텍스트 변환과 화자 분리를 수행한다. 사용자가 미디어를 받아쓰기하거나, 녹취록·자막을 만들거나, 화자를 구분하거나, 회의 녹음을 요약하기 전에 전사본이 필요하거나, inbox에 미디어 파일을 넣었을 때 사용한다. '트랜스크립션 해줘', '이 영상에서 음성 추출해줘', '텍스트로 변환해줘', '화자 분리해줘', 'inbox에 파일 넣었어' 등의 요청에 트리거된다. 회의 내용의 요약·결정 사항·액션 아이템 작성은 meeting-summary 스킬에 맡긴다."
---

# WhisperKit STT + 화자 분리

WhisperKit CLI 기반 음성-텍스트 변환 스킬이다. 입력 미디어를 FFmpeg로 표준 WAV로 정규화하고 Apple Silicon Neural Engine에서 온디바이스로 전사한다. 이 스킬의 책임은 `transcript.txt` 생성까지이며 회의 요약은 작성하지 않는다.

## 요구사항

- macOS 13+ (Apple Silicon 전용 — Intel Mac 미지원)
- `whisperkit-cli` (`brew install whisperkit-cli`)
- `ffmpeg`/`ffprobe` (`brew install ffmpeg`)

실행 전 반드시 의존성을 확인한다:

```bash
which whisperkit-cli && which ffmpeg && which ffprobe
```

하나라도 없으면 `setup` 스킬을 먼저 실행한다. 의존성 없이 진행하지 않는다.

## 책임 경계

- 입력: FFmpeg가 디코딩할 수 있고 오디오 스트림이 있는 미디어 파일
- 출력: 화자와 타임스탬프가 포함된 `transcript.txt`
- 하지 않는 일: 회의 요약, 결정 사항, 액션 아이템 작성
- 회의록까지 요청받은 경우: 이 스킬을 완료한 뒤 `meeting-summary` 스킬에 `transcript.txt`를 전달

## 플로우 요약

```text
inbox/ → 미디어 검사 → 날짜 추출 → rec_{날짜}_{번호}/ 생성 → 원본 이동
→ 16 kHz mono PCM WAV 정규화 → whisperkit-cli 실행 → 화자 파싱 → transcript.txt
```

## 출력 구조

```text
rec_2026-03-30_001/
├── audio.mov           # 원본 미디어, 원래 확장자 유지
├── transcript.txt      # 화자 분리된 최종 전사본
└── data/
    ├── audio.wav       # STT용 16 kHz mono PCM 정규화 파일
    ├── raw.txt         # whisperkit-cli stdout 전체 캡처
    ├── audio.json      # 워드 단위 타임스탬프, 신뢰도 점수
    └── audio.srt       # SRT 자막 파일
```

`meeting-summary`를 이어서 실행하면 같은 폴더에 `summary.md`가 추가된다.

## 에이전트 실행 가이드

### Step 1: inbox 파일 확인

```bash
ls inbox/
```

inbox가 비어 있으면 사용자에게 파일을 넣어달라고 안내한다. 사용자가 파일 경로를 직접 지정했다면 그 파일을 사용한다.

### Step 2: 미디어와 오디오 스트림 검사

```bash
ffprobe -v error -show_entries format=format_name,duration \
  -show_entries stream=index,codec_type,codec_name,channels,sample_rate \
  -of json "inbox/파일명"
```

- 오디오 스트림이 없으면 중단하고 사용자에게 알린다.
- 오디오 스트림이 하나면 그대로 사용한다.
- 여러 오디오 스트림이 있으면 기본적으로 첫 번째를 사용하되, 언어·해설 등 트랙 선택이 결과에 영향을 줄 수 있으면 사용자에게 선택을 요청한다.
- DRM 보호, 손상 파일, FFmpeg 미지원 코덱은 우회하지 말고 변환 불가 사유를 알린다.

### Step 3: 녹음 날짜 추출

```bash
ffprobe -v quiet -show_entries format_tags=creation_time -of csv=p=0 "inbox/파일명"
```

`creation_time`이 없으면 다음 순서로 처리한다.

1. 파일 수정일(`stat -f "%Sm" -t "%Y-%m-%d"`) 사용
2. 수정일도 신뢰할 수 없으면 오늘 날짜 사용
3. 추정한 날짜를 사용자에게 알린다

### Step 4: 폴더 생성 및 원본 이동

- 날짜는 `YYYY-MM-DD` 형식을 사용한다.
- 같은 날짜 폴더가 있으면 `_001`, `_002` 순으로 사용되지 않은 번호를 선택한다.
- 원본 확장자를 유지해 `audio.<원본확장자>`로 이동한다.
- 확장자가 없으면 `audio.source`를 사용한다.

```bash
mkdir -p "rec_2026-03-30_001/data"
mv "inbox/파일명.mov" "rec_2026-03-30_001/audio.mov"
```

이동 전에 사용자에게 확인한다. 원본을 삭제하거나 덮어쓰지 않는다.

### Step 5: WhisperKit용 오디오 정규화

스킬에 포함된 `scripts/prepare-media.sh`를 사용한다.

```bash
bash scripts/prepare-media.sh \
  "rec_2026-03-30_001/audio.mov" \
  "rec_2026-03-30_001/data/audio.wav"
```

정규화 규격:

| 항목 | 값 | 이유 |
|------|----|------|
| 컨테이너 | WAV | Apple 플랫폼에서 안정적으로 디코딩 가능 |
| 코덱 | PCM signed 16-bit little-endian | 무손실·비압축 표준 입력 |
| 샘플레이트 | 16 kHz | Whisper 입력 샘플레이트에 맞춤 |
| 채널 | mono | 음성 인식 입력을 일관되게 유지 |
| 영상 | 제거 | STT에 불필요한 데이터 제외 |

정규화는 손실된 음질을 복구하는 작업이 아니다. 다양한 입력을 동일하고 예측 가능한 STT 입력으로 만드는 단계다. 원본 미디어는 그대로 보존한다.

### Step 6: 트랜스크립션 + 화자 분리

```bash
whisperkit-cli transcribe \
  --audio-path "rec_2026-03-30_001/data/audio.wav" \
  --model large-v3 \
  --language ko \
  --diarization \
  --report \
  --report-path "rec_2026-03-30_001/data/" \
  2>&1 | tee "rec_2026-03-30_001/data/raw.txt"
```

stdout을 반드시 캡처한다. 화자 분리 결과는 JSON/SRT가 아니라 stdout의 `SPEAKER` 라인에서 파싱한다.

| 파라미터 | 설명 | 비고 |
|----------|------|------|
| `--model` | Whisper 모델 | `large-v3` 권장 |
| `--language` | 언어 코드 | `ko`, `en`, `ja`, `zh` 등 |
| `--diarization` | 화자 분리 활성화 | 없으면 화자 구분 불가 |
| `--report` | JSON/SRT 리포트 생성 | |
| `--report-path` | 리포트 저장 경로 | 디렉토리를 미리 생성해야 함 |

- 한국어가 기본이며 다른 언어면 `--language`를 변경한다.
- 언어를 모르면 자동 감지를 사용한다.
- 다국어 혼용 음성은 주요 언어 하나를 지정하는 편이 일반적으로 안정적이다.
- 45분 오디오는 Apple Silicon에서 모델 캐시 후 약 12분이 걸릴 수 있다.
- 첫 실행 시 `large-v3` 모델 약 1.5GB를 다운로드할 수 있다.

### Step 7: transcript.txt 생성

`scripts/parse-speakers.sh`를 사용한다.

```bash
bash scripts/parse-speakers.sh \
  "rec_2026-03-30_001/data/raw.txt" \
  > "rec_2026-03-30_001/transcript.txt"
```

출력 형식:

```text
[화자 A] (00:00:03)
첫 번째 발화 내용

[화자 B] (00:00:11)
두 번째 발화 내용
```

- 시작 시간을 `HH:MM:SS`로 표시한다.
- 화자가 바뀔 때만 새 라벨을 출력한다.
- 화자 라벨은 원본의 `A`, `B`, `C` 등을 그대로 유지한다.

## 실패 대응

| 상황 | 원인 | 대응 |
|------|------|------|
| `whisperkit-cli: command not found` | 미설치 | `setup` 스킬 실행 |
| `ffmpeg` 또는 `ffprobe` 없음 | 미설치 | `setup` 스킬 실행 |
| 오디오 스트림 없음 | 무음 영상 또는 잘못된 입력 | 전사하지 않고 사용자에게 알림 |
| 변환 실패 | 손상, DRM, 미지원 코덱 | FFmpeg 오류를 보존하고 원본을 확인 |
| 여러 오디오 트랙 | 언어·해설 트랙 혼재 | 필요한 트랙을 확인한 뒤 선택 |
| `Error: Could not load model` | 모델 미다운로드 | 네트워크 확인 후 재실행 |
| stdout에 `SPEAKER` 라인 없음 | 화자 1명 또는 diarization 실패 | 플래그 확인 후 단일 화자 처리 여부 판단 |
| 한국어인데 영어로 인식 | 언어 미지정 | `--language ko` 명시 |
| `--report-path` 에러 | 디렉토리 미존재 | `mkdir -p` 먼저 실행 |

## 하면 안 되는 것

- 원본 미디어를 정규화 파일로 덮어쓰지 않는다.
- 오디오 스트림을 확인하지 않고 FFmpeg나 WhisperKit을 실행하지 않는다.
- `grep -P`를 사용하지 않는다. macOS 기본 grep은 PCRE를 지원하지 않는다.
- JSON/SRT에서 화자 정보를 추출하지 않는다.
- stdout 캡처 없이 화자 분리를 실행하지 않는다.
- `--report-path`에 파일 경로를 지정하지 않는다.
- 사용자의 확인 없이 inbox 원본을 이동하거나 삭제하지 않는다.
