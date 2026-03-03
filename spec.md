# wtml Language Specification

Version: 0.1 (draft)

## 1. Overview

wtml is an ML-family functional programming language implemented in OCaml. It has the following characteristics:

- Strict evaluation
- Hindley-Milner-based type inference
- A simple module system (no OOP)
- A mechanism for tracking the presence of side effects in the type system
- A Lisp VM as the compilation target

## 2. Lexical Structure

### 2.1 Comments

Text from `//` to the end of the line is a line comment. Text enclosed by `/*` and `*/` is a block comment. Block comments can be nested.

```
// This is a comment
let x = 1  // End-of-line comment

/*
  This is
  a block comment
*/
```

### 2.2 Keywords

The following identifiers are reserved words and cannot be used as variable names or function names.

```
let  fn  type  match  if  then  else  with  module  import  true  false
```

### 2.3 Identifiers

Regular identifiers start with a lowercase alphabetic character or underscore, and are composed of alphanumeric characters and underscores.

```
x  foo  my_value  fold_left  string_of_int
```

`!` and `~` may be appended as suffixes to indicate side effects. `#` is reserved as the prefix for debug expressions (see Section 2.5).

```
println!  map~  printAndReturn!  filter~
```

Module names and data constructor names begin with an uppercase alphabetic character.

```
List  Main  Some  None  Point
```

Type variables begin with a single quote.

```
'a  'b  'key  'value
```

User-defined type names are regular identifiers and begin with a lowercase letter.

```
option  result  point  person
```

### 2.4 Literals

| Kind | Examples |
|---|---|
| Integer | `0`, `42`, `-1` |
| Float | `0.0`, `3.14`, `-1.5` |
| Character | `'a'`, `'Z'`, `'\n'` |
| String | `"hello"`, `"FizzBuzz"` |
| Boolean | `true`, `false` |
| List | `[]`, `[1, 2, 3]`, `["a", "b", "c"]` |
| Tuple | `(1, 2)`, `(i % 3, i % 5)` |
| Unit | `()` |

### 2.5 Debug Expressions

`#` is the prefix for debug expressions. An expression following `#` is evaluated only in debug builds, and is removed by the compiler in release builds.

Side effects inside a debug expression do not affect the type system. In other words, even if a `!` function is called inside a debug expression, the enclosing function's effect type does not change.

```
// Single expression
fn square x = {
  # println! x       // Printed only in debug builds. square remains pure.
  x * x
}

// Block (multiple expressions)
fn foo x = {
  # {
    println! x
    println! "done"
  }
  x + 1
}
```

The type of a debug expression is always `unit`. The value of a debug expression cannot be used in program logic.

## 3. Type System

### 3.1 Primitive Types

| Type | Description |
|---|---|
| `int` | Integer |
| `float` | Float |
| `char` | Character |
| `string` | String |
| `bool` | Boolean (`true` / `false`) |
| `unit` | Unit type (its value is `()`) |
| `'a` | Type variable (polymorphic type) |

### 3.2 Compound Types

| Type Syntax | Description |
|---|---|
| `'a list` | List type |
| `('a, 'b)` | Tuple type |
| `'a -> 'b` | Pure function type |
| `'a ->! 'b` | Effectful function type |
| `'a ->~ 'b` | Effect-polymorphic function type |
| `option 'a` | Variant type (user-defined) |
| `point` | User-defined record type name |

### 3.3 Type Annotations

Type annotations are written using `:`. If omitted, they are determined through type inference.

Record types are defined like `type point = Point { x : float, y : float }`.

```
// Type annotation on an expression
let x : int = 42

// Type annotation on a function argument
fn length (x : 'a list) : int = ...

// Function type declaration
fn length : 'a list -> int
```

### 3.4 Effect Type System

The most distinctive feature of wtml's type system is that it tracks whether functions have side effects at the type level.

#### 3.4.1 Function Arrow Types

There are three kinds of arrows for function types.

| Arrow | Meaning | Use Case |
|---|---|---|
| `->` | Pure (no side effects) | Referentially transparent functions |
| `->!` | Effectful | Functions that perform I/O, state mutation, etc. |
| `->~` | Effect-polymorphic | Higher-order functions whose effects depend on argument functions |

#### 3.4.2 Notation at Definition Time

In function definitions, the function name carries a suffix indicating its kind of effect.

