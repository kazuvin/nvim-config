#!/usr/bin/env bash
# 環境音を BBC Sound Effects からダウンロードして sounds/ に作る。
# BBC の RemArc Licence は再配布を禁止しているので、sounds/ は git に入れず、
# 新しいマシンではこのスクリプトで作り直す（WAV を 1 つ 65MB ほどダウンロードする）。
#
#   ./scripts/fetch-sounds.sh           # すべて
#   ./scripts/fetch-sounds.sh rain      # 1 つだけ
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 名前: BBC の ID と、録音の両端のフェードを切り落とす秒数（先頭 末尾）
fetch() {
  local name=$1 id=$2 head=$3 tail=$4
  echo "$name ($id)"
  curl -fL --progress-bar -o "$tmp/$id.wav" "https://sound-effects-media.bbcrewind.co.uk/wav/$id.wav"
  "$root/scripts/prepare-sound.sh" "$tmp/$id.wav" "$name" "$head" "$tail"
  rm "$tmp/$id.wav"
}

targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(river mountain rain)
for name in "${targets[@]}"; do
  case $name in
    river) fetch river 07031097 2.5 5 ;;         # Water: Gentle stream flowing
    mountain) fetch mountain 07027032 2 4.5 ;;   # Weather: Wind in trees
    rain) fetch rain 07005210 1 3 ;;             # Heavy rain, on turf and trees
    *) echo "unknown: $name (river / mountain / rain)" >&2; exit 1 ;;
  esac
done
