#!/usr/bin/env bash
# 環境音の録音を、ループ再生しても継ぎ目が分からない音声にする。
#   1. 録音の最初と最後のフェード部分を切り落とす
#   2. 末尾の数秒を先頭に重ねてクロスフェードする（最後まで再生したら、そのまま先頭へつながる）
#   3. どのムードでも同じくらいの音量になるよう -26 LUFS にそろえ、AAC (.m4a) にする
#
#   ./scripts/prepare-sound.sh ~/Downloads/stream.wav river 2 5    # 先頭 2 秒・末尾 5 秒を切って river.m4a に
#   ./scripts/prepare-sound.sh sea.wav sea 0 0 6                     # クロスフェードを 6 秒にする
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <recording> <name> [trim_start=0] [trim_end=0] [crossfade=4]" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
input=$1 name=$2 head=${3:-0} tail=${4:-0} fade=${5:-4}
out="$root/sounds/$name.m4a"
mkdir -p "$root/sounds"

total=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$input")
len=$(echo "$total - $head - $tail" | bc -l)   # 切り落とした後の長さ
mid_end=$(echo "$len - $fade" | bc -l)

# 先頭 fade 秒（フェードイン）と末尾 fade 秒（フェードアウト）を重ね、その後ろに中間部を続ける。
# 雑音のような音は重ねても打ち消し合わないので、音量が下がらない quarter-sine のカーブを使う
ffmpeg -hide_banner -loglevel error -y -i "$input" -filter_complex "
  [0]atrim=start=$head:duration=$len,asetpts=PTS-STARTPTS,asplit=3[a][b][c];
  [a]atrim=0:$fade,asetpts=PTS-STARTPTS,afade=t=in:d=$fade:curve=qsin[head];
  [b]atrim=start=$mid_end,asetpts=PTS-STARTPTS,afade=t=out:d=$fade:curve=qsin[tail];
  [c]atrim=start=$fade:end=$mid_end,asetpts=PTS-STARTPTS[mid];
  [head][tail]amix=inputs=2:normalize=0[joint];
  [joint][mid]concat=n=2:v=0:a=1,loudnorm=I=-26:TP=-3[out]" \
  -map '[out]' -ar 44100 -c:a aac -b:a 128k "$out"
echo "$out"
