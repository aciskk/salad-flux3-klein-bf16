#!/usr/bin/env bash
set -Eeuo pipefail

MODEL_ROOT="${MODEL_DIR:-/opt/ComfyUI/models}"
REVISION="feef60b0aaf63a4773ace96636ebbcf43b881312"
REPO_BASE="https://huggingface.co/black-forest-labs/flux-3-image-klein-comfy/resolve/${REVISION}"
APP_ROOT="/opt/flux3"
RUNTIME_ROOT="${APP_ROOT}/runtime"
HF_ACCESS_TOKEN="${HF_TOKEN:-}"

log() {
  printf '[flux3-start] %s\n' "$*"
}

if [[ -z "${HF_ACCESS_TOKEN}" && -r /run/secrets/hf_token ]]; then
  HF_ACCESS_TOKEN="$(< /run/secrets/hf_token)"
fi
if [[ -z "${HF_ACCESS_TOKEN}" ]]; then
  log "HF_TOKEN is required because the official FLUX.3 Klein repository is gated."
  log "Accept the model license on Hugging Face, then provide a read-only token as a secret."
  exit 1
fi

download_verified() {
  local relative_path="$1"
  local expected_size="$2"
  local expected_sha256="$3"
  local destination="${MODEL_ROOT}/${relative_path}"
  local partial="${destination}.part"
  local marker="${destination}.sha256-ok"
  local url="${REPO_BASE}/${relative_path}?download=true"
  local reserve_bytes=8000000000
  local partial_size=0
  local remaining_bytes=0
  local available_bytes=0

  mkdir -p "$(dirname "${destination}")"

  if [[ -f "${destination}" && -f "${marker}" ]] \
      && [[ "$(stat -c '%s' "${destination}")" == "${expected_size}" ]] \
      && [[ "$(<"${marker}")" == "${expected_sha256}" ]]; then
    log "Using verified cached model: ${relative_path}"
    return
  fi

  if [[ -f "${destination}" ]]; then
    log "Existing unverified model will be replaced: ${relative_path}"
    rm -f "${destination}" "${marker}"
  fi

  if [[ -f "${partial}" ]]; then
    partial_size="$(stat -c '%s' "${partial}")"
    if (( partial_size > expected_size )); then
      log "Oversized partial file will be discarded: ${relative_path}"
      rm -f "${partial}"
      partial_size=0
    fi
  fi

  remaining_bytes=$((expected_size - partial_size))
  available_bytes="$(df -PB1 "${MODEL_ROOT}" | awk 'NR==2 {print $4}')"
  if (( available_bytes < remaining_bytes + reserve_bytes )); then
    log "Not enough free disk for ${relative_path}: ${available_bytes} bytes available, $((remaining_bytes + reserve_bytes)) required including reserve"
    return 1
  fi

  if (( partial_size < expected_size )); then
    log "Downloading gated model ${relative_path} (${partial_size}/${expected_size} bytes already present)"
    curl --location --fail --show-error --silent \
      --retry 8 --retry-delay 5 --retry-all-errors \
      --header "Authorization: Bearer ${HF_ACCESS_TOKEN}" \
      --continue-at - --output "${partial}" "${url}"
  else
    log "A complete partial file is present; verifying ${relative_path}"
  fi

  if [[ "$(stat -c '%s' "${partial}")" != "${expected_size}" ]]; then
    log "Size mismatch for ${relative_path}; removing partial file"
    rm -f "${partial}"
    return 1
  fi

  if ! printf '%s  %s\n' "${expected_sha256}" "${partial}" | sha256sum --check --status; then
    log "SHA256 mismatch for ${relative_path}; removing corrupt partial file"
    rm -f "${partial}" "${marker}"
    return 1
  fi
  mv -f "${partial}" "${destination}"
  printf '%s' "${expected_sha256}" > "${marker}"
  log "Verified ${relative_path}"
}

mkdir -p "${MODEL_ROOT}" "${RUNTIME_ROOT}"

python "${APP_ROOT}/prepare-workflow.py" \
  --template "${APP_ROOT}/workflows/flux3-klein-distilled-bf16-api.template.json" \
  --system-prompt "${APP_ROOT}/prompt-upsampler-system.txt" \
  --output "/workflows/flux3-klein-distilled-bf16-api.json"

python "${APP_ROOT}/prepare-workflow.py" \
  --template "${APP_ROOT}/workflows/flux3-klein-distilled-bf16-api.template.json" \
  --system-prompt "${APP_ROOT}/prompt-upsampler-system.txt" \
  --output "${RUNTIME_ROOT}/flux3-klein-distilled-bf16-warmup-api.json" \
  --warmup

download_verified \
  "diffusion_models/flux3-image-klein-bf16.safetensors" \
  "11097404512" \
  "c3e9813cdd049c831c836b2e9db61150e49a93fc1a4c63b256494642fee0bd7c"

download_verified \
  "text_encoders/qwen3vl_4b_bf16.safetensors" \
  "8875719408" \
  "f0b24fc5c8d7c0ea6ca909da14c20af5cac53f22506be942c6c956f838b9630f"

download_verified \
  "text_encoders/qwen3.5_9b_flux3_prompt_upsampler_w4a8.safetensors" \
  "6724090780" \
  "e5d85a7421d197bf5a12474511936ecabce19a833252f16e9310a983194a4458"

download_verified \
  "vae/flux2-vae.safetensors" \
  "336211292" \
  "868fe7b343cc8f3a19dbcfcafbc3d5f888802be3f89bd81b65b3621a066ce8f3"

unset HF_ACCESS_TOKEN HF_TOKEN
log "All FLUX.3 Klein files are ready; starting ComfyUI API"
exec /opt/comfyui-api