| Suffix | Meaning | Examples |
|---|---|---|
| None | Pure | `square`, `length`, `sum` |
| `!` | Effectful | `println!`, `printAndReturn!`, `main!` |
| `~` | Effect-polymorphic | `map~`, `filter~` |

The suffix must match the function's type.

`~` does not mean "always effectful". A function defined with `~` may behave as either pure or effectful depending on the arguments passed at the call site.

#### 3.4.3 Subtyping Rules

The following subtyping relationships exist between effect types.

```
->  <:  ->!    A pure function can be passed where an effectful function is expected
->  <:  ->~    A pure function can be passed to ~ (~ resolves as pure)
->! <:  ->~    An effectful function can also be passed to ~ (~ resolves as effectful)
->! ≠>  ->     An effectful function cannot be passed where a pure function is expected (compile error)
```

That is, `->~` is the least upper bound of `->` and `->!`, and `->` is the most restrictive type.

#### 3.4.4 Inference Rules

Function effects are inferred according to the following rules:

1. If the body calls a `!` function, the function itself must be `!`
2. If the body only forwards a `~` argument, it can be `~`
3. If there are no effectful calls, the function is pure (`->`)

#### 3.4.5 Notation and Resolution at Call Sites

`!` and `~` can also be used when calling functions.

- `f x` represents a pure call
- `f! x` represents an effectful call
- `f~ x` represents a call whose effect has not yet been fixed

These are not separate function names. For example, `map`, `map!`, and `map~` refer to the same function binding defined as `map~`, but in different effect modes at the call site.

An effect-polymorphic function `~` is resolved according to the effect of the function or expression passed at the call site. In other words, a function defined with `~` is instantiated as either `->` or `->!` depending on how it is used.

```
map square [1,2,3]           // square is pure, so map can be called as pure
map! println! ["a","b","c"]  // println! is effectful, so map is called as effectful
map~ f~ xs                   // the effect is not fixed yet at this point
```

Pure functions cannot be called with `!`, and effectful functions cannot be called without a suffix. The call-site suffix must match the actual effect type of the callee.

```
square! 3      // error: square is pure
println "x"    // error: println! is effectful
map! square xs // error: as long as square is passed, map resolves as pure
```

#### 3.4.6 Example of a Compile Error

```
// Error: calling an effectful function inside a pure function
fn badPure : int -> int =
  fn x -> {
    println! "oops"   // compile error
    x
  }
```

### 3.5 Variant Types

The `type` keyword defines variant types (algebraic data types). Each variant is separated by `|`, and constructor names begin with an uppercase letter.

#### 3.5.1 Definitions

```
type option 'a = {
  | Some 'a
  | None
}

type result 'a 'e = {
  | Ok 'a
  | Err 'e
}

// Constructors without arguments only (enum-like)
type color = {
  | Red
  | Green
  | Blue
}
```

#### 3.5.2 Recursive Types

Variant types can be defined recursively.

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

#### 3.5.3 Constructor Scope

Constructors belong to the scope of the module in which they are defined. To use them from another module, access them as `ModuleName.ConstructorName`. The prefix can be omitted with `import`.

```
module Option

type option 'a = {
  | Some 'a
  | None
}

module Main

// Access with module prefix
let x = Option.Some 42
let y = Option.None

// Prefix can be omitted after import
import Option
let z = Some 42
let w = None
```

#### 3.5.4 With Pattern Matching

Constructors can be destructured in pattern matching (see Section 4.5.1).

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

### 3.6 Record Types

Record types in wtml are nominal. Type identity is determined not by field shape, but by the type definition and constructor name.

A record type has one record constructor and its associated set of fields.

#### 3.6.1 Definitions

```
type point = Point { x : float, y : float }

type person = Person {
  name : string,
  age : int,
}

// Polymorphic record
type pair 'a 'b = Pair {
  first : 'a,
  second : 'b,
}
```

Trailing commas are allowed.

Even if two records have the same field structure, they are different types if their type names or constructor names differ.

```
type point = Point { x : float, y : float }
type vec2 = Vec2 { x : float, y : float }

// point and vec2 are different types
```

#### 3.6.2 Record Construction

Record values are created using the constructor name declared in the type definition.

```
let origin = Point { x = 0.0, y = 0.0 }
let p = Point { x = 1.0, y = 2.0 }
let bob = Person { name = "Bob", age = 30 }
```

Field names must match the defined fields, and each field must be provided exactly once.

#### 3.6.3 Field Access

Record fields are accessed with dot notation.

