# 💤 LazyVim Configuration

Personal Neovim configuration based on [LazyVim](https://github.com/LazyVim/LazyVim).

## セットアップ手順

### 必要な環境
- Neovim 0.8以上
- Git
- Node.js（一部プラグインで必要）
- ripgrep（検索機能用）

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

### 主な設定内容

- **プラグイン管理**: Lazy.nvim
- **LSP設定**: 各種言語サーバーの設定
- **キーマップ**: カスタムキーバインド
- **テーマ**: LazyVimデフォルトテーマ

### カスタマイズ

個人的な設定は `lua/config/` 以下のファイルで管理：
- `options.lua`: Neovimの基本設定
- `keymaps.lua`: キーマップ設定
- `autocmds.lua`: 自動コマンド設定

追加プラグインは `lua/plugins/` 以下に配置。

### 参考リンク

- [LazyVim Documentation](https://lazyvim.github.io/)
- [LazyVim GitHub](https://github.com/LazyVim/LazyVim)
