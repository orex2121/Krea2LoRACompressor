"""Batch strip DIT/UNET layers from Krea2 LoRAs with strategic block removal.

Supports percentage-based stripping starting from edge blocks (0-5, N-5...N).

Usage:
  python batch_strip_krea2.py --file model.safetensors --percentage 50
  python batch_strip_krea2.py --folder ./models/ --percentage 25
"""

import sys
from safetensors import safe_open
from safetensors.torch import save_file
from pathlib import Path
import os
import argparse
import re

OUTPUT_SUFFIX = "_stripped"
RISK_THRESHOLD_PCT = 10.0
LEVEL_LABELS = {
    5: "near_original",
    25: "high_quality",
    50: "balanced",
    75: "compact",
    95: "maximum_compression",
}
STRIP_PREFIXES_RAW = ['blocks', 'first', 'last_linear', 'last.linear', 'tmlp_', 'tproj_1']
PREFIX = 'diffusion_model.'
STRIP_PREFIXES = [PREFIX + x for x in STRIP_PREFIXES_RAW]
KREA2_SIGNATURE = 'diffusion_model.txtfusion.'


def build_output_path(input_file, percentage, output_name=None):
    """Build a non-destructive, level-specific output path."""
    input_path = Path(input_file)
    if output_name:
        output_path = Path(str(output_name).strip('"'))
        if not output_path.is_absolute():
            output_path = input_path.parent / output_path
        if output_path.suffix.lower() != ".safetensors":
            output_path = Path(f"{output_path}.safetensors")
        return output_path

    label = LEVEL_LABELS.get(percentage, f"custom_{percentage}pct")
    return input_path.parent / (
        f"{input_path.stem}{OUTPUT_SUFFIX}_{percentage}pct_{label}.safetensors"
    )


def is_generated_output(path):
    stem = Path(path).stem.lower()
    return stem.endswith(OUTPUT_SUFFIX) or f"{OUTPUT_SUFFIX}_" in stem


def is_krea2_lora(filepath):
    try:
        with safe_open(filepath, framework="pt", device="cpu") as f:
            return any(k.startswith(KREA2_SIGNATURE) for k in f.keys())
    except Exception as e:
        print(f"  [ERROR] Could not read {filepath.name}: {e}")
        return False


def select_blocks_for_removal(all_keys, total_block_tensors, percentage_to_remove):
    """Return every tensor key from the selected complete transformer blocks.

    The percentage applies to the number of transformer blocks, never to
    individual tensors. Blocks are selected from the outer edges inward. For
    the 28-block Krea2 layout the preferred edge set is 0-5 and 23-27.
    ``total_block_tensors`` is retained for API compatibility.
    """
    del total_block_tensors

    blocks = {}
    for key in all_keys:
        match = re.match(r"diffusion_model\.blocks\.(\d+)\.", key)
        if match:
            blocks.setdefault(int(match.group(1)), []).append(key)

    block_nums = sorted(blocks)
    if not block_nums or percentage_to_remove <= 0:
        return set()
    if percentage_to_remove >= 100:
        return {key for keys in blocks.values() for key in keys}

    import math

    target_blocks = min(
        len(block_nums),
        max(1, math.ceil(len(block_nums) * percentage_to_remove / 100.0)),
    )

    # Krea2 priority: left blocks 0-5 and right blocks 23-27 first. The
    # equivalent edge widths are used for non-standard block counts.
    left_edge = block_nums[: min(6, len(block_nums))]
    left_set = set(left_edge)
    right_candidates = [bn for bn in block_nums if bn not in left_set]
    right_edge = right_candidates[-min(5, len(right_candidates)) :]

    priority = []
    for index in range(max(len(left_edge), len(right_edge))):
        if index < len(left_edge):
            priority.append(left_edge[index])
        if index < len(right_edge):
            priority.append(right_edge[-1 - index])

    selected = set(priority)
    remaining = [bn for bn in block_nums if bn not in selected]
    while remaining:
        priority.append(remaining.pop())
        if remaining:
            priority.append(remaining.pop(0))

    chosen_blocks = priority[:target_blocks]
    return {key for block in chosen_blocks for key in blocks[block]}


