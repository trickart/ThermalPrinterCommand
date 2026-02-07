# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

サーマルプリンター（ESC/POS）コマンドのエンコード・デコードライブラリ。Swift Package Manager、Swift 6.2ツールチェーン使用。外部依存なし。対応プラットフォーム: macOS 10.15+, iOS 13+。

## Build Commands

```bash
swift build                        # ビルド
swift build -c release             # リリースビルド
swift test                         # 全テスト実行
swift test --filter <test_name>    # 特定テスト実行
```

## Architecture

2ターゲット構成（外部依存なし）:

- **ThermalPrinterCommand** (Library): ESC/POSコマンドのエンコード・デコード
- **ReceiptRenderer** (Library, depends: ThermalPrinterCommand): ESC/POSコマンドのテキスト表示

## Tests

Swift Testing フレームワーク（`@Suite`, `@Test`）使用:

- **ThermalPrinterCommandTests**: ESCPOSEncoder/Decoderのエンコード・デコード検証
- **ReceiptRendererTests**: TextReceiptRenderer, SixelEncoder, QRCodeRasterizerのテスト
