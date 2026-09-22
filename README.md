# 💤 LazyVim Configuration

Personal Neovim configuration based on [LazyVim](https://github.com/LazyVim/LazyVim).

## セットアップ手順

### 必要な環境

- Neovim 0.11 以上（動作確認は 0.11.4）
- Git
- Node.js（一部プラグインで必要）
- ripgrep（検索機能用）
- ライティングモード（後述）を使う場合
  - macOS と [Ghostty](https://ghostty.org/)
  - Hack Nerd Font（`Hack Nerd Font Mono`）
  - ffmpeg（環境音・背景画像の用意に使う）

### インストール方法

1. 既存のNeovim設定をバックアップ（必要に応じて）
   ```bash
   mv ~/.config/nvim ~/.config/nvim.bak
   mv ~/.local/share/nvim ~/.local/share/nvim.bak
   ```

2. このリポジトリをクローン
   ```bash
   git clone https://github.com/kazuvin/nvim-config.git ~/.config/nvim
   ```

3. Neovimを起動してプラグインの自動インストールを実行
   ```bash
   nvim
   ```

4. ライティングモードの環境音を用意（再配布できない素材のため、リポジトリには含めていない）
   ```bash
   ~/.config/nvim/local/yohaku.nvim/scripts/fetch-sounds.sh
   ```

### 主な設定内容

- **プラグイン管理**: Lazy.nvim
- **LSP設定**: 各種言語サーバーの設定（TypeScript・Rust・Tailwind など LazyVim の extras）
- **キーマップ**: カスタムキーバインド
- **テーマ**: catppuccin（mocha・背景透過）
- **ファイラー**: snacks.nvim の explorer（右側に表示）
- **AI 補完**: Copilot
- **ライティングモード**: 日記・エッセイ用の自作プラグイン（後述）

### ディレクトリ構成

```
init.lua
lua/config/          基本設定（options / keymaps / autocmds / lazy）
lua/plugins/         追加・上書きするプラグイン
local/yohaku.nvim/   自作のライティングモード（lua/plugins/yohaku.lua で読み込む）
```

### ライティングモード（yohaku.nvim）

[しずかなインターネット](https://sizu.me/) のように、書くことが楽しくなる画面で日記やエッセイを書くためのモード。
ぼかした風景写真を背景に、ゆったりした行間で本文を中央に置き、環境音を流す。

- `:Writing`（`<leader>uW`）: 今のファイルを、書く用の Ghostty ウィンドウで開く。中で実行すると閉じる
- `:Mood [river|mountain|rain]`: ムード（背景と環境音）を切り替える
- `:WritingSound [on|off]`: 環境音の切り替え

背景・フォント・行間は書く用ウィンドウの Ghostty にだけ効き、ふだんの Ghostty には影響しない。
素材の出典は [`local/yohaku.nvim/CREDITS.md`](local/yohaku.nvim/CREDITS.md) を参照。

### カスタマイズ

個人的な設定は `lua/config/` 以下のファイルで管理：
- `options.lua`: Neovimの基本設定
- `keymaps.lua`: キーマップ設定
- `autocmds.lua`: 自動コマンド設定

追加プラグインは `lua/plugins/` 以下に配置。

### 参考リンク

- [LazyVim Documentation](https://lazyvim.github.io/)
- [LazyVim GitHub](https://github.com/LazyVim/LazyVim)