```
p.x       // 1.0
p.y       // 2.0
bob.name  // "Bob"
```

Field access is allowed only on values of record types that actually have that field.

#### 3.6.4 Record Update (Functional Update)

With the `with` keyword, a new record can be created by changing only part of an existing record.

```
let p2 = { p with x = 3.0 }
// p2 = Point { x = 3.0, y = 2.0 }

let older_bob = { bob with age = 31 }
```

The updated value has the same record type as the original. Only fields defined on that record type may be updated.

#### 3.6.5 Constructor Scope

Record constructors belong to the scope of the module in which they are defined. To use them from another module, access them as `ModuleName.ConstructorName`. The prefix can be omitted with `import`.

```
module Geometry

type point = Point { x : float, y : float }

module Main

import Geometry
let p = Point { x = 1.0, y = 2.0 }

// Without import
let q = Geometry.Point { x = 3.0, y = 4.0 }
```

#### 3.6.6 With Pattern Matching

Records can be destructured with constructor-qualified patterns.

```
fn distance_from_origin p =
  match p {
    | Point { x, y } => (x, y)
  }

fn get_x = {
  | Point { x, .. } => x
}
```

`Point { x, y }` binds all fields. `Point { x, .. }` binds only some fields and ignores the rest. In a record pattern without `..`, all fields of that record type must be listed exactly once.

Record patterns cannot use field names that do not exist on that record type.

## 4. Expressions and Syntax

### 4.1 Value Bindings (`let`)

`let` binds a value to a name. Its scope lasts until the end of the enclosing block `{}`.

```
let x = 42
let name = "wtml"
let double = fn x -> x * 2
```

### 4.2 Function Definitions (`fn`)

#### 4.2.1 Named Function Definitions

```
fn name args... = body
```

```
fn square x = x * x

fn add x y = x + y

fn length (x : 'a list) : int =
  if x = [] then 0
  else 1 + length (List.tl x)
```

#### 4.2.2 Anonymous Functions (Lambda Expressions)

```
fn args... -> body
```

```
let double = fn x -> x * 2
let add = fn a b -> a + b
map (fn x -> x * x) [1, 2, 3]
```

#### 4.2.3 Function Declarations (Without a Body)

If `=` is omitted, the declaration is a signature only.

```
fn length : 'a list -> int
fn head : 'a list -> 'a
fn map~ : ('a ->~ 'b) -> 'a list ->~ 'b list
```

### 4.3 Block Expressions

A block enclosed in `{}` contains multiple expressions. The value of the last expression becomes the value of the entire block. For a single expression, `{}` is unnecessary.

Expressions inside a block are separated by **newlines**. If multiple expressions are written on one line, they are separated by a **semicolon `;`**. Semicolons and newlines are equivalent separators and may be mixed.

```
// Separated by newlines (basic style)
fn printAndReturn! x = {
  println! x
  x
}

// Separated by semicolon (when writing multiple expressions on one line)
fn printAndReturn! x = { println! x; x }
```

The scope of a `let` binding extends to the end of the enclosing block.

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

### 4.4 Conditional Expressions (`if-then-else`)

```
if condition then when_true else when_false
```

```
if x = [] then 0
else 1 + length (List.tl x)
```

### 4.5 Pattern Matching (`match`)

A `match` expression must always be enclosed in `{}`. Each pattern arm starts with `|`, and `=>` separates the pattern from the body.

```
match expr {
  | pattern1 => expr1
  | pattern2 => expr2
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

#### 4.5.1 Patterns

| Pattern | Description | Example |
|---|---|---|
| Literal | Matches a constant value | `0`, `"hello"` |
| Variable | Matches any value and binds it | `x`, `rest` |
| Wildcard | Matches any value without binding | `_` |
| Constructor | Matches and destructures a variant constructor | `Some x`, `None`, `Leaf _` |
| Record | Destructures record fields | `Point { x, y }`, `Point { x, .. }` |
| Cons pattern | Decomposes a list into head and tail | `x :: xs`, `_ :: rest` |
| Empty list | Matches the empty list | `[]` |
| Tuple | Decomposes a tuple into its elements | `(0, 0)`, `(_, 0)` |

#### 4.5.2 Shorthand When the Function Body Is Only a Pattern Match

If a function body consists of a single `match` expression, the following shorthand may be used.

```
fn name = {
  | pattern1 => expr1
  | pattern2 => expr2
}
```

In this case, the function implicitly takes one argument and pattern matches on that argument.

```
// The following two definitions are equivalent
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

