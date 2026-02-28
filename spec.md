# wtml 言語仕様書

バージョン: 0.1（ドラフト）

## 1. 概要

wtml は OCaml で実装される ML 系の関数型プログラミング言語である。以下の特徴を持つ。

- 正格評価（eager evaluation）
- Hindley-Milner ベースの型推論
- シンプルなモジュール機構（OOP なし）
- 副作用の有無を型システムで追跡する仕組み
- コンパイルターゲットは Lisp VM

## 2. 字句構造

### 2.1 コメント

`//` から行末までが行コメントである。`/*` と `*/` で囲まれた範囲はブロックコメントである。ブロックコメントはネストできる。

```
// これはコメント
let x = 1  // 行末コメント

/*
  これは
  ブロックコメント
*/
```

### 2.2 キーワード

以下の識別子は予約語であり、変数名・関数名として使用できない。

```
let  fn  type  match  if  then  else  with  module  import  true  false
```

### 2.3 識別子

通常の識別子はアルファベット小文字またはアンダースコアで始まり、英数字・アンダースコアで構成される。

```
x  foo  my_value  fold_left  string_of_int
```

副作用を表すサフィックスとして `!` および `~` を末尾に付けることができる。`#` はデバッグ式のプレフィックスとして予約されている（2.5 節参照）。

```
println!  map~  printAndReturn!  filter~
```

モジュール名およびデータコンストラクタ名はアルファベット大文字で始まる。

```
List  Main  Some  None  Point
```

型変数はシングルクォートで始まる。

```
'a  'b  'key  'value
```

ユーザー定義の型名は通常の識別子であり、小文字で始まる。

```
option  result  point  person
```

### 2.4 リテラル

| 種類 | 例 |
|---|---|
| 整数 | `0`, `42`, `-1` |
| 浮動小数点数 | `0.0`, `3.14`, `-1.5` |
| 文字 | `'a'`, `'Z'`, `'\n'` |
| 文字列 | `"hello"`, `"FizzBuzz"` |
| ブーリアン | `true`, `false` |
| リスト | `[]`, `[1, 2, 3]`, `["a", "b", "c"]` |
| タプル | `(1, 2)`, `(i % 3, i % 5)` |
| ユニット | `()` |

### 2.5 デバッグ式

`#` はデバッグ式のプレフィックスである。`#` に続く式はデバッグビルド時のみ評価され、リリースビルドではコンパイラによって除去される。

デバッグ式内の副作用は型システムに影響しない。つまり、デバッグ式の中で `!` 関数を呼んでも、囲む関数の副作用型は変化しない。

```
// 単一式
fn square x = {
  # println! x       // デバッグ時のみ出力。square は純粋のまま
  x * x
}

// ブロック（複数式）
fn foo x = {
  # {
    println! x
    println! "done"
  }
  x + 1
}
```

デバッグ式の型は常に `unit` である。デバッグ式の値をプログラムのロジックで使用することはできない。

## 3. 型システム

### 3.1 基本型

| 型 | 説明 |
|---|---|
| `int` | 整数 |
| `float` | 浮動小数点数 |
| `char` | 文字 |
| `string` | 文字列 |
| `bool` | ブーリアン（`true` / `false`） |
| `unit` | ユニット型（値は `()`） |
| `'a` | 型変数（多相型） |

### 3.2 複合型

| 型構文 | 説明 |
|---|---|
| `'a list` | リスト型 |
| `('a, 'b)` | タプル型 |
| `'a -> 'b` | 純粋関数型 |
| `'a ->! 'b` | 副作用あり関数型 |
| `'a ->~ 'b` | 副作用ポリモーフィック関数型 |
| `option 'a` | バリアント型（ユーザー定義） |
| `point` | ユーザー定義レコード型名 |

### 3.3 型注釈

型注釈は `:` を使って記述する。省略した場合は型推論により決定される。

レコード型は `type point = Point { x : float, y : float }` のように定義する。

