ARG BASE_VARIANT=runtime
ARG PYTORCH_VERSION=2.13.0
ARG CUDA_VERSION=13.0

FROM pytorch/pytorch:${PYTORCH_VERSION}-cuda${CUDA_VERSION}-cudnn9-${BASE_VARIANT}

ARG COMFYUI_VERSION=0.42.1
ARG COMFYUI_API_VERSION=1.19.2
ARG CUDA_VERSION=13.0
ARG TORCHAUDIO_VERSION=2.11.0

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    UV_BREAK_SYSTEM_PACKAGES=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir uv \
    && uv pip install --no-cache-dir --system "comfy-cli==1.5.1"

WORKDIR /opt
RUN git clone --depth 1 --branch "v${COMFYUI_VERSION}" https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /opt/ComfyUI
RUN python -c 'import importlib.metadata as m; print("\n".join(f"{p}=={m.version(p)}" for p in ("torch", "torchvision")))' > /opt/pytorch-constraints.txt \
    && uv pip install --no-cache-dir --system -c /opt/pytorch-constraints.txt "torchaudio==${TORCHAUDIO_VERSION}" --index-url "https://download.pytorch.org/whl/cu${CUDA_VERSION//./}" \
    && python -c 'import importlib.metadata as m; print("torchaudio==" + m.version("torchaudio"))' >> /opt/pytorch-constraints.txt \
    && uv pip install --no-cache-dir --system -c /opt/pytorch-constraints.txt -r requirements.txt

ENV COMFY_HOME=/opt/ComfyUI \
    MODEL_DIR=/opt/ComfyUI/models \
    OUTPUT_DIR=/opt/ComfyUI/output \
    INPUT_DIR=/opt/ComfyUI/input \
    WORKFLOW_DIR=/workflows \
    WARMUP_PROMPT_FILE=/opt/flux3/runtime/flux3-klein-distilled-bf16-warmup-api.json \
    PORT=3000 \
    STARTUP_CHECK_MAX_TRIES=600 \
    CMD="comfy --workspace /opt/ComfyUI launch -- --listen 0.0.0.0" \
    BASE="" \
    CUDA_MODULE_LOADING=LAZY \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

RUN comfy --skip-prompt tracking disable \
    && comfy --skip-prompt set-default /opt/ComfyUI

WORKDIR /opt
ADD https://github.com/SaladTechnologies/comfyui-api/releases/download/${COMFYUI_API_VERSION}/comfyui-api /opt/comfyui-api

COPY start-flux3.sh /opt/flux3/start-flux3.sh
COPY prepare-workflow.py /opt/flux3/prepare-workflow.py
COPY model-lock.json /opt/flux3/model-lock.json
COPY prompt-upsampler-system.txt /opt/flux3/prompt-upsampler-system.txt
COPY workflows/flux3-klein-distilled-bf16-api.template.json /opt/flux3/workflows/flux3-klein-distilled-bf16-api.template.json

RUN chmod 0755 /opt/comfyui-api /opt/flux3/start-flux3.sh /opt/flux3/prepare-workflow.py \
    && mkdir -p /opt/flux3/runtime /opt/ComfyUI/models/diffusion_models /opt/ComfyUI/models/text_encoders /opt/ComfyUI/models/vae /workflows

EXPOSE 3000

CMD ["/opt/flux3/start-flux3.sh"]