This form can also be combined with type annotations.

```
fn length : 'a list -> int = {
  | [] => 0
  | _ :: rest => 1 + length rest
}
```

### 4.6 List Operations

| Syntax | Description |
|---|---|
| `[]` | Empty list |
| `[a, b, c]` | List literal |
| `x :: xs` | Cons (prepend an element) |

### 4.7 Operators

| Operator | Description |
|---|---|
| `+`, `-`, `*`, `/` | Arithmetic |
| `%` | Remainder |
| `=` | Equality comparison |
| `>`, `<`, `>=`, `<=` | Ordering comparison |

### 4.8 Function Application

Function application uses juxtaposition. Arguments are separated by spaces.

```
square 5
add 1 2
map square [1, 2, 3]
println! "hello"
```

Parentheses are used for grouping.

```
1 + length (List.tl x)
fold_left (fn a b -> a + b) 0 xs
```

## 5. Module System

### 5.1 Module Definitions

The `module` keyword defines a module. Subsequent definitions belong to that module.

```
module List
fn length = { ... }
fn head = { ... }

module Main
fn main! = { ... }
```

### 5.2 Module Access

Values inside a module are accessed as `ModuleName.valueName`.

```
A.x
List.tl x
```

### 5.3 import

`import` brings a module's contents into the current scope, allowing the module-name prefix to be omitted.

```
module Main
import List

// You can write length instead of List.length
let n = length [1, 2, 3]

// List.length remains accessible as well
let m = List.length [4, 5, 6]
```

## 6. Program Structure

A wtml program consists of one or more module definitions. Each module contains type definitions, value bindings, function definitions, and function declarations.

```
module ModuleName
  type definitions (variant types, record types)...
  definitions (value bindings, function definitions, function declarations)...

module ModuleName
  type definitions (variant types, record types)...
  definitions (value bindings, function definitions, function declarations)...
```

The conventional entry point for execution is the `main!` function in the `Main` module.

## 7. Built-in Functions

| Function | Type | Description |
|---|---|---|
| `println!` | `string ->! unit` | Prints a string followed by a newline |
| `string_of_int` | `int -> string` | Converts an integer to a string |
| `error` | `string -> 'a` | Raises an error |

## 8. Complete Program Example

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

## Appendix A. Grammar (BNF-like)

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
              | '#' expr                         (* debug expression *)
              | '#' '{' expr (sep expr)* '}'    (* debug block *)
              | expr expr                       (* function application *)
              | expr '::' expr
              | expr ':' type
              | expr '.' IDENT                  (* field access *)
              | UIDENT '.' IDENT_EFF
              | UIDENT '{' field_init (',' field_init)* ','? '}'   (* record construction *)
              | '{' expr 'with' field_init (',' field_init)* ','? '}'  (* record update *)
              | UIDENT expr*                    (* constructor application *)
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
              | UIDENT pattern*                 (* constructor pattern *)
              | UIDENT '{' field_pat (',' field_pat)* ','? '}'     (* record pattern *)
              | UIDENT '{' field_pat (',' field_pat)* ',' '..' '}' (* partial record pattern *)
              | pattern '::' pattern
              | '(' pattern (',' pattern)* ')'

field_pat   ::= IDENT                           (* field name only: binds to a variable of the same name *)
              | IDENT ':' pattern               (* field name: pattern *)

type        ::= base_type
              | type arrow type
              | type IDENT                      (* type application: 'a list *)
              | IDENT type+                     (* prefix type application: option 'a *)
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
sep         ::= NEWLINE | ';'               (* expression separator: newline or semicolon *)
```

`IDENT_EFF` appears syntactically as a single identifier, but effect suffixes do not introduce separate bindings. `f`, `f!`, and `f~` are different notations for referring to the same function binding in different effect modes, and the permitted forms are determined by that binding's effect type.

Record types are nominal. Even if `point` and `vec2` have the same field structure, they are not compatible as long as they come from different type definitions or use different constructors.

## Appendix B. Effect-Type Subtyping Diagram

```
        ->~
       /   \
      /     \
    ->      ->!
     \     /
      \   /
   compile error
   (conversion from ->! to -> is not allowed)
```

`->~` is a supertype of both `->` and `->!`. Between `->` and `->!`, only the implicit conversion from `->` to `->!` is allowed (not the reverse).

---

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
