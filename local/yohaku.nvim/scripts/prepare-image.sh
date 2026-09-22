#!/usr/bin/env bash
# 手持ちの写真を、しずかなインターネットの背景と同じように加工する。
# しずかなインターネットは写真そのものには手を加えず、表示するときに次の 2 つだけをかけている:
#   * filter: blur(12px) … 標準偏差 12px のガウスぼかし
#   * opacity: .75       … 下地の #2c2d2d（ダークモードの背景色）の上に 75% の濃さで重ねる
# ここでは同じ処理を画像に焼き込む。ザラつき（ノイズ）・減光・彩度の調整はしない。
#
#   ./scripts/prepare-image.sh ~/Downloads/river.jpg river    # backgrounds/river.jpg を上書き
#   ./scripts/prepare-image.sh photo.jpg sea 12 0.75 2c2d2d    # ぼかし・濃さ・下地の色を指定
#
# 画像は幅 2560px で書き出す。幅 2560pt の画面で書く用ウィンドウを全画面にすると、画像の
# 1px が画面の 1pt になるので、blur=12 でしずかなインターネットと同じぼけ方になる
# （ウィンドウが小さいと、そのぶん画像が縮んでぼけも弱く見える）。
# 暗さは加工ではなく写真選びで決まる（しずかなインターネットも夕暮れや夜の写真を使っている）。
# 明るい写真だと白い文字が読みにくくなるので、暗めの写真を選ぶ。
# 最後に、ムードの `bg` に使える色（加工後の画像の平均色）を表示する。
# 新しい名前で作った場合は、lua/plugins/yohaku.lua の moods に追加する。
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <photo> <name> [blur=12] [opacity=0.75] [base=2c2d2d]" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
input=$1 name=$2 blur=${3:-12} opacity=${4:-0.75} base=${5:-2c2d2d}
base=${base#\#}
out="$root/backgrounds/$name.jpg"
mkdir -p "$root/backgrounds"

# 下地の色と混ぜる: 画素 × opacity + 下地 × (1 - opacity)（ブラウザと同じく sRGB の値のまま混ぜる）
mix() {
  echo "val*$opacity+$((16#$1))*(1-$opacity)"
}
ffmpeg -hide_banner -loglevel error -y -i "$input" \
  -vf "scale=2560:-2:flags=lanczos,gblur=sigma=$blur:steps=3,lutrgb=r='$(mix "${base:0:2}")':g='$(mix "${base:2:2}")':b='$(mix "${base:4:2}")',format=yuvj444p" \
  -frames:v 1 -q:v 2 "$out"
echo "$out"

avg=$(ffmpeg -hide_banner -loglevel error -i "$out" -vf "scale=1:1:flags=area,format=rgb24" -f rawvideo - | od -An -tu1)
read -r r g b <<<"$avg"
printf 'bg = "#%02x%02x%02x"\n' "$r" "$g" "$b"
