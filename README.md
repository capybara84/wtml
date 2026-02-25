# wtml

副作用を型システムで追跡する、新しいML系プログラミング言語。

## 特徴

- **ML系関数型言語** — OOPなし、関数型プログラミングに特化
- **正格（先行）評価**
- **型推論** — 型注釈は省略可能
- **副作用追跡** — 関数の矢印型（`->`、`->!`、`->~`）で副作用を型レベルで管理
- **シンプルなモジュール機構** — `module`、`import`、ドットアクセス
- **Lisp VM へコンパイル**

## 副作用型システム

wtml では副作用を関数型の一部として追跡します。関数は接尾辞で分類されます：

| 接尾辞 | 矢印 | 意味 |
|--------|------|------|
| (なし) | `->` | 純粋 — 副作用なし |
| `!` | `->!` | 副作用あり |
| `~` | `->~` | 副作用多相 — 引数に依存 |

```
fn square x = x * x                   # 純粋
fn println! x = ...                    # 副作用あり
fn map~ f~ xs = ...                    # 多相: fに応じて純粋にも副作用ありにもなる
```

サブタイピング規則により安全性を保証します：
- 純粋な関数は副作用ありの場所に渡せる（`->` <: `->!`）
- 純粋・副作用ありの両方を副作用多相に渡せる（`->` <: `->~`、`->!` <: `->~`）
- 副作用ありの関数は純粋な場所には渡せない（コンパイルエラー）

## 構文の概要

```
# 値束縛
let x = 42

# 関数定義
fn add x y = x + y

# 無名関数
let double = fn x -> x * 2

# 型注釈（省略可能）
fn length (xs : 'a list) : int = ...

# ブロック
fn foo x = {
  let y = x + 1
  y * 2
}

# パターンマッチ
fn length = {
  | [] => 0
  | _ :: rest => 1 + length rest
}

# モジュール
module List
fn head = {
  | [] => error "empty list"
  | x :: _ => x
}

module Main
import List
let x = head [1, 2, 3]
```

## コード例

```
module Main

import List

fn square x = x * x

fn sum xs = fold_left (fn a b -> a + b) 0 xs

fn fizzbuzz n = {
  fn go i =
    if i > n then []
    else {
      let s =
        match (i % 3, i % 5) {
          | (0, 0) => "FizzBuzz"
          | (0, _) => "Fizz"
          | (_, 0) => "Buzz"
          | _ => string_of_int i
        }
      s :: go (i + 1)
    }
  go 1
}

fn main! = {
  let nums = [1, 2, 3, 4, 5]
  let squares = map square nums
  let total = sum squares
  println! total
  print_all! (fizzbuzz 15)
}
```

## ビルド

wtml は OCaml で実装されており、Dune ビルドシステムを使用しています。

```sh
dune build    # ビルド
dune test     # テスト実行
dune clean    # ビルド成果物の削除
```

### 必要なもの

- OCaml
- Dune (>= 3.18)
- OPAM

## 状態

設計・ブートストラップの初期段階です。言語仕様は `memo.txt` にあります。

## ライセンス

MIT
