"""Generate a reproducible local ACE-Step soundtrack audition for Shit-Tacular."""

import argparse
import json
import os
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
ACE_ROOT = ROOT / "ACE-Step-1.5"
sys.path.insert(0, str(ACE_ROOT))
os.environ.setdefault("HF_HOME", str(ACE_ROOT / ".cache" / "huggingface"))
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")


def main():
    """Load the Turbo model with CPU offload and render a WAV audition."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=112905)
    args = parser.parse_args()

    from acestep.handler import AceStepHandler
    from acestep.inference import GenerationConfig, GenerationParams, generate_music
    from acestep.llm_inference import LLMHandler

    output = ROOT / "artifacts" / "music" / "flush-funk"
    output.mkdir(parents=True, exist_ok=True)
    handler = AceStepHandler()
    status, ready = handler.initialize_service(
        project_root=str(ACE_ROOT),
        config_path="acestep-v15-turbo",
        device="cuda",
        use_flash_attention=False,
        compile_model=False,
        offload_to_cpu=True,
        offload_dit_to_cpu=False,
    )
    print(status, flush=True)
    if not ready:
        raise RuntimeError("ACE-Step initialization failed; see status above.")

    params = GenerationParams(
        caption=(
            "Instrumental playful arcade combat funk. A tight syncopated electric bass "
            "riff, punchy breakbeat drums, bright porcelain-tap percussion, pitched "
            "water droplets, bubbling synth accents and swirling watery whoosh fills. "
            "Catchy mischievous retro-game synth melody, energetic apartment mayhem. "
            "Steady danceable groove, clean spacious mix, quirky and musical. "
            "Repeated four-bar motif with subtle variations, immediate groove, "
            "consistent energy throughout, no fade out, no vocals or speech."
        ),
        lyrics="[Instrumental]",
        instrumental=True,
        bpm=112,
        duration=240 / 112 * 16,
        keyscale="D minor",
        timesignature="4",
        inference_steps=8,
        seed=args.seed,
        thinking=False,
        use_cot_metas=False,
        use_cot_caption=False,
        use_cot_language=False,
    )
    config = GenerationConfig(
        batch_size=1, use_random_seed=False, seeds=[args.seed], audio_format="wav"
    )
    result = generate_music(handler, LLMHandler(), params, config, save_dir=str(output))
    if not result.success:
        raise RuntimeError(result.error)
    metadata = {"parameters": params.to_dict(), "config": config.to_dict(),
                "audios": result.audios}
    (output / f"generation-{args.seed}.json").write_text(
        json.dumps(metadata, indent=2, default=str), encoding="utf-8"
    )
    for audio in result.audios:
        print(f"GENERATED_AUDIO={audio['path']}", flush=True)


if __name__ == "__main__":
    main()