```
// 式への型注釈
let x : int = 42

// 関数引数への型注釈
fn length (x : 'a list) : int = ...

// 関数の型宣言
fn length : 'a list -> int
```

### 3.4 副作用型システム

wtml の型システムの最大の特徴は、関数の副作用の有無を型レベルで追跡する仕組みである。

#### 3.4.1 関数の矢印型

関数型の矢印には 3 種類ある。

| 矢印 | 意味 | 用途 |
|---|---|---|
| `->` | 純粋（副作用なし） | 参照透過な関数 |
| `->!` | 副作用あり | I/O、状態変更等を行う関数 |
| `->~` | 副作用ポリモーフィック | 引数の関数の副作用に依存する高階関数 |

#### 3.4.2 定義時の記法

関数定義では、関数名の末尾に副作用の種類を示すサフィックスを付ける。

| サフィックス | 意味 | 例 |
|---|---|---|
| なし | 純粋 | `square`, `length`, `sum` |
| `!` | 副作用あり | `println!`, `printAndReturn!`, `main!` |
| `~` | 副作用ポリモーフィック | `map~`, `filter~` |

サフィックスは関数の型と一致しなければならない。

`~` は「常に副作用あり」を意味しない。`~` 付きで定義された関数は、呼び出し時に渡された引数に応じて、純粋にも副作用ありにもなりうる。

#### 3.4.3 サブタイピング規則

副作用型の間には以下のサブタイピング関係がある。

```
->  <:  ->!    純粋関数は副作用ありの場所に渡せる
->  <:  ->~    純粋関数は ~に渡せる（~ が純粋に解決）
->! <:  ->~    副作用ありも ~に渡せる（~ が副作用ありに解決）
->! ≠>  ->     副作用ありは純粋な場所に渡せない（コンパイルエラー）
```

つまり `->~` は `->` と `->!` の上限型であり、`->` は最も制限的な型である。

#### 3.4.4 推論規則

関数の副作用は以下のルールで推論される。

1. 本体で `!` 関数を呼び出している → その関数は `!` でなければならない
2. 本体が `~` の引数をそのまま渡すだけ → `~` にできる
3. 副作用のある呼び出しがない → 純粋（`->`）

#### 3.4.5 呼び出し時の記法と解決

`!` と `~` は関数の呼び出し時にも使える。

- `f x` は純粋な呼び出しを表す
- `f! x` は副作用ありの呼び出しを表す
- `f~ x` は副作用がまだ確定していない呼び出しを表す

これらは別々の関数名ではなく、同じ関数束縛に対する呼び出し時の表記である。たとえば `map`、`map!`、`map~` は、`map~` として定義された1つの関数を異なる副作用モードで参照している。

副作用ポリモーフィックな関数 `~` は、呼び出し時に渡された関数や式の副作用に応じて解決される。つまり、`~` 付きで定義された関数は、使用箇所ごとに `->` または `->!` として具体化される。

```
map square [1,2,3]           // square は純粋 → map も純粋として呼べる
map! println! ["a","b","c"]  // println! は副作用あり → map も副作用ありとして呼ぶ
map~ f~ xs                   // この時点ではまだ副作用が確定していない
```

純粋関数は `!` 付きでは呼び出せず、副作用あり関数は接尾辞なしでは呼び出せない。呼び出し時の接尾辞は、呼び出し先の実際の副作用型と一致していなければならない。

```
square! 3      // エラー: square は純粋関数
println "x"    // エラー: println! は副作用あり関数
map! square xs // エラー: square を渡す限り map は純粋に解決される
```

#### 3.4.6 コンパイルエラーの例

```
// エラー: 純粋関数内で副作用のある関数を呼んでいる
fn badPure : int -> int =
  fn x -> {
    println! "oops"   // コンパイルエラー
    x
  }
```

### 3.5 バリアント型

`type` キーワードでバリアント型（代数的データ型）を定義する。各バリアントは `|` で区切り、コンストラクタ名は大文字で始まる。

#### 3.5.1 定義