def strip_layers(input_file, output_file, percentage=0):
    """Strip tensors based on block selection logic."""

    all_keys = []
    blocks_stats = {}
    total_block_tensors = 0

    with safe_open(input_file, framework="pt", device="cpu") as f:
        metadata = f.metadata()

        for key in f.keys():
            if 'diffusion_model.blocks.' in key:
                all_keys.append(key)
                total_block_tensors += 1

                match = re.match(r'diffusion_model\.blocks\.(\d+)\.', key)
                if match:
                    bn = int(match.group(1))
                    if bn not in blocks_stats:
                        blocks_stats[bn] = []
                    blocks_stats[bn].append(key)

    keys_to_strip = set()
    
    # When using percentage-based block removal, STRIP_PREFIXES should NOT match 'blocks'
    # to avoid double-stripping. Only use legacy prefix stripping for non-block patterns.
    effective_prefixes = [p for p in STRIP_PREFIXES if not p.startswith('diffusion_model.blocks')]

    # Strategic Block Stripping (percentage-based)
    if percentage > 0:
        keys_to_strip = select_blocks_for_removal(
            all_keys, total_block_tensors, percentage
        )

    tensors = {}
    removed_count, kept_count = 0, 0
    removed_bytes, kept_bytes = 0, 0

    with safe_open(input_file, framework="pt", device="cpu") as f:
        for key in f.keys():
            tensor = f.get_tensor(key)
            tensor_bytes = tensor.element_size() * tensor.nelement()

            # Legacy prefix stripping (non-block patterns like 'first', 'tmlp_', etc.)
            if any(key.startswith(p) for p in effective_prefixes):
                removed_count += 1
                removed_bytes += tensor_bytes
                continue

            # Percentage-based block removal
            if percentage > 0 and key in keys_to_strip:
                removed_count += 1
                removed_bytes += tensor_bytes
                continue

            tensors[key] = tensor
            kept_count += 1
            kept_bytes += tensor_bytes

    save_file(tensors, output_file, metadata=metadata)

    return {
        "removed_count": removed_count,
        "kept_count": kept_count,
        "removed_bytes": removed_bytes,
        "kept_bytes": kept_bytes,
        "total_blocks": len(blocks_stats),
        "blocks_removed": len({re.match(r'diffusion_model\.blocks\.(\d+)\.', k).group(1)
                               for k in keys_to_strip if re.match(r'diffusion_model\.blocks\.\d+\.', k)})
    }


