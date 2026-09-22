# 素材の出典

画像は `scripts/prepare-image.sh`、音声は `scripts/prepare-sound.sh` で加工したもの
（画像はしずかなインターネットと同じく 12px ぼかして下地の #2c2d2d に 75% の濃さで重ね、
音声は両端を切ってループ用にクロスフェードし、音量をそろえた）。

## 背景画像

| ファイル | 写真 | 撮影者 | ライセンス |
|---|---|---|---|
| `backgrounds/river.jpg` | [A stream running through a lush green forest](https://unsplash.com/photos/a-stream-running-through-a-lush-green-forest-nM7KMy14kcY) | Daniel Alexandre Páscoa | [Unsplash License](https://unsplash.com/license) |
| `backgrounds/mountain.jpg` | [The silhouette of a mountain against a dark blue sky](https://unsplash.com/photos/the-silhouette-of-a-mountain-against-a-dark-blue-sky-G7sDNMQn_GA) | Martin Adams | [Unsplash License](https://unsplash.com/license) |
| `backgrounds/rain.jpg` | [Rain drops on a window with a dark sky in the background](https://unsplash.com/photos/rain-drops-on-a-window-with-a-dark-sky-in-the-background-8Poc0TjWOgA) | Bernd Dittrich | [Unsplash License](https://unsplash.com/license) |

## 環境音

すべて [BBC Sound Effects](https://sound-effects.bbcrewind.co.uk/) の録音で、
[RemArc Licence](https://sound-effects.bbcrewind.co.uk/licensing)（個人・教育・研究目的のみ）で使っている。

- **再配布は禁止**。`sounds/` は `.gitignore` で git から外している（リンクの共有は可）
- 新しいマシンでは `scripts/fetch-sounds.sh` で BBC からダウンロードして作り直す
- 求められているクレジット表記: bbc.co.uk – © copyright 2026 BBC

| ファイル | BBC の ID | 内容 |
|---|---|---|
| `sounds/river.m4a` | 07031097 | Water: Gentle stream flowing（穏やかな小川。鳥の声なし） |
| `sounds/mountain.m4a` | 07027032 | Weather: Wind in trees（木々を渡る一定の風） |
| `sounds/rain.m4a` | 07005210 | Heavy rain, on turf and trees（芝や木々に降る、むらのない雨） |

ID で [検索](https://sound-effects.bbcrewind.co.uk/search) すると元の録音を聴ける。
