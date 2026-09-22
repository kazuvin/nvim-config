#!/usr/bin/env bash
# 手持ちの写真を、しずかなインターネットの背景のように加工する
# （強くぼかし、全体を少し暗くして、下に行くほどさらに暗くする）。
#
#   ./scripts/prepare-image.sh ~/Downloads/river.jpg river          # backgrounds/river.jpg を上書き
#   ./scripts/prepare-image.sh photo.jpg sea 30 -0.3 0.3 0.6        # ぼかし・明るさ・下側の暗さ・彩度を指定
#
# 白い文字が読めるよう、本文が載る中央部分の明るいところでもコントラスト比 5 以上を目安に暗くする。
# 最後に、ムードの `bg` に使える色（画像の平均色を暗くしたもの）を表示する。
# 新しい名前で作った場合は、lua/plugins/yohaku.lua の moods に追加する。
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <photo> <name> [blur=30] [brightness=-0.25] [shade=0.3] [saturation=0.65]" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
input=$1 name=$2 blur=${3:-30} brightness=${4:--0.25} shade=${5:-0.3} saturation=${6:-0.65}
out="$root/backgrounds/$name.jpg"
mkdir -p "$root/backgrounds"

# 縮小してからぼかすと速い。彩度を落として落ち着いた色にし、shade の分だけ上端から下端へ徐々に暗くする
dark="(1-$shade*Y/H)"
ffmpeg -hide_banner -loglevel error -y -i "$input" \
  -vf "scale=1280:-2,gblur=sigma=$blur,eq=brightness=$brightness:saturation=$saturation,format=gbrp,geq=r='r(X,Y)*$dark':g='g(X,Y)*$dark':b='b(X,Y)*$dark',scale=2560:-2:flags=bicubic,noise=alls=3:allf=u,format=yuvj444p" \
  -frames:v 1 -q:v 2 "$out"
echo "$out"

# 平均色を 6 割の明るさにしたものを、ムードの bg の候補として出す
avg=$(ffmpeg -hide_banner -loglevel error -i "$out" -vf "scale=1:1,format=rgb24" -f rawvideo - | od -An -tu1)
read -r r g b <<<"$avg"
printf 'bg = "#%02x%02x%02x"\n' $((r * 6 / 10)) $((g * 6 / 10)) $((b * 6 / 10))
