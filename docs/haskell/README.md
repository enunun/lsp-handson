# 文法と概念のノート

各Iterationで初めて使う文法，概念，道具を説明する．

| Iteration | ノート | 主な内容 |
| --- | --- | --- |
| 0 | [iteration-0.md](iteration-0.md) | LSPの仕組み，`lsp`ライブラリの骨組み，`Text`と`OverloadedStrings`，lens，cabal，hspec，lsp-test |
| 1 | [iteration-1.md](iteration-1.md) | 診断(`publishDiagnostics`)と位置，レコード，`Maybe`と`Either`の組み合わせ，`Data.Text`による行の検査 |
| 2 | [iteration-2.md](iteration-2.md) | megaparsec，再帰的なデータ型と再帰関数，演算子の優先順位，`mapAccumL`と`Data.Set` |
| 3 | [iteration-3.md](iteration-3.md) | リクエストとレスポンス，`requestHandler`と`\|?`型，`Data.Map`，`Either`と`Maybe`の`do`，`--match` |
| 4 | [iteration-4.md](iteration-4.md) | `Location`，定義と参照のリクエスト，名前解決の表，テストを安全網にしたリファクタリング，名前の衝突 |
| 5 | [iteration-5.md](iteration-5.md) | 補完と`CompletionItem`，書きかけの入力の扱い，lensの`&`と`?~`，`nub`と内包表記のパターン |
| 6 | [iteration-6.md](iteration-6.md) | リネームの2つのリクエスト，`WorkspaceEdit`，エラーレスポンス，QuickCheckによる性質のテスト |
| 7 | [iteration-7.md](iteration-7.md) | `DocumentSymbol`，全文と差分の同期とVFS，STMと`TVar`による共有状態，`liftIO` |
