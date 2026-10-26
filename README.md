# FLUX.3 Image Klein Distilled BF16 — SaladCloud容器

這個專案固定使用一套模型：`black-forest-labs/flux-3-image-klein-comfy`的Distilled版本。正式生圖固定16步，不安裝50步Base版，也不做兩套模型切換。

## 固定版本與權重

- ComfyUI：`v0.42.1`
- PyTorch：`2.13.0`
- CUDA：`13.0`
- Salad ComfyUI API：`1.19.2`
- 權重Revision：`feef60b0aaf63a4773ace96636ebbcf43b881312`
- 圖像模型：`flux3-image-klein-bf16.safetensors`，BF16
- 圖像文字編碼器：`qwen3vl_4b_bf16.safetensors`，BF16
- 官方提示詞擴寫器：`qwen3.5_9b_flux3_prompt_upsampler_w4a8.safetensors`
- VAE：`flux2-vae.safetensors`
- 總下載量：27,033,425,992 bytes，約25.18 GiB

每個權重的固定大小與SHA256都在`model-lock.json`。容器先下載、續傳並完成大小及SHA256校驗，全部通過後才會啟動API。

官方Hugging Face Repository是gated，啟動前必須先接受FLUX.3 Klein授權，並用Salad環境變數`HF_TOKEN`提供只讀Token。Token不應寫進映像、Git或日誌。

## 畫質與資源取捨

- 真正出圖的DiT模型與Qwen3-VL圖像文字編碼器都是BF16，沒有把生成路徑換成INT8／FP8／NVFP4。
- 提示詞擴寫器是獨立的輔助LLM，採官方W4A8版本，降低32GB VRAM與64GB主機記憶體同時載入兩套大型模型時的OOM風險。
- 採樣固定16 steps、CFG 1、Euler、Simple。
- 正式尺寸沿用直圖832×1088、橫圖1088×832。
- 官方Prompt Upsampler固定開啟；系統提示詞保存在`prompt-upsampler-system.txt`。
- 暖機工作流走完整模型鏈，但只跑4 steps；正式工作流仍是16 steps。

## 建置與部署順序

1. 將本資料夾放到新的GitHub Repository根目錄。
2. GitHub Actions建置並推送：
   `ghcr.io/<GitHub帳號>/salad-flux3-klein-bf16:comfy0.42.1-flux3-klein-distilled-bf16-r1`
3. 將GHCR Package設為Public。
4. 在Hugging Face接受模型授權並建立只讀Token。
5. Token只保存於本機記憶根目錄`huggingAPIKEY.txt`，由控制腳本在建立Salad Container Group時傳入`HF_TOKEN`；該檔案已被記憶根目錄的`.gitignore`忽略。
6. 使用獨立Container Group，不覆蓋Qwen測試群組。

## Salad預定配置

- RTX 5090 32GB
- High Priority
- 4 vCPU
- 64GB系統記憶體
- 100GB暫存磁碟
- 1 Replica
- AMD64
- Autostart關閉

任何建立、啟動、停止、重啟、映像更新或副本變更，都必須在當次操作前告知使用者並得到明確確認。批次測試預設只做dry-run；實際出圖另需`--execute --user-confirmed`。

## 官方依據

- 模型與授權：<https://huggingface.co/black-forest-labs/flux-3-image-klein>
- ComfyUI版權重：<https://huggingface.co/black-forest-labs/flux-3-image-klein-comfy>
- ComfyUI教學：<https://docs.comfy.org/tutorials/flux/flux-3-klein>
- 官方工作流模板：<https://github.com/Comfy-Org/workflow_templates/blob/main/templates/image_flux3_klein_distilled_t2i.json>
