#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


PLACEHOLDER = "__FLUX3_PUP_SYSTEM_PROMPT__"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", required=True)
    parser.add_argument("--system-prompt", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--warmup", action="store_true")
    args = parser.parse_args()

    template_path = Path(args.template)
    system_prompt_path = Path(args.system_prompt)
    output_path = Path(args.output)

    workflow = json.loads(template_path.read_text(encoding="utf-8"))
    system_prompt = system_prompt_path.read_text(encoding="utf-8").strip()
    if workflow["12"]["inputs"].get("value") != PLACEHOLDER:
        raise SystemExit("workflow template system-prompt placeholder is missing")
    if not system_prompt:
        raise SystemExit("prompt-upsampler system prompt is empty")

    workflow["12"]["inputs"]["value"] = system_prompt
    if args.warmup:
        workflow["5"]["inputs"]["prompt"] = (
            "A full-color outdoor portrait photograph of an adult person in soft morning light."
        )
        workflow["8"]["inputs"].update({"width": 832, "height": 1088, "batch_size": 1})
        workflow["9"]["inputs"].update({"seed": 2026102600, "steps": 4})
        workflow["11"]["inputs"]["filename_prefix"] = "flux3-klein-warmup"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(workflow, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
