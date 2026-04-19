---
name: setup
description: WhisperKit 트랜스크립션 환경 자동 감지 및 셋업 (macOS Apple Silicon)
---

# 환경 자동 감지 및 셋업

프로젝트를 처음 받은 사용자의 환경을 자동 감지하고, 누락된 의존성을 설치하는 스킬.

## 언제 사용

- 프로젝트를 처음 클론했을 때
- 트랜스크립션 실행 전 환경 확인이 필요할 때
- 의존성 문제로 에러가 발생했을 때

**트리거 키워드:**
"setup", "셋업", "설치", "환경", "세팅", "초기 설정", "처음", "install",
"환경 설정", "의존성", "dependency", "brew", "whisperkit 설치"

**자동 트리거 조건:**
whisperkit 스킬 실행 시 `whisperkit-cli` 또는 `ffprobe`가 없으면 이 스킬을 먼저 실행한다.

## 감지 항목

아래 항목을 순서대로 검사한다. 각 항목은 독립적으로 pass/fail 판정.

### 1. 플랫폼 호환성

```bash
# Apple Silicon 확인
uname -m
# 기대값: arm64
# x86_64이면 FAIL → "이 프로젝트는 Apple Silicon Mac 전용입니다"

# macOS 버전 확인
sw_vers -productVersion
# 기대값: 13.0 이상
```

### 2. Homebrew

```bash
which brew
# 없으면 FAIL → 설치 안내
```

설치 명령:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3. whisperkit-cli

```bash
which whisperkit-cli
# 없으면 FAIL → 설치
```

설치 명령:
```bash
brew install whisperkit-cli
```

### 4. ffmpeg / ffprobe

```bash
which ffmpeg && which ffprobe
# 없으면 FAIL → 설치
```

설치 명령:
```bash
brew install ffmpeg
```

### 5. WhisperKit 모델 캐시

```bash
ls ~/Library/Caches/huggingface/hub/models--argmaxinc--whisperkit-coreml/
# 또는
ls ~/.cache/huggingface/hub/models--argmaxinc--whisperkit-coreml/
```

- 없으면 WARN → "첫 트랜스크립션 시 large-v3 모델 다운로드 (~1.5GB). Wi-Fi 환경 권장."
- 모델 프리로드 원하면:
```bash
whisperkit-cli transcribe --model large-v3 --audio-path /dev/null 2>&1 || true
```

### 6. inbox 디렉토리

```bash
[ -d "inbox" ]
# 없으면 생성
mkdir -p inbox
```

## 실행 가이드

### 출력 형식

감지 결과를 테이블로 보여준다:

```
## 환경 검사 결과

| 항목                  | 상태 | 비고                          |
|-----------------------|------|-------------------------------|
| Apple Silicon         | ✅   | arm64                         |
| macOS 버전            | ✅   | 15.3                          |
| Homebrew              | ✅   | /opt/homebrew/bin/brew        |
| whisperkit-cli        | ❌   | 미설치                        |
| ffmpeg/ffprobe        | ✅   | /opt/homebrew/bin/ffmpeg      |
| WhisperKit 모델 캐시  | ⚠️   | 첫 실행 시 ~1.5GB 다운로드   |
| inbox 디렉토리        | ✅   | 존재                          |
```

### 동작 방식

1. **모든 항목 검사**를 먼저 수행 (한 번에 모아서 보여줌)
2. FAIL 항목이 있으면 **설치 여부를 사용자에게 확인** 후 진행
3. 플랫폼 호환성 FAIL이면 **나머지 검사 스킵** → 즉시 안내
4. 설치 완료 후 **재검사**하여 최종 상태 확인

### 주의사항

- Homebrew 설치는 시간이 걸릴 수 있음 (Xcode CLT 포함)
- whisperkit-cli 설치 후 첫 실행 시 모델 다운로드 발생
- 모든 설치 명령은 사용자 확인 후 실행 (자동 실행 금지)
