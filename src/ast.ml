(* ===== Position & Error ===== *)

type pos = {
    filename : string;
    line : int;
    col : int;
}

let dummy_pos = { filename = "<none>"; line = 0; col = 0 }

let s_pos pos =
    Printf.sprintf "\"%s\":line=%d:col=%d:" pos.filename pos.line pos.col

exception Error of pos * string
let error pos msg = raise (Error (pos, msg))
let error_msg pos msg = s_pos pos ^ msg

(* ===== Tokens ===== *)

type token_decl =
    | EOF | NEWLINE
    | Int of int | Float of float | Char of char
    | String of string | Id of string
    | MODULE | IMPORT | TYPE | LET | FN | MATCH | WITH
    | TRUE | FALSE
    | IF | THEN | ELSE | BEGIN | END | SEMI
    | COLON | DCOLON | DOT | COMMA | ARROW | ARROW_BANG | ARROW_TILDE
    | HASH
    | ASSIGN | OR | AND | LOR | LAND
    | LPAR | RPAR | LBRA | RBRA | LBRACE | RBRACE | NOT
    | EQ | NEQ | EQL | NEQL | LT | LE | GT | GE
    | PLUS | MINUS | STAR | SLASH | PERCENT
    | QUES | UNIT | NIL
    | BAR | FATARROW | DOTDOT
and token = token_decl * pos

(* ===== Effect Kind ===== *)

type effect =
    | Pure        (* -> *)
    | Effectful   (* ->! *)
    | Polymorphic (* ->~ *)

(* Identifier with optional effect suffix *)
type ident_eff = {
    name : string;
    eff : effect;
}

(* ===== Type Expressions ===== *)

type typ =
    | TInt                                  (* int *)
    | TFloat                                (* float *)
    | TChar                                 (* char *)
    | TString                               (* string *)
    | TBool                                 (* bool *)
    | TUnit                                 (* unit *)
    | TVar of string                        (* 'a *)
    | TArrow of typ * effect * typ          (* t1 -> t2, t1 ->! t2, t1 ->~ t2 *)
    | TList of typ                          (* t list *)
    | TTuple of typ list                    (* (t1, t2, ...) *)
    | TApp of string * typ list             (* option 'a, result 'a 'e *)

(* ===== Patterns ===== *)

type pattern =
    | PWild                                 (* _ *)
    | PVar of string                        (* x *)
    | PInt of int                            (* 0, 42 *)
    | PFloat of float                       (* 3.14 *)
    | PChar of char                         (* 'a' *)
    | PString of string                     (* "hello" *)
    | PBool of bool                         (* true, false *)
    | PUnit                                 (* () *)
    | PNil                                  (* [] *)
    | PCons of pattern * pattern            (* x :: xs *)
    | PTuple of pattern list                (* (p1, p2, ...) *)
    | PConstructor of string * pattern list (* Some x, None, Leaf _ *)
    | PRecord of string * field_pat list * bool
        (* Point { x, y } (closed=false when ..) *)

and field_pat =
    | FPBind of string                      (* x  -- binds field to same name *)
    | FPPattern of string * pattern         (* x : pat *)

(* ===== Expressions ===== *)

type expr = {
    expr_desc : expr_desc;
    expr_pos : pos;
}

and expr_desc =
    (* Literals *)
    | EInt of int
    | EFloat of float
    | EChar of char
    | EString of string
    | EBool of bool
    | EUnit
    (* Variables and access *)
    | EVar of ident_eff                     (* x, f!, g~ *)
    | EModuleAccess of string * ident_eff   (* List.head, Option.Some *)
    | EFieldAccess of expr * string         (* e.x *)
    (* Collections *)
    | EList of expr list                    (* [a, b, c] *)
    | ETuple of expr list                   (* (a, b, c) *)
    | ECons of expr * expr                  (* x :: xs *)
    (* Binding *)
    | ELet of pattern * typ option * expr * expr
        (* let p : t = e1 in e2 (e2 = rest of block) *)
    (* Functions *)
    | EFn of effect * param list * expr     (* fn x -> e, fn! x -> e *)
    | EApp of expr * expr                   (* f x *)
    (* Control flow *)
    | EIf of expr * expr * expr             (* if c then t else f *)
    | EMatch of expr * match_arm list       (* match e { | p => e ... } *)
    (* Block *)
    | EBlock of expr list                   (* { e1; e2; ... } *)
    (* Record *)
    | ERecordCreate of string * field_init list
        (* Point { x = 1.0, y = 2.0 } *)
    | ERecordUpdate of expr * field_init list
        (* { e with x = 3.0 } *)
    (* Constructor *)
    | EConstructor of string * expr list    (* Some 42, None *)
    (* Type annotation *)
    | EAnnot of expr * typ                  (* e : t *)
    (* Debug *)
    | EDebug of expr                        (* # e *)
    (* Binary operators *)
    | EBinop of binop * expr * expr

and param =
    | Param of ident_eff                    (* x, f~ *)
    | ParamAnnot of ident_eff * typ         (* (x : int) *)

and match_arm = {
    arm_pat : pattern;
    arm_body : expr;
}

and field_init = {
    fi_name : string;
    fi_expr : expr;
}

and binop =
    | OpAdd | OpSub | OpMul | OpDiv | OpMod
    | OpEq | OpLt | OpGt | OpLe | OpGe

(* ===== Variant & Record Type Definitions ===== *)

type variant_arm = {
    va_ctor : string;       (* constructor name, e.g. Some *)
    va_args : typ list;     (* argument types *)
}

type field_def = {
    fd_name : string;       (* field name *)
    fd_type : typ;          (* field type *)
}

type type_def =
    | TDVariant of string * string list * variant_arm list
        (* type option 'a = { | Some 'a | None } *)
    | TDRecord of string * string list * string * field_def list
        (* type point = Point { x : float, y : float }
           name, type params, constructor name, fields *)

(* ===== Top-level Definitions ===== *)

type definition =
    | DLet of pattern * typ option * expr
        (* let x = 42, let x : int = 42 *)
    | DFn of ident_eff * param list * typ option * expr
        (* fn square x = x * x *)
    | DFnMatch of ident_eff * typ option * match_arm list
        (* fn length = { | [] => 0 | ... } *)
    | DFnDecl of ident_eff * typ
        (* fn length : 'a list -> int *)
    | DType of type_def
        (* type option 'a = { | Some 'a | None } *)
    | DImport of string
        (* import List *)

(* ===== Module & Program ===== *)

type module_def = {
    mod_name : string;
    mod_defs : definition list;
}

type program = module_def list

(* ===== Helper constructors ===== *)

let mk_expr pos desc = { expr_desc = desc; expr_pos = pos }

let mk_ident name = { name; eff = Pure }
let mk_ident_bang name = { name; eff = Effectful }
let mk_ident_tilde name = { name; eff = Polymorphic }