```
type option 'a = {
  | Some 'a
  | None
}

type result 'a 'e = {
  | Ok 'a
  | Err 'e
}

// 引数なしのコンストラクタのみの場合（列挙型）
type color = {
  | Red
  | Green
  | Blue
}
```

#### 3.5.2 再帰型

バリアント型は再帰的に定義できる。

```
type tree 'a = {
  | Leaf 'a
  | Node (tree 'a) (tree 'a)
}

type my_list 'a = {
  | Nil
  | Cons 'a (my_list 'a)
}
```

#### 3.5.3 コンストラクタのスコープ

コンストラクタは定義されたモジュールのスコープに属する。他のモジュールから使う場合は `モジュール名.コンストラクタ名` でアクセスする。`import` でプレフィックスを省略できる。

```
module Option

type option 'a = {
  | Some 'a
  | None
}

module Main

// モジュール名付きでアクセス
let x = Option.Some 42
let y = Option.None

// import すればプレフィックスを省略できる
import Option
let z = Some 42
let w = None
```

#### 3.5.4 パターンマッチとの組み合わせ

コンストラクタはパターンマッチで分解できる（4.5.1 節参照）。

```
fn unwrap_or default_value = {
  | Some x => x
  | None => default_value
}

fn depth = {
  | Leaf _ => 1
  | Node left right =>
    if depth left > depth right then 1 + depth left
    else 1 + depth right
}
```

### 3.6 レコード型

wtml のレコード型は nominal である。型の同一性はフィールドの形ではなく、型定義とコンストラクタ名によって決まる。

レコード型は、1つのレコードコンストラクタと、そのフィールド集合を持つ。

#### 3.6.1 定義

```
type point = Point { x : float, y : float }

type person = Person {
  name : string,
  age : int,
}

// 多相レコード
type pair 'a 'b = Pair {
  first : 'a,
  second : 'b,
}
```

末尾のカンマ（trailing comma）は許容される。

同じフィールド構成を持っていても、型名またはコンストラクタ名が異なれば別の型である。

```
type point = Point { x : float, y : float }
type vec2 = Vec2 { x : float, y : float }

// point と vec2 は別の型
```

#### 3.6.2 レコードの生成

レコード値は、定義時に宣言したコンストラクタ名を使って生成する。

```
let origin = Point { x = 0.0, y = 0.0 }
let p = Point { x = 1.0, y = 2.0 }
let bob = Person { name = "Bob", age = 30 }
```

フィールド名は定義済みのものと一致しなければならず、各フィールドはちょうど1回ずつ与えなければならない。

#### 3.6.3 フィールドアクセス

レコード値のフィールドにはドット記法でアクセスする。

```
p.x       // 1.0
p.y       // 2.0
bob.name  // "Bob"
```

フィールドアクセスは、そのフィールドを持つレコード型の値に対してのみ許される。

#### 3.6.4 レコード更新（functional update）

`with` キーワードで、既存のレコードの一部のフィールドだけ変更した新しいレコードを作る。

```
let p2 = { p with x = 3.0 }
// p2 = Point { x = 3.0, y = 2.0 }

let older_bob = { bob with age = 31 }
```

更新後の値は、元の値と同じレコード型を持つ。更新できるのは、そのレコード型に定義されたフィールドのみである。

#### 3.6.5 コンストラクタのスコープ

レコードコンストラクタは定義されたモジュールのスコープに属する。他のモジュールから使う場合は `モジュール名.コンストラクタ名` でアクセスする。`import` でプレフィックスを省略できる。

```
module Geometry

type point = Point { x : float, y : float }

module Main

import Geometry
let p = Point { x = 1.0, y = 2.0 }

// import なしの場合
let q = Geometry.Point { x = 3.0, y = 4.0 }
```

#### 3.6.6 パターンマッチとの組み合わせ

レコードはコンストラクタ名付きのパターンで分解できる。

```
fn distance_from_origin p =
  match p {
    | Point { x, y } => (x, y)
  }

fn get_x = {
  | Point { x, .. } => x
}
```

