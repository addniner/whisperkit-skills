---
name: setup
description: "WhisperKit 트랜스크립션 환경을 중앙 검사 스크립트로 진단하고 필요한 설치를 안내한다. 프로젝트를 처음 클론했거나, 'command not found' 오류가 발생했거나, '설치해줘', '환경 세팅해줘', '셋업', 'setup', '의존성 확인', 'brew install' 등을 요청할 때 사용한다. whisperkit 스킬의 환경 사전 검사에 항상 이 스킬의 check-env.sh를 사용한다."
---

# 환경 검사 및 셋업

`scripts/check-env.sh`를 환경 판정의 단일 진실 공급원으로 사용한다. 에이전트가 `uname`, `which`, 캐시 경로 같은 검사를 따로 반복하면 문서와 실제 판정이 어긋날 수 있으므로, 스크립트의 JSON 결과를 읽고 필요한 후속 행동만 수행한다.

## 환경 검사

프로젝트 루트에서 에이전트용 JSON 검사를 실행한다.

```bash
bash scripts/check-env.sh --json
```

사용자에게 직접 보여줄 결과가 필요하면 표 형식을 사용한다.

```bash
bash scripts/check-env.sh
```

스크립트는 다음 항목을 한 번에 검사한다.

- Apple Silicon 여부
- macOS 14 이상 여부
- Homebrew 설치 및 PATH 상태
- 깨끗한 새 zsh 로그인 셸에서 Homebrew가 인식되는지
- `whisperkit-cli`
- `ffmpeg`와 `ffprobe`
- WhisperKit 모델 캐시

스크립트는 읽기 전용이다. 패키지를 설치하거나 디렉토리를 생성하지 않는다.

## JSON 계약

```json
{
  "schema_version": 1,
  "platform_ok": true,
  "has_fail": false,
  "results": [
    {
      "name": "whisperkit-cli",
      "status": "pass",
      "detail": "/opt/homebrew/bin/whisperkit-cli"
    }
  ]
}
```

- `platform_ok=false`: 즉시 중단하고 Apple Silicon 및 macOS 14+ 요구사항을 안내한다.
- `has_fail=true`: 필수 실행 명령이 없으므로 STT를 시작하지 않는다.
- `status=warn`: 실행을 막지 않는다. `detail`에 따라 필요한 준비만 수행한다.
- 종료 코드 `0`: 필수 검사 통과
- 종료 코드 `1`: 필수 명령 누락
- 종료 코드 `2`: 플랫폼 비호환

검사 결과를 받은 뒤 같은 항목을 수동 명령으로 재검사하지 않는다. 환경을 변경한 경우에만 `check-env.sh --json`을 다시 실행해 최종 상태를 확인한다.

## 결과별 조치

### Homebrew가 현재 PATH에 없음

결과가 `설치됨, PATH 미설정`이면 설치를 반복하지 않고 현재 셸에 Homebrew를 활성화한다.

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Homebrew가 새 로그인 셸에서 인식되지 않음

`Homebrew 로그인 셸` 결과가 `warn`이면 새 터미널에 설정이 적용되지 않은 상태다. 사용자 확인 후 설정을 중복 없이 추가한다.

```bash
BREW_SHELLENV_LINE='eval "$(/opt/homebrew/bin/brew shellenv)"'
grep -qxF "$BREW_SHELLENV_LINE" ~/.zprofile 2>/dev/null \
  || printf '%s\n' "$BREW_SHELLENV_LINE" >> ~/.zprofile
```

### Homebrew가 없고 필수 명령도 누락됨

Homebrew는 권장 설치 수단이다. 설치 전에 사용자 승인을 받는다.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

설치 프로그램이 출력하는 `Next steps`를 우선 따른다. Apple Silicon 기본 경로에서는 보통 다음 명령으로 현재 셸과 이후 셸에 PATH를 적용한다.

```bash
BREW_SHELLENV_LINE='eval "$(/opt/homebrew/bin/brew shellenv)"'
grep -qxF "$BREW_SHELLENV_LINE" ~/.zprofile 2>/dev/null \
  || printf '%s\n' "$BREW_SHELLENV_LINE" >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Homebrew 설치가 개발 도구 오류로 실패

Homebrew 설치 출력이 Xcode Command Line Tools 누락을 가리키면 사용자 승인 후 설치한다.

```bash
xcode-select --install
```

설치 완료를 사용자가 확인하면 Homebrew 설치를 다시 실행하고, 위 `brew shellenv` 설정을 적용한다.

`brew doctor`는 일반적인 Homebrew 문제 진단에 사용할 수 있지만 `.zprofile` 영구 적용 여부의 단일 판정으로 사용하지 않는다. `check-env.sh`가 깨끗한 새 zsh 로그인 셸에서 `command -v brew`를 실행한 결과를 기준으로 삼는다.

### 필수 명령 누락

Homebrew가 활성화된 뒤, 검사 결과에서 누락된 항목만 설치하도록 사용자 승인을 받는다.

```bash
brew install whisperkit-cli
brew install ffmpeg
```

`ffmpeg` formula에 `ffprobe`가 포함되므로 별도 설치하지 않는다.

### 모델 캐시 없음

실행을 막지 않는다. 첫 STT에서 모델 약 1.5GB를 다운로드할 수 있으므로 네트워크와 소요 시간을 사용자에게 알린다.

## 실행 순서

1. `check-env.sh --json`을 한 번 실행한다.
2. `platform_ok`와 `has_fail`, 각 `status`를 읽는다.
3. 설치가 필요하면 사용자 승인을 받은 뒤 누락 항목만 설치한다.
4. 환경이 바뀌었으면 스크립트를 다시 실행한다.
5. `platform_ok=true`, `has_fail=false`가 확인되면 작업을 계속한다.

## 하면 안 되는 것

- 스크립트 실행 전에 동일한 환경 검사를 개별 명령으로 반복하지 않는다.
- 사용자 확인 없이 Homebrew나 formula를 설치하지 않는다.
- Homebrew가 없다는 이유만으로 실패 처리하지 않는다. 필수 명령의 존재 여부가 기준이다.
- Homebrew를 `sudo`로 설치하지 않는다.
- Intel Mac에서 Rosetta 우회를 시도하지 않는다.
