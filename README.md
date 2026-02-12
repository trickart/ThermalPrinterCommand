# ThermalPrinterCommand

サーマルプリンターコマンドのエンコード・デコードライブラリ

## 要件

- Swift 6.2+
- macOS 10.15+ / iOS 13+

## インストール

`Package.swift` に追加:

```swift
dependencies: [
    .package(url: "https://github.com/trickart/ThermalPrinterCommand.git", from: "0.0.1")
]
```

## ターゲット構成

| ターゲット | 説明 |
|---|---|
| **ThermalPrinterCommand** | ESC/POS コマンドの型定義・エンコード・デコード |
| **ReceiptRenderer** | ESC/POS コマンドを表示するレンダラー |

## 使い方

### コマンドのエンコード

`ESCPOSCommand` を組み立てて `Data` にエンコード:

```swift
import ThermalPrinterCommand

// 個別にエンコード
let data = ESCPOSCommand.initialize.encode()

// 複数コマンドをまとめてエンコード
let commands: [ESCPOSCommand] = [
    .initialize,
    .text("Hello, World!".data(using: .shiftJIS)!),
    .lineFeed,
    .cut(.partial),
]
let bytes = commands.encode()
```

### コマンドのデコード

プリンターから受信した `Data` を `ESCPOSCommand` の配列にデコード:

```swift
let decoder = ESCPOSDecoder()
let commands = decoder.decode(receivedData)

for command in commands {
    switch command {
    case .text(let data):
        print(String(data: data, encoding: .shiftJIS) ?? "")
    case .cut(let mode):
        print("カット: \(mode)")
    default:
        break
    }
}
```

### レンダリング

`TextReceiptRenderer` で ESC/POS コマンド列をターミナルやプレーンテキストとして描画:

```swift
import ReceiptRenderer

var renderer = TextReceiptRenderer()
renderer.render(commands)
```

ターミナル以外（ファイル出力等）で使う場合は ANSI 装飾を無効化:

```swift
var renderer = TextReceiptRenderer(ansiStyleEnabled: false)
```

Sixel 対応ターミナルでバーコード・QRコード・画像をグラフィカルに表示:

```swift
var renderer = TextReceiptRenderer(ansiStyleEnabled: true, sixelEnabled: true)
```

## ライセンス

MIT License