def main():
    parser = argparse.ArgumentParser(description="Krea2 LoRA Stripper")
    source_group = parser.add_mutually_exclusive_group(required=True)
    source_group.add_argument("--file", type=str, help="Path to a single .safetensors file")
    source_group.add_argument("--folder", type=str, help="Path to folder containing .safetensors files")
    parser.add_argument(
        "--percentage",
        type=int,
        choices=sorted(LEVEL_LABELS),
        default=50,
        help="Complete transformer blocks to remove: 5, 25, 50, 75, or 95 percent",
    )
    parser.add_argument("--output-name", type=str,
                        help="Output path for single-file mode (default: level-specific name)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would happen without creating output files")

    args = parser.parse_args()

    if args.folder and args.output_name:
        parser.error("--output-name can only be used together with --file")

    results = []

    # Determine files to process
    if args.file:
        f = Path(args.file.strip('"'))
        if not f.exists():
            print(f"ERROR: File not found: {f}")
            sys.exit(1)
        files = [f]
    else:
        lora_dir = Path(args.folder.strip('"'))
        if not lora_dir.exists() or not lora_dir.is_dir():
            print(f"ERROR: Folder not found: {lora_dir}")
            sys.exit(1)
        files = sorted(lora_dir.glob("*.safetensors"))

    if not files:
        print("No .safetensors files found")
        return

    # Build non-destructive output paths. Each level gets a distinct name.
    out_names = []
    for f in files:
        if is_generated_output(f):
            out_names.append(None)
        else:
            out_names.append(build_output_path(f, args.percentage, args.output_name))

    print(f"Found {len(files)} .safetensors files\n")

    for idx, f in enumerate(files):
        if is_generated_output(f):
            print(f"Checking: {f.name}")
            print("  -> SKIP (already stripped)\n")
            results.append({"name": f.name, "status": "skipped"})
            continue

        out_path = Path(out_names[idx]) if idx < len(out_names) else None
        if not args.dry_run and out_path and out_path.exists():
            print(f"Checking: {f.name}")
            print(f"  -> SKIP (output already exists)\n")
            results.append({"name": f.name, "status": "already_done"})
            continue

        print(f"Checking: {f.name}")
        if not is_krea2_lora(f):
            print("  -> SKIP (not Krea2 architecture)\n")
            results.append({"name": f.name, "status": "skipped"})
            continue

        before_mb = os.path.getsize(f) / (1024 * 1024)

        # Show block structure info first
        with safe_open(f, framework="pt", device="cpu") as sf:
            keys = list(sf.keys())
            total_tensors = len(keys)
            txt_keys = [k for k in keys if k.startswith(KREA2_SIGNATURE)]
            block_keys = [
                k for k in keys
                if re.match(r"diffusion_model\.blocks\.\d+\.", k)
            ]
            n_blocks = len({
                int(re.match(r"diffusion_model\.blocks\.(\d+)\.", k).group(1))
                for k in block_keys
            })

        print(f"  Structure: {total_tensors} tensors, {n_blocks} blocks")
        print(f"  txtfusion layers: {len(txt_keys)} (will be preserved)")

        if args.dry_run:
            selected_keys = select_blocks_for_removal(
                block_keys, len(block_keys), args.percentage
            )
            selected_blocks = sorted({
                int(re.match(r"diffusion_model\.blocks\.(\d+)\.", key).group(1))
                for key in selected_keys
            })

            print(f"\n  [DRY RUN] Percentage: {args.percentage}%")
            print(f"  Blocks selected: {len(selected_blocks)}/{n_blocks}")
            print(f"  Selected block indices: {selected_blocks}")
            print(f"  Transformer tensors selected: {len(selected_keys)}/{len(block_keys)}")

            if args.output_name or out_path:
                target_file = str(out_path) if out_path else args.output_name
                print(f"\n  Would save to: {target_file}")

            print()
            results.append({"name": f.name, "status": "dry_run"})
        else:
            stats = strip_layers(f, out_path, percentage=args.percentage)

            after_mb = os.path.getsize(out_path) / (1024 * 1024) if out_path and out_path.exists() else 0
            reduction = 100 * (1 - after_mb / before_mb) if before_mb > 0 else 0

            total_tensor_bytes = stats["kept_bytes"] + stats["removed_bytes"]
            kept_byte_pct = (100 * stats["kept_bytes"] / total_tensor_bytes
                           if total_tensor_bytes > 0 else 0)
            is_risky = kept_byte_pct < RISK_THRESHOLD_PCT

            print(f"\n  Stripped: removed {stats['removed_count']} tensors, "
                  f"kept {stats['kept_count']}")
            print(f"  Blocks processed: {stats['total_blocks']}, "
                  f"blocks stripped: {stats['blocks_removed']}")
            print(f"  Size: {before_mb:.2f} MB -> {after_mb:.2f} MB ({reduction:.1f}% reduction)")

            risk_msg = ""
            if is_risky:
                risk_msg = " [!] LOW -- higher risk of fidelity loss"
            else:
                risk_msg = " [OK]"
            print(f"  Kept-byte ratio: {kept_byte_pct:.2f}%{risk_msg}")

            print()
            results.append({
                "name": f.name,
                "status": "stripped",
                "before_mb": before_mb,
                "after_mb": after_mb,
                "kept_byte_pct": kept_byte_pct,
                "risky": is_risky,
                "blocks_removed": stats['blocks_removed'],
                "total_blocks": stats['total_blocks']
            })

    # Print summary
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    for r in results:
        if r["status"] == "stripped":
            flag = "" if not r.get('risky') else " [!] LOW-FIDELITY RISK"
            blocks_info = f", {r['blocks_removed']}/{r['total_blocks']} blocks stripped" \
                         if r.get('blocks_removed', 0) > 0 else ""
            print(f"[OK]      {r['name']}: {r['before_mb']:.1f}MB -> {r['after_mb']:.1f}MB"
                  f"{flag}{blocks_info}")
        elif r["status"] == "already_done":
            print(f"[SKIP]    {r['name']}: output already exists")
        elif r["status"] == "dry_run":
            print(f"[DRY RUN] {r['name']}")
        else:
            print(f"[SKIP]    {r['name']}: not Krea2 architecture")


if __name__ == "__main__":
    main()
