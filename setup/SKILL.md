---
name: setup
description: "WhisperKit 트랜스크립션 환경을 자동 감지하고 셋업한다. 프로젝트를 처음 클론했을 때, 'whisperkit-cli: command not found' 에러가 났을 때, '설치해줘', '환경 세팅해줘', '셋업', 'setup', '의존성', 'brew install' 등을 요청할 때 사용한다. whisperkit 스킬 실행 시 의존성이 없으면 이 스킬이 자동으로 먼저 트리거된다."
---

# 환경 자동 감지 및 셋업

프로젝트 의존성을 한 번에 검사하고, 누락된 항목을 설치하는 스킬.
모든 검사를 먼저 수행한 뒤 결과를 테이블로 보여주고, 사용자 확인 후 설치를 진행한다.

## 감지 항목

아래 항목을 **병렬로** 검사한다. 단, 플랫폼 호환성이 FAIL이면 나머지는 스킵한다.

### 1. 플랫폼 호환성

```bash
uname -m          # 기대값: arm64
sw_vers -productVersion  # 기대값: 13.0 이상
```

**CRITICAL:** `x86_64`이면 즉시 중단한다. WhisperKit은 Apple Silicon Neural Engine 전용이며, Intel Mac에서는 동작하지 않는다. Rosetta 2로도 실행할 수 없다.

### 2. Homebrew

```bash
which brew
```

설치 명령:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Note:** Homebrew 설치 시 Xcode Command Line Tools도 함께 설치된다. 네트워크 상태에 따라 수 분 소요될 수 있다.

### 3. whisperkit-cli

```bash
which whisperkit-cli
```

설치 명령:
```bash
brew install whisperkit-cli
```

### 4. ffmpeg / ffprobe

```bash
which ffmpeg && which ffprobe
```

설치 명령:
```bash
brew install ffmpeg
```

**Note:** ffmpeg을 설치하면 ffprobe도 함께 설치된다. 별도 설치 불필요.

### 5. WhisperKit 모델 캐시

```bash
ls ~/Library/Caches/huggingface/hub/models--argmaxinc--whisperkit-coreml/ 2>/dev/null \
  || ls ~/.cache/huggingface/hub/models--argmaxinc--whisperkit-coreml/ 2>/dev/null
```

- 없으면 **WARN** — "첫 트랜스크립션 시 large-v3 모델이 자동 다운로드됩니다 (~1.5GB). Wi-Fi 환경 권장."
- 미리 다운로드하고 싶으면:
```bash
whisperkit-cli transcribe --model large-v3 --audio-path /dev/null 2>&1 || true
```

### 6. inbox 디렉토리

```bash
[ -d "inbox" ] || mkdir -p inbox
```

자동 생성. 사용자 확인 불필요.

## 실행 가이드

### 검사 스크립트

`scripts/check-env.sh`로 모든 항목을 한 번에 검사할 수 있다:

```bash
bash scripts/check-env.sh          # 터미널 출력
bash scripts/check-env.sh --json   # JSON 출력 (프로그래밍용)
```

종료 코드: `0` = 모두 통과, `1` = 필수 항목 FAIL, `2` = 플랫폼 비호환

### 출력 형식

모든 검사 후 결과를 테이블로 보여준다:

```
## 환경 검사 결과

| 항목                  | 상태 | 비고                          |
|-----------------------|------|-------------------------------|
| Apple Silicon         | PASS | arm64                         |
| macOS 버전            | PASS | 15.3                          |
| Homebrew              | PASS | /opt/homebrew/bin/brew        |
| whisperkit-cli        | FAIL | 미설치                        |
| ffmpeg/ffprobe        | PASS | /opt/homebrew/bin/ffmpeg      |
| WhisperKit 모델 캐시  | WARN | 첫 실행 시 ~1.5GB 다운로드   |
| inbox 디렉토리        | PASS | 존재                          |
```

### 동작 순서

1. **전체 검사 수행** — 모든 항목을 한 번에 검사하고 테이블로 출력
2. **FAIL 항목 설치 제안** — "다음 항목을 설치하시겠습니까?" 형태로 확인
3. **사용자 승인 후 설치** — 승인된 항목만 설치
4. **재검사** — 설치 완료 후 전체 재검사하여 최종 상태 확인

**IMPORTANT:** 모든 설치 명령은 사용자 확인 후 실행한다. 자동 설치하지 않는다.

## 실패 대응

| 상황 | 대응 |
|------|------|
| Intel Mac (`x86_64`) | 즉시 중단. "Apple Silicon Mac이 필요합니다" 안내 |
| macOS 12 이하 | "macOS 13 이상으로 업그레이드 필요" 안내 |
| Homebrew 설치 실패 | Xcode CLT 수동 설치 안내: `xcode-select --install` |
| brew install 타임아웃 | 네트워크 확인 안내, `brew update` 후 재시도 |
| 모델 다운로드 실패 | HuggingFace 네트워크 접근 확인, 프록시 설정 확인 |

## 하면 안 되는 것

- **사용자 확인 없이 brew install 실행 금지** — 시스템 패키지 설치는 반드시 사용자 동의 필요
- **Intel Mac에서 Rosetta 우회 시도 금지** — WhisperKit CoreML은 Neural Engine 전용
- **sudo로 Homebrew 설치 금지** — Homebrew는 사용자 권한으로 설치해야 함