`Point { x, y }` は全フィールドを束縛する。`Point { x, .. }` は一部のフィールドだけを束縛し、残りを無視する。`..` を使わないレコードパターンでは、そのレコード型の全フィールドをちょうど1回ずつ列挙しなければならない。

レコードパターンでは、そのレコード型に存在しないフィールド名は使えない。

## 4. 式と構文

### 4.1 値束縛（let）

`let` は値を名前に束縛する。スコープは囲むブロック `{}` の終わりまで。

```
let x = 42
let name = "wtml"
let double = fn x -> x * 2
```

### 4.2 関数定義（fn）

#### 4.2.1 名前付き関数定義

```
fn 名前 引数... = 本体
```

```
fn square x = x * x

fn add x y = x + y

fn length (x : 'a list) : int =
  if x = [] then 0
  else 1 + length (List.tl x)
```

#### 4.2.2 無名関数（ラムダ式）

```
fn 引数... -> 本体
```

```
let double = fn x -> x * 2
let add = fn a b -> a + b
map (fn x -> x * x) [1, 2, 3]
```

#### 4.2.3 関数宣言（本体なし）

`=` を省略すると宣言（シグネチャ）のみとなる。

```
fn length : 'a list -> int
fn head : 'a list -> 'a
fn map~ : ('a ->~ 'b) -> 'a list ->~ 'b list
```

### 4.3 ブロック式

`{}` で囲まれた複数の式からなるブロック。最後の式の値がブロック全体の値になる。単一式の場合は `{}` は不要。

ブロック内の式は**改行**で区切る。1行に複数の式を書く場合は**セミコロン `;`** で区切る。セミコロンと改行は同等の区切り子であり、混在も可能である。

```
// 改行で区切る（基本）
fn printAndReturn! x = {
  println! x
  x
}

// セミコロンで区切る（1行に複数の式を書く場合）
fn printAndReturn! x = { println! x; x }
```

`let` のスコープはそれを囲むブロックの終わりまでである。

```
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
```

### 4.4 条件式（if-then-else）

```
if 条件 then 真の場合 else 偽の場合
```

```
if x = [] then 0
else 1 + length (List.tl x)
```

### 4.5 パターンマッチ（match）

`match` 式は必ず `{}` で囲む。各パターン節は `|` で始まり、`=>` で本体を分ける。

```
match 式 {
  | パターン1 => 式1
  | パターン2 => 式2
  ...
}
```

```
match xs {
  | [] => []
  | y :: ys => f~ y :: map~ f~ ys
}

match (i % 3, i % 5) {
  | (0, 0) => "FizzBuzz"
  | (0, _) => "Fizz"
  | (_, 0) => "Buzz"
  | _ => string_of_int i
}
```

#### 4.5.1 パターン

| パターン | 説明 | 例 |
|---|---|---|
| リテラル | 定数値にマッチ | `0`, `"hello"` |
| 変数 | 任意の値にマッチし束縛 | `x`, `rest` |
| ワイルドカード | 任意の値にマッチ（束縛しない） | `_` |
| コンストラクタ | バリアントのコンストラクタにマッチし分解 | `Some x`, `None`, `Leaf _` |
| レコード | レコードのフィールドに分解 | `Point { x, y }`, `Point { x, .. }` |
| コンスパターン | リストの先頭と残りに分解 | `x :: xs`, `_ :: rest` |
| 空リスト | 空リストにマッチ | `[]` |
| タプル | タプルの要素に分解 | `(0, 0)`, `(_, 0)` |

#### 4.5.2 関数本体がパターンマッチのみの場合の省略記法

関数の本体が単一の `match` 式である場合、以下の省略記法が使える。

```
fn 名前 = {
  | パターン1 => 式1
  | パターン2 => 式2
}
```

この場合、暗黙の引数を1つ取り、その引数に対してパターンマッチを行う。

