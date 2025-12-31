#!/usr/bin/env bash
set -euo pipefail

size="320x480"
auto_orient=1
portrait_size="320x480"
landscape_size="480x320"
supported_sizes=("$portrait_size" "$landscape_size")
size_explicit=0
fit="contain"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
input_dir="$script_dir/input"
out_dir="$script_dir/output"
optimize=1
strip=1
recursive=0
dry_run=0
pingpong=1
colors=128
dither="FloydSteinberg"
use_gifsicle=1
format="gif"
webp_quality=80
webp_method=6
webp_lossless=0
install_deps=1

usage() {
  cat <<'USAGE'
Usage: tools/prepare_gifs.sh [options] [gif|dir]...

Resize and optimize animated GIFs for PiFrame.

Options:
  --size WxH         Force a supported size (disables auto orientation)
  --portrait         Force 320x480 (disables auto orientation)
  --landscape        Force 480x320 (disables auto orientation)
  --auto             Auto-detect orientation per file (default)
  --fit MODE         contain|cover|stretch (default: contain)
  --out DIR          Output directory (default: ./tools/output)
  --recursive        Process .gif files in subdirectories
  --format TYPE      gif|webp (default: gif)
  --webp-quality N   WebP quality 0-100 (default: 80)
  --webp-method N    WebP method 0-6 (default: 6)
  --webp-lossless    Use lossless WebP
  --colors N         Reduce to N colors (default: 128, 0 disables)
  --no-dither        Disable dithering
  --no-optimize      Skip GIF layer optimization
  --no-strip         Keep metadata
  --no-pingpong      Disable ping-pong (reverse) playback
  --no-gifsicle      Disable extra gifsicle optimization (if installed)
  --no-install       Do not attempt to install missing dependencies
  --dry-run          Print commands without running them
  -h, --help         Show this help

Defaults:
  - If no inputs are provided, reads from ./tools/input
  - Writes to ./tools/output unless --out is provided

Examples:
  tools/prepare_gifs.sh --portrait --out img/sync gifs/*.gif
  tools/prepare_gifs.sh --landscape --fit cover ~/Downloads/gifs
  tools/prepare_gifs.sh --auto --out img/sync ~/Downloads/gifs
  tools/prepare_gifs.sh
USAGE
}

inputs=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --size)
      size="${2:-}"
      auto_orient=0
      size_explicit=1
      shift 2
      ;;
    --portrait)
      size="$portrait_size"
      auto_orient=0
      shift
      ;;
    --landscape)
      size="$landscape_size"
      auto_orient=0
      shift
      ;;
    --auto)
      auto_orient=1
      shift
      ;;
    --fit)
      fit="${2:-}"
      shift 2
      ;;
    --out|--output)
      out_dir="${2:-}"
      shift 2
      ;;
    --recursive)
      recursive=1
      shift
      ;;
    --format)
      format="${2:-}"
      shift 2
      ;;
    --webp-quality)
      webp_quality="${2:-}"
      shift 2
      ;;
    --webp-method)
      webp_method="${2:-}"
      shift 2
      ;;
    --webp-lossless)
      webp_lossless=1
      shift
      ;;
    --colors)
      colors="${2:-}"
      shift 2
      ;;
    --no-dither)
      dither="None"
      shift
      ;;
    --no-optimize)
      optimize=0
      shift
      ;;
    --no-strip)
      strip=0
      shift
      ;;
    --no-pingpong)
      pingpong=0
      shift
      ;;
    --no-gifsicle)
      use_gifsicle=0
      shift
      ;;
    --no-install)
      install_deps=0
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      inputs+=("$1")
      shift
      ;;
  esac
done

if [[ ${#inputs[@]} -eq 0 ]]; then
  if [[ -d "$input_dir" ]]; then
    inputs=("$input_dir")
  else
    echo "No inputs provided and default input directory not found: $input_dir" >&2
    usage >&2
    exit 1
  fi
fi

if [[ ! "$size" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "Invalid size: $size (expected WxH)" >&2
  exit 1
fi

case "$format" in
  gif|webp)
    ;;
  *)
    echo "Invalid format: $format (use gif|webp)" >&2
    exit 1
    ;;
esac

if [[ ! "$colors" =~ ^[0-9]+$ ]]; then
  echo "Invalid colors value: $colors (expected integer)" >&2
  exit 1
fi
if (( colors > 256 )); then
  echo "Invalid colors value: $colors (max 256)" >&2
  exit 1
fi

if [[ ! "$webp_quality" =~ ^[0-9]+$ ]] || (( webp_quality < 0 || webp_quality > 100 )); then
  echo "Invalid WebP quality: $webp_quality (expected 0-100)" >&2
  exit 1
fi
if [[ ! "$webp_method" =~ ^[0-9]+$ ]] || (( webp_method < 0 || webp_method > 6 )); then
  echo "Invalid WebP method: $webp_method (expected 0-6)" >&2
  exit 1
fi

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_imagemagick() {
  if have_cmd apt-get; then
    sudo apt-get update
    sudo apt-get install -y imagemagick
    return
  fi
  if have_cmd brew; then
    brew install imagemagick
    return
  fi
  if have_cmd dnf; then
    sudo dnf install -y imagemagick
    return
  fi
  if have_cmd yum; then
    sudo yum install -y imagemagick
    return
  fi
  if have_cmd pacman; then
    sudo pacman -S --noconfirm imagemagick
    return
  fi
  if have_cmd port; then
    sudo port install imagemagick
    return
  fi
  return 1
}

ensure_imagemagick() {
  if have_cmd magick || have_cmd convert; then
    return 0
  fi

  if [[ $install_deps -eq 0 ]]; then
    return 1
  fi

  echo "ImageMagick not found. Attempting to install..." >&2
  if install_imagemagick; then
    if have_cmd magick || have_cmd convert; then
      return 0
    fi
  fi
  return 1
}

if [[ $auto_orient -eq 0 || $size_explicit -eq 1 ]]; then
  size_ok=0
  for allowed in "${supported_sizes[@]}"; do
    if [[ "$size" == "$allowed" ]]; then
      size_ok=1
      break
    fi
  done
  if [[ $size_ok -eq 0 ]]; then
    echo "Unsupported size: $size" >&2
    echo "Supported sizes are: ${supported_sizes[*]}" >&2
    exit 1
  fi
fi

case "$fit" in
  contain|cover|stretch)
    ;;
  *)
    echo "Invalid fit: $fit (use contain|cover|stretch)" >&2
    exit 1
    ;;
esac

if ! ensure_imagemagick; then
  echo "ImageMagick not found. Install with: sudo apt install -y imagemagick" >&2
  exit 1
fi

if command -v magick >/dev/null 2>&1; then
  im=(magick)
  identify_mode="magick-identify"
elif command -v identify >/dev/null 2>&1; then
  im=(convert)
  identify_mode="identify"
elif command -v convert >/dev/null 2>&1; then
  im=(convert)
  identify_mode="convert-info"
else
  echo "ImageMagick not found. Install with: sudo apt install -y imagemagick" >&2
  exit 1
fi

if [[ "$format" == "webp" ]]; then
  if ! "${im[@]}" -list format 2>/dev/null | grep -q 'WEBP'; then
    echo "ImageMagick lacks WEBP support. Reinstall ImageMagick with WebP support." >&2
    exit 1
  fi
fi

get_dimensions() {
  local file="$1"
  case "$identify_mode" in
    magick-identify)
      magick identify -format "%w %h" "${file}[0]" 2>/dev/null || true
      ;;
    identify)
      identify -format "%w %h" "${file}[0]" 2>/dev/null || true
      ;;
    convert-info)
      convert "${file}[0]" -format "%w %h" info: 2>/dev/null || true
      ;;
    *)
      ;;
  esac
}

get_frame_count() {
  local file="$1"
  case "$identify_mode" in
    magick-identify)
      magick identify -format "%n\n" "$file" 2>/dev/null | awk 'NR==1{print; exit}'
      ;;
    identify)
      identify -format "%n\n" "$file" 2>/dev/null | awk 'NR==1{print; exit}'
      ;;
    convert-info)
      convert "$file" -format "%n\n" info: 2>/dev/null | awk 'NR==1{print; exit}'
      ;;
    *)
      ;;
  esac
}

mkdir -p "$out_dir"

collect_files=()
for input in "${inputs[@]}"; do
  if [[ -d "$input" ]]; then
    if [[ $recursive -eq 1 ]]; then
      while IFS= read -r -d '' file; do
        collect_files+=("$file")
      done < <(find "$input" -type f -iname '*.gif' -print0)
    else
      while IFS= read -r -d '' file; do
        collect_files+=("$file")
      done < <(find "$input" -maxdepth 1 -type f -iname '*.gif' -print0)
    fi
  else
    collect_files+=("$input")
  fi
done

if [[ ${#collect_files[@]} -eq 0 ]]; then
  echo "No GIF files found in input(s)." >&2
  exit 0
fi

for in_file in "${collect_files[@]}"; do
  if [[ ! -f "$in_file" ]]; then
    echo "Skip non-file: $in_file" >&2
    continue
  fi

  case "${in_file##*.}" in
    gif|GIF|Gif)
      ;;
    *)
      echo "Skip non-gif: $in_file" >&2
      continue
      ;;
  esac

  base="$(basename "$in_file")"
  base_no_ext="${base%.*}"
  if [[ "$format" == "webp" ]]; then
    out_file="$out_dir/$base_no_ext.webp"
  else
    out_file="$out_dir/$base"
  fi

  target_size="$size"
  if [[ $auto_orient -eq 1 ]]; then
    dims="$(get_dimensions "$in_file")"
    if [[ -n "$dims" ]]; then
      read -r width height <<<"$dims"
      if [[ -n "$width" && -n "$height" ]]; then
        if [[ "$width" -ge "$height" ]]; then
          target_size="$landscape_size"
        else
          target_size="$portrait_size"
        fi
      fi
    fi
  fi

  pingpong_args=()
  if [[ $pingpong -eq 1 ]]; then
    frame_count="$(get_frame_count "$in_file")"
    if [[ "$frame_count" =~ ^[0-9]+$ ]]; then
      if (( frame_count >= 3 )); then
        pingpong_args=( "(" -clone "1--2" -reverse ")" )
      elif (( frame_count == 2 )); then
        pingpong_args=( "(" -clone "0" -reverse ")" )
      fi
    fi
  fi

  cmd=( "${im[@]}" "$in_file" -coalesce -filter Lanczos )
  case "$fit" in
    contain)
      cmd+=( -resize "$target_size" -background black -gravity center -extent "$target_size" )
      ;;
    cover)
      cmd+=( -resize "${target_size}^" -background black -gravity center -extent "$target_size" )
      ;;
    stretch)
      cmd+=( -resize "${target_size}!" )
      ;;
  esac

  if [[ "$format" == "gif" ]]; then
    if (( colors > 0 )); then
      cmd+=( -dither "$dither" -colors "$colors" )
    fi
  else
    cmd+=( -define "webp:method=${webp_method}" -quality "$webp_quality" )
    if [[ $webp_lossless -eq 1 ]]; then
      cmd+=( -define webp:lossless=true )
    else
      cmd+=( -define webp:lossless=false )
    fi
    cmd+=( -loop 0 )
  fi

  if [[ ${#pingpong_args[@]} -gt 0 ]]; then
    cmd+=( "${pingpong_args[@]}" )
  fi

  if [[ $strip -eq 1 ]]; then
    cmd+=( -strip )
  fi
  if [[ $optimize -eq 1 && "$format" == "gif" ]]; then
    cmd+=( -layers Optimize )
  fi

  cmd+=( "$out_file" )

  if [[ $dry_run -eq 1 ]]; then
    printf 'Would run: %q ' "${cmd[@]}"
    printf '\n'
  else
    "${cmd[@]}"
    if [[ $use_gifsicle -eq 1 && "$format" == "gif" ]] && command -v gifsicle >/dev/null 2>&1; then
      tmp_file="${out_file}.tmp"
      gifsicle --optimize=3 -o "$tmp_file" "$out_file"
      mv "$tmp_file" "$out_file"
    fi
    echo "Wrote $out_file"
  fi
done
