#!/usr/bin/env bash
# エディタ(Calc拡張機能)が起動する.bin/calc-lspを，指定したパッケージの実行ファイルに向ける．
set -euo pipefail

package="$1"
cabal build "$package:exe:calc-lsp"
binary="$(cabal list-bin "$package:exe:calc-lsp")"
mkdir -p .bin
ln -sf "$binary" .bin/calc-lsp
echo ".bin/calc-lsp -> $binary"
echo "VS Codeでコマンド「Calc: Restart Server」を実行すると，新しいサーバに切り替わる．"