```
# 以下の2つは同等
fn length x =
  match x {
    | [] => 0
    | _ :: rest => 1 + length rest
  }

fn length = {
  | [] => 0
  | _ :: rest => 1 + length rest
}
```

型注釈と組み合わせることもできる。

```
fn length : 'a list -> int = {
  | [] => 0
  | _ :: rest => 1 + length rest
}
```

### 4.6 リスト操作

| 構文 | 説明 |
|---|---|
| `[]` | 空リスト |
| `[a, b, c]` | リストリテラル |
| `x :: xs` | cons（先頭に要素を追加） |

### 4.7 演算子

| 演算子 | 説明 |
|---|---|
| `+`, `-`, `*`, `/` | 算術演算 |
| `%` | 剰余 |
| `=` | 等値比較 |
| `>`, `<`, `>=`, `<=` | 順序比較 |

### 4.8 関数適用

関数適用は並置（juxtaposition）で行う。引数はスペースで区切る。

```
square 5
add 1 2
map square [1, 2, 3]
println! "hello"
```

括弧はグルーピングに使う。

```
1 + length (List.tl x)
fold_left (fn a b -> a + b) 0 xs
```

## 5. モジュールシステム

### 5.1 モジュール定義

`module` キーワードでモジュールを定義する。以降の定義はそのモジュールに属する。

```
module List
fn length = { ... }
fn head = { ... }

module Main
fn main! = { ... }
```

### 5.2 モジュールアクセス

モジュール内の値には `モジュール名.値名` でアクセスする。

```
A.x
List.tl x
```

### 5.3 import

`import` でモジュールの内容を現在のスコープに展開し、モジュール名のプレフィックスを省略できるようにする。

```
module Main
import List

// List.length の代わりに length と書ける
let n = length [1, 2, 3]

// List.length でも引き続きアクセス可能
let m = List.length [4, 5, 6]
```

## 6. プログラム構造

wtml プログラムは1つ以上のモジュール定義から構成される。各モジュールは値束縛・関数定義・関数宣言を含む。

```
module モジュール名
  型定義（バリアント型・レコード型）...
  定義（値束縛・関数定義・関数宣言）...

module モジュール名
  型定義（バリアント型・レコード型）...
  定義（値束縛・関数定義・関数宣言）...
```

実行のエントリーポイントは `Main` モジュールの `main!` 関数である（慣例）。

## 7. 組み込み関数

| 関数 | 型 | 説明 |
|---|---|---|
| `println!` | `string ->! unit` | 文字列を出力して改行 |
| `string_of_int` | `int -> string` | 整数を文字列に変換 |
| `error` | `string -> 'a` | エラーを発生させる |

## 8. 完全なプログラム例

```
module List

fn length : 'a list -> int
fn head : 'a list -> 'a
fn map~ : ('a ->~ 'b) -> 'a list ->~ 'b list

fn length = {
  | [] => 0
  | _ :: rest => 1 + length rest
}

fn head = {
  | [] => error "empty list"
  | x :: _ => x
}

fn map~ f~ xs =
  match xs {
    | [] => []
    | y :: ys => f~ y :: map~ f~ ys
  }

fn filter~ pred~ = {
  | [] => []
  | y :: ys =>
    if pred~ y then y :: filter~ pred~ ys
    else filter~ pred~ ys
}

fn fold_left f acc = {
  | [] => acc
  | y :: ys => fold_left f (f acc y) ys
}

module Main

import List

fn square x = x * x

fn sum xs = fold_left (fn a b -> a + b) 0 xs

fn print_all! xs =
  map! (fn x -> { println! x; x }) xs

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

## 付録A. 文法（BNF 風）

```
program     ::= module_def+

module_def  ::= 'module' UIDENT definition*

definition  ::= let_def | fn_def | fn_decl | type_def | import_stmt

let_def     ::= 'let' pattern (':' type)? '=' expr

fn_def      ::= 'fn' IDENT_EFF param* (':' type)? '=' expr
              | 'fn' IDENT_EFF (':' type)? '=' '{' match_arm+ '}'

