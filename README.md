# Project Phase 3 — mC Semantic Analyzer

**CS 4318 — Compiler Construction**

## Overview

Build a static semantic analyzer for the **mC** language that augments the symbol table and AST (from Phase 2) with semantic information. The analyzer detects:

1. **Scoping errors** — undeclared and multiply declared identifiers
2. **Type errors** — type mismatches in assignments and function calls
3. **Array errors** — invalid indexing (non-array variables, non-integer or out-of-bounds indices)
4. **Function errors** — argument count and type mismatches

## Repository Structure

```
├── src/
│   ├── scanner.l      # Lexer (reused from Phase 1)
│   ├── parser.y       # YACC grammar + semantic analysis — implement checks here
│   ├── tree.c / .h    # AST node definitions and printAst()
│   ├── strtab.c / .h  # Hierarchical symbol table — implement here
│   └── driver.c       # Entry point — provided, do not modify
├── test/
│   ├── cases/         # Sample .mC input programs
│   └── exp/           # Expected output for each test case
└── Makefile
```

## Building

```sh
make clean && make
```

The binary is written to `obj/mcc`.

## Running

The compiler takes a source file as its argument, with optional flags to print the AST or symbol table:

```sh
./obj/mcc [--ast] [--sym] input.mC
./obj/mcc --help
```

| Flag | Effect |
|------|--------|
| `--ast` | Print a textual representation of the AST |
| `--sym` | Print a textual representation of the symbol table |
| `-h`, `--help` | Print usage information and exit |

## Testing

```sh
make test
```

Runs all cases in `test/cases/` against the expected output in `test/exp/`.

## What to Implement

### `strtab.c` — Hierarchical Symbol Table

The symbol table is a **tree of hash tables** mirroring the scope nesting. Each `table_node` holds a hash table of up to `MAXIDS` entries and pointers to its parent and child scopes.

| Function | Description |
|----------|-------------|
| `ST_insert(id, data_type, symbol_type, scope)` | Insert a symbol into the current scope's table; hash key = djb2(`scope` + `id`) % `MAXIDS` |
| `ST_lookup(id)` | Search from `current_scope` upward through parent scopes; return the entry or `NULL` |
| `new_scope()` | Create a child `table_node` and set it as `current_scope` |
| `up_scope()` | Move `current_scope` back to its parent |
| `add_param(data_type, symbol_type)` | Append a parameter to the `working_list` linked list |
| `connect_params(index, num_params)` | Attach the completed parameter list to the function's symbol entry |

Symbol table entry fields:

| Field | Description |
|-------|-------------|
| `id` | Identifier name |
| `scope` | Enclosing function name, or empty string for globals |
| `data_type` | `INT_TYPE`, `CHAR_TYPE`, or `VOID_TYPE` |
| `symbol_type` | `SCALAR`, `ARRAY`, or `FUNCTION` |
| `size` | Number of elements (arrays) or number of parameters (functions) |
| `params` | Linked list of parameter types (functions only) |

### `parser.y` — Semantic Checks

Add the following checks to the grammar actions:

1. **Undeclared identifiers** — call `ST_lookup` on every variable/function use; emit an error if not found
2. **Multiply declared identifiers** — before `ST_insert`, check that the name does not already exist in the current scope
3. **Function call mismatch** — verify argument count and types match the function's signature
4. **Array indexing** — verify the variable is an array and the index is an integer within bounds
5. **Type mismatch in assignments** — verify left-hand and right-hand sides share the same type (for simple RHS expressions: variable, literal, or function call)

## Semantic Errors

| Error | Description |
|-------|-------------|
| Undeclared identifier | Variable or function used before declaration |
| Multiply declared identifier | Same name declared more than once in the same scope |
| Function call mismatch | Wrong number of arguments or wrong argument type |
| Array indexing error | Non-array variable indexed, or index is non-integer / out-of-bounds |
| Type mismatch | Left- and right-hand sides of an assignment have different types |

## Extra Credit: AST Minimization

As an optional extra credit extension, you may minimize the AST by removing or collapsing redundant nodes (e.g., pass-through productions with a single child). This is not a strict requirement and will not affect your base score.

## Grading Rubric

| Category | Points |
|----------|--------|
| Symbol Table (type, scope, function info) | 20 |
| Undeclared/Multiply Declared Variables | 10 |
| Undeclared/Multiply Declared Functions | 10 |
| Function Call Mismatch | 10 |
| Array Indexing | 10 |
| Type Mismatch | 10 |
| Compile & Run | 10 |
| Documentation | 10 |
| Writeup | 10 |
| **Total** | **100** |

## Writeup (`writeup.txt`)

Required sections:
1. Your name and course ID
2. Group members and their respective contributions
3. Two test examples (different from those provided) demonstrating correctness
4. Any extra build instructions if you deviate from the provided Makefile

## Submission

**Due: Friday April 17th at 11:59 P.M.**

The project may be done individually or as a group of two. Submit a zip archive to Canvas named:

```
Project3_<netID1>_<netID2>.zip
```

containing all source files with the original directory structure intact.

### Late Policy

| Late Amount | Penalty |
|-------------|---------|
| 1 day | 10% |
| 2 days | 30% |
| 3 days | 50% |
| > 3 days | 100% (no credit) |