fn_decl     ::= 'fn' IDENT_EFF ':' type

type_def    ::= 'type' IDENT TYVAR* '=' '{' variant_arm+ '}'
              | 'type' IDENT TYVAR* '=' UIDENT '{' field_def (',' field_def)* ','? '}'

variant_arm ::= '|' UIDENT type*

field_def   ::= IDENT ':' type

import_stmt ::= 'import' UIDENT

param       ::= IDENT_EFF
              | '(' IDENT_EFF ':' type ')'

expr        ::= 'let' pattern (':' type)? '=' expr
              | 'fn' param+ '->' expr
              | 'if' expr 'then' expr 'else' expr
              | 'match' expr '{' match_arm+ '}'
              | '{' expr (sep expr)* '}'
              | expr binop expr
              | '#' expr                         (* デバッグ式 *)
              | '#' '{' expr (sep expr)* '}'    (* デバッグブロック *)
              | expr expr                       (* 関数適用 *)
              | expr '::' expr
              | expr ':' type
              | expr '.' IDENT                  (* フィールドアクセス *)
              | UIDENT '.' IDENT_EFF
              | UIDENT '{' field_init (',' field_init)* ','? '}'   (* レコード生成 *)
              | '{' expr 'with' field_init (',' field_init)* ','? '}'  (* レコード更新 *)
              | UIDENT expr*                    (* コンストラクタ適用 *)
              | '(' expr (',' expr)* ')'
              | '[' (expr (',' expr)*)? ']'
              | literal
              | IDENT_EFF

field_init  ::= IDENT '=' expr

match_arm   ::= '|' pattern '=>' expr

pattern     ::= '_'
              | IDENT
              | literal
              | '[]'
              | UIDENT pattern*                 (* コンストラクタパターン *)
              | UIDENT '{' field_pat (',' field_pat)* ','? '}'     (* レコードパターン *)
              | UIDENT '{' field_pat (',' field_pat)* ',' '..' '}' (* レコード部分パターン *)
              | pattern '::' pattern
              | '(' pattern (',' pattern)* ')'

field_pat   ::= IDENT                           (* フィールド名のみ: 同名の変数に束縛 *)
              | IDENT ':' pattern               (* フィールド名: パターン *)

type        ::= base_type
              | type arrow type
              | type IDENT                      (* 型適用: 'a list *)
              | IDENT type+                     (* 型適用（前置）: option 'a *)
              | '(' type (',' type)* ')'
              | TYVAR

arrow       ::= '->' | '->!' | '->~'

base_type   ::= 'int' | 'float' | 'char' | 'string' | 'bool' | 'unit'

IDENT       ::= [a-z_][a-zA-Z0-9_]*
IDENT_EFF   ::= IDENT ('!' | '~')?
UIDENT      ::= [A-Z][a-zA-Z0-9_]*
TYVAR       ::= "'" IDENT
literal     ::= INT | FLOAT | CHAR | STRING | 'true' | 'false' | '()'
binop       ::= '+' | '-' | '*' | '/' | '%' | '=' | '>' | '<' | '>=' | '<='
sep         ::= NEWLINE | ';'               (* 式の区切り: 改行またはセミコロン *)
```

`IDENT_EFF` は構文上は単一の識別子として現れるが、副作用サフィックスは独立した別名を導入しない。`f`、`f!`、`f~` は同一の関数束縛を異なる副作用モードで参照する表記であり、許される形はその束縛の副作用型によって決まる。

レコード型は nominal である。`point` と `vec2` が同じフィールド構成を持っていても、異なる型定義または異なるコンストラクタを持つ限り互換ではない。

## 付録B. 副作用型サブタイピングの図

```
        ->~
       /   \
      /     \
    ->      ->!
     \     /
      \   /
   コンパイルエラー
   (->! から -> への変換は不可)
```

`->~` は `->` と `->!` の両方のスーパータイプである。`->` と `->!` の間には `->` から `->!` への暗黙変換のみ許される（逆は不可）。
