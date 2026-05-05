%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<../src/tree.h>
#include<../src/strtab.h>

extern int yylineno;
extern int yylex(void);

int yywarning(char *msg);
int yyerror(char *msg);

int pcount = 0;
extern tree *ast;

char* scope = "";
int in_call_args = 0;

static int get_actual_symbol_type(tree *node) {
    if (node == NULL) {
        return SCALAR;
    }

    if (node->nodeKind == VAR) {
        return node->val;
    }

    if (node->nodeKind == EXPRESSION || node->nodeKind == ADDEXPR || node->nodeKind == TERM || node->nodeKind == FACTOR) {
        if ((node->nodeKind == EXPRESSION || node->nodeKind == ADDEXPR || node->nodeKind == TERM) && node->numChildren == 3) {
            return SCALAR;
        }

        if (node->numChildren > 0) {
            return get_actual_symbol_type(node->children[0]);
        }
    }

    return SCALAR;
}

static int infer_expr_type(tree *node, int *ok) {
    int left_type;
    int right_type;

    if (node == NULL) {
        *ok = 0;
        return VOID_TYPE;
    }

    switch (node->nodeKind) {
        case INTEGER:
            return INT_TYPE;
        case CHAR:
            return CHAR_TYPE;
        case STRING:
            return STRING_TYPE;
        case VAR:
        case FUNCCALLEXPR:
            return node->type;
        case FACTOR:
            if (node->numChildren == 0) {
                *ok = 0;
                return VOID_TYPE;
            }
            return infer_expr_type(node->children[0], ok);
        case TERM:
        case ADDEXPR:
            if (node->numChildren == 1) {
                return infer_expr_type(node->children[0], ok);
            }
            left_type = infer_expr_type(node->children[0], ok);
            right_type = infer_expr_type(node->children[2], ok);
            if (!*ok || left_type != right_type || left_type == VOID_TYPE) {
                *ok = 0;
                return VOID_TYPE;
            }
            return left_type;
        case EXPRESSION:
            if (node->numChildren == 1) {
                return infer_expr_type(node->children[0], ok);
            }
            left_type = infer_expr_type(node->children[0], ok);
            right_type = infer_expr_type(node->children[2], ok);
            if (!*ok || left_type != right_type || left_type == VOID_TYPE) {
                *ok = 0;
            }
            return INT_TYPE;
        default:
            if (node->numChildren == 1) {
                return infer_expr_type(node->children[0], ok);
            }
            *ok = 0;
            return VOID_TYPE;
    }
}

static int count_args(tree *args) {
    if (args == NULL) {
        return 0;
    }

    if (args->nodeKind != ARGLIST) {
        return 0;
    }

    if (args->numChildren == 1) {
        return 1;
    }

    if (args->numChildren == 2) {
        return count_args(args->children[0]) + 1;
    }

    return 0;
}

static int validate_call_args(tree *args, param **expected_param) {
    int ok = 1;
    int actual_type;
    tree *actual;

    if (args == NULL) {
        return expected_param != NULL && *expected_param == NULL;
    }

    if (expected_param == NULL || *expected_param == NULL || args->nodeKind != ARGLIST) {
        return 0;
    }

    if (args->numChildren == 2 && !validate_call_args(args->children[0], expected_param)) {
        return 0;
    }

    actual = (args->numChildren == 1) ? args->children[0] : args->children[1];
    actual_type = infer_expr_type(actual, &ok);
    if (!ok || actual == NULL) {
        return 0;
    }

    if (actual_type != (*expected_param)->data_type) {
        return 0;
    }

    *expected_param = (*expected_param)->next;
    return 1;
}

static int eval_constant_int(tree *node, int *value) {
    if (node == NULL || value == NULL) {
        return 0;
    }

    if (node->nodeKind == INTEGER) {
        *value = node->val;
        return 1;
    }

    if (node->numChildren == 1) {
        return eval_constant_int(node->children[0], value);
    }

    if (node->numChildren == 3 && node->children[1] != NULL) {
        int left_value = 0;
        int right_value = 0;

        if (!eval_constant_int(node->children[0], &left_value) || !eval_constant_int(node->children[2], &right_value)) {
            return 0;
        }

        switch (node->children[1]->nodeKind) {
            case ADDOP:
                if (node->children[1]->val == ADD) {
                    *value = left_value + right_value;
                } else if (node->children[1]->val == SUB) {
                    *value = left_value - right_value;
                } else {
                    return 0;
                }
                return 1;
            case MULOP:
                if (node->children[1]->val == MUL) {
                    *value = left_value * right_value;
                } else if (node->children[1]->val == DIV) {
                    if (right_value == 0) {
                        return 0;
                    }
                    *value = left_value / right_value;
                } else {
                    return 0;
                }
                return 1;
            case EXPRESSION:
            case ADDEXPR:
            case TERM:
                return eval_constant_int(node->children[0], value);
            default:
                return 0;
        }
    }

    return 0;
}
%}

%union
{
    int value;
    struct treenode *node;
    char *strval;
}

%token <strval> ID STRCONST
%token <value> INTCONST CHARCONST

%token KWD_IF KWD_ELSE KWD_WHILE KWD_INT KWD_STRING KWD_CHAR KWD_RETURN KWD_VOID
%token OPER_INC OPER_DEC OPER_ADD OPER_SUB OPER_MUL OPER_DIV OPER_MOD
%token OPER_LTE OPER_GTE OPER_EQ OPER_NEQ OPER_LT OPER_GT OPER_ASGN
%token OPER_AND OPER_OR OPER_NOT OPER_AT
%token LSQ_BRKT RSQ_BRKT LCRLY_BRKT RCRLY_BRKT LPAREN RPAREN COMMA SEMICLN
%token ERROR

%nonassoc IFX
%nonassoc KWD_ELSE

%type <node> program declList decl varDecl typeSpecifier funDecl
%type <node> formalDeclList formalDecl funBody localDeclList
%type <node> statementList statement compoundStmt assignStmt
%type <node> condStmt loopStmt returnStmt expression relop
%type <node> addExpr addop term mulop factor funCallExpr argList var

%start program

%%

program         : { new_scope("global"); } declList 
                { 
                    $$ = maketree(PROGRAM); 
                    addChild($$, $2); // Use $2 because the action is now $1
                    ast = $$; 
                }
                ;

declList        : decl 
                { $$ = maketree(DECLLIST); addChild($$, $1); }
                | declList decl 
                { $$ = maketree(DECLLIST); addChild($$, $1); addChild($$, $2); }
                ;

decl            : varDecl 
                { $$ = maketree(DECL); addChild($$, $1); }
                | funDecl 
                { $$ = maketree(DECL); addChild($$, $1); }
                ;

varDecl         : typeSpecifier ID LSQ_BRKT INTCONST RSQ_BRKT SEMICLN 
                { 
                    $$ = maketree(VARDECL); 
                    addChild($$, $1); 
                    
                    if (ST_insert($2, $1->val, ARRAY, current_scope->scope_name) == 0) {
                        yyerror("Symbol declared multiple times.");
                    } else {
                        symEntry *entry = ST_lookup($2);
                        if (entry != NULL) {
                            entry->size = $4;
                        }
                    }

                    if ($4 == 0) {
                        yyerror("Array variable declared with size of zero.");
                    }
                    
                    addChild($$, maketreeWithVal(IDENTIFIER, 0));
                    addChild($$, maketreeWithVal(INTEGER, $4));
                }
                | typeSpecifier ID SEMICLN 
                { 
                    $$ = maketree(VARDECL); 
                    addChild($$, $1);
                    
                    if (ST_insert($2, $1->val, SCALAR, current_scope->scope_name) == 0) {
                        yyerror("Symbol declared multiple times.");
                    }
                    
                    addChild($$, maketreeWithVal(IDENTIFIER, 0));
                }
                ;

typeSpecifier   : KWD_INT  { $$ = maketree(TYPESPEC); $$->val = INT_TYPE; }
                | KWD_CHAR { $$ = maketree(TYPESPEC); $$->val = CHAR_TYPE; }
                | KWD_VOID { $$ = maketree(TYPESPEC); $$->val = VOID_TYPE; }
                | KWD_STRING { $$ = maketree(TYPESPEC); $$->val = STRING_TYPE; } /* Optional if part of your mC version */
                ;

funDecl         : typeSpecifier ID LPAREN 
                { 
                    if (ST_insert($2, $1->val, FUNCTION, "global") == 0) {
                        yyerror("Symbol declared multiple times.");
                    }
                    scope = $2; 
                    new_scope(scope);
                    pcount = 0; 
                }
                formalDeclList RPAREN funBody 
                { 
                    tree *funcTypeName = maketree(FUNCTYPENAME);
                    $$ = maketree(FUNDECL); 
                    addChild(funcTypeName, $1);
                    addChild(funcTypeName, maketreeWithVal(IDENTIFIER, 0));
                    addChild($$, funcTypeName);
                    addChild($$, $5); 
                    addChild($$, $7); 
                    
                    connect_params($2, pcount); 
                    up_scope(); 
                    scope = ""; 
                }
                | typeSpecifier ID LPAREN 
                { 
                    if (ST_insert($2, $1->val, FUNCTION, "global") == 0) {
                        yyerror("Symbol declared multiple times.");
                    }
                    scope = $2; 
                    new_scope(scope);
                    pcount = 0;
                }
                RPAREN funBody 
                { 
                  tree *funcTypeName = maketree(FUNCTYPENAME);
                    $$ = maketree(FUNDECL); 
                  addChild(funcTypeName, $1);
                  addChild(funcTypeName, maketreeWithVal(IDENTIFIER, 0));
                  addChild($$, funcTypeName);
                    addChild($$, $6); 
                    
                    connect_params($2, pcount);
                    up_scope(); 
                    scope = ""; 
                }
                ;

formalDeclList  : formalDecl 
                { $$ = maketree(FORMALDECLLIST); addChild($$, $1); }
                | formalDecl COMMA formalDeclList 
                { $$ = maketree(FORMALDECLLIST); addChild($$, $1); addChild($$, $3); }
                ;

formalDecl      : typeSpecifier ID 
                { 
                    $$ = maketree(FORMALDECL); 
                    addChild($$, $1); 
                    
                    if (ST_insert($2, $1->val, SCALAR, current_scope->scope_name) == 0) {
                        yyerror("Symbol declared multiple times.");
                    }
                    add_param($1->val, SCALAR);
                    pcount++;
                    addChild($$, maketreeWithVal(IDENTIFIER, 0)); 
                }
                | typeSpecifier ID LSQ_BRKT RSQ_BRKT 
                { 
                    $$ = maketree(FORMALDECL); 
                    addChild($$, $1); 
                    
                    if (ST_insert($2, $1->val, ARRAY, current_scope->scope_name) == 0) {
                        yyerror("Symbol declared multiple times.");
                    }
                    pcount++;
                    add_param($1->val, ARRAY);
                    addChild($$, maketreeWithVal(IDENTIFIER, 0)); 
                    addChild($$, maketree(ARRAYDECL));
                }
                ;

funBody         : LCRLY_BRKT localDeclList statementList RCRLY_BRKT 
                { $$ = maketree(FUNBODY); addChild($$, $2); addChild($$, $3); }
                ;

localDeclList   : /* empty */ 
                { $$ = NULL; }
                | varDecl localDeclList 
                { $$ = maketree(LOCALDECLLIST); addChild($$, $1); addChild($$, $2); }
                ;

statementList   : /* empty */ 
                { $$ = NULL; }
                | statement statementList 
                { $$ = maketree(STATEMENTLIST); addChild($$, $1); addChild($$, $2); }
                ;

statement       : compoundStmt { $$ = maketree(STATEMENT); addChild($$, $1); }
                | assignStmt   { $$ = maketree(STATEMENT); addChild($$, $1); }
                | condStmt     { $$ = maketree(STATEMENT); addChild($$, $1); }
                | loopStmt     { $$ = maketree(STATEMENT); addChild($$, $1); }
                | returnStmt   { $$ = maketree(STATEMENT); addChild($$, $1); }
                ;

compoundStmt    : LCRLY_BRKT statementList RCRLY_BRKT 
                { $$ = maketree(COMPOUNDSTMT); addChild($$, $2); }
                ;

assignStmt      : var OPER_ASGN expression SEMICLN 
                { 
                    int lhs_ok = 1;
                    int rhs_ok = 1;
                    int lhs_type;
                    int rhs_type;

                    $$ = maketree(ASSIGNSTMT); 
                    addChild($$, $1); 
                    addChild($$, $3); 

                    lhs_type = infer_expr_type($1, &lhs_ok);
                    rhs_type = infer_expr_type($3, &rhs_ok);

                    if (!lhs_ok || !rhs_ok || lhs_type != rhs_type) {
                        yyerror("Type mismatch in assignment.");
                    }
                }
                | expression SEMICLN 
                { 
                    $$ = maketree(ASSIGNSTMT); 
                    addChild($$, $1); 
                }
                ;

condStmt        : KWD_IF LPAREN expression RPAREN statement 
                %prec IFX
                { $$ = maketree(CONDSTMT); addChild($$, $3); addChild($$, $5); }
                | KWD_IF LPAREN expression RPAREN statement KWD_ELSE statement 
                { $$ = maketree(CONDSTMT); addChild($$, $3); addChild($$, $5); addChild($$, $7); }
                ;

loopStmt        : KWD_WHILE LPAREN expression RPAREN statement 
                { $$ = maketree(LOOPSTMT); addChild($$, $3); addChild($$, $5); }
                ;

returnStmt      : KWD_RETURN SEMICLN 
                { $$ = maketree(RETURNSTMT); }
                | KWD_RETURN expression SEMICLN 
                { $$ = maketree(RETURNSTMT); addChild($$, $2); }
                ;

var             : ID 
                { 
                    $$ = maketree(VAR); 
                    symEntry* entry = ST_lookup($1);
                    if (entry == NULL) {
                        if (!in_call_args) {
                            yyerror("Undeclared variable");
                        }
                    } else {
                        $$->type = entry->data_type;
                        $$->val = entry->symbol_type;
                        $$->offset = entry->offset;
                    }
                    addChild($$, maketreeWithStrVal(IDENTIFIER, $1)); 
                }
                | ID LSQ_BRKT addExpr RSQ_BRKT 
                { 
                    int index_ok = 1;
                    int index_type;
                    int index_value = 0;

                    $$ = maketree(VAR); 
                    symEntry* entry = ST_lookup($1);
                    if (entry == NULL) {
                        if (!in_call_args) {
                            yyerror("Undeclared variable");
                        }
                    } else if (entry->symbol_type != ARRAY) {
                        yyerror("Non-array identifier used as an array.");
                    } else {
                        $$->type = entry->data_type;
                        $$->val = SCALAR;
                        $$->offset = entry->offset;
                    }
                    
                    index_type = infer_expr_type($3, &index_ok);
                    if (!index_ok || index_type != INT_TYPE) {
                        yyerror("Array indexed using non-integer expression.");
                    } else {
                        if (entry != NULL && entry->symbol_type == ARRAY && eval_constant_int($3, &index_value) && index_value >= entry->size) {
                            yyerror("Statically sized array indexed with constant, out-of-bounds expression.");
                        }
                    }
                    
                    addChild($$, maketreeWithStrVal(IDENTIFIER, $1)); 
                    addChild($$, $3); 
                }
                ;

expression      : addExpr 
                { $$ = maketree(EXPRESSION); addChild($$, $1); }
                | expression relop addExpr 
                { $$ = maketree(EXPRESSION); addChild($$, $1); addChild($$, $2); addChild($$, $3); }
                ;

relop           : OPER_LTE { $$ = maketree(RELOP); $$->val = LTE; }
                | OPER_LT  { $$ = maketree(RELOP); $$->val = LT; }
                | OPER_GT  { $$ = maketree(RELOP); $$->val = GT; }
                | OPER_GTE { $$ = maketree(RELOP); $$->val = GTE; }
                | OPER_EQ  { $$ = maketree(RELOP); $$->val = EQ; }
                | OPER_NEQ { $$ = maketree(RELOP); $$->val = NEQ; }
                ;

addExpr         : term 
                { $$ = maketree(ADDEXPR); addChild($$, $1); }
                | addExpr addop term 
                { $$ = maketree(ADDEXPR); addChild($$, $1); addChild($$, $2); addChild($$, $3); }
                ;

addop           : OPER_ADD { $$ = maketree(ADDOP); $$->val = ADD; }
                | OPER_SUB { $$ = maketree(ADDOP); $$->val = SUB; }
                ;

term            : factor 
                { $$ = maketree(TERM); addChild($$, $1); }
                | term mulop factor 
                { $$ = maketree(TERM); addChild($$, $1); addChild($$, $2); addChild($$, $3); }
                ;

mulop           : OPER_MUL { $$ = maketree(MULOP); $$->val = MUL; }
                | OPER_DIV { $$ = maketree(MULOP); $$->val = DIV; }
                ;

factor          : INTCONST      
                { 
                    $$ = maketreeWithVal(INTEGER, $1); 
                    $$->type = INT_TYPE; 
                }
                | CHARCONST     
                { 
                    $$ = maketreeWithVal(CHAR, $1); 
                    $$->type = CHAR_TYPE; 
                }
                | STRCONST      
                { 
                    $$ = maketreeWithStrVal(STRING, $1); 
                    $$->type = STRING_TYPE; 
                }
                | var { $$ = $1; } 
                | funCallExpr   
                { 
                    $$ = maketree(FACTOR); 
                    addChild($$, $1); 
                    $$->type = $1->type;
                }
                | LPAREN expression RPAREN 
                { 
                    $$ = maketree(FACTOR); 
                    addChild($$, $2); 
                    $$->type = $2->type;
                }
                ;

funCallExpr     : ID LPAREN { in_call_args = 1; } argList RPAREN 
                {
                    int actual_count;
                    in_call_args = 0;
                    symEntry* entry = ST_lookup($1);
                    if (entry == NULL) {
                        yyerror("Undefined function");
                    } else if (entry->symbol_type != FUNCTION) {
                        yyerror("Called identifier is not a function.");
                    } else {
                        actual_count = count_args($4);
                        if (actual_count < entry->size) {
                            yyerror("Too few arguments provided in function call.");
                        } else if (actual_count > entry->size) {
                            yyerror("Too many arguments provided in function call.");
                        } else {
                        param *expected_params = entry->params;
                        if (!validate_call_args($4, &expected_params)) {
                            yyerror("Argument type mismatch in function call.");
                        }
                        }
                    }
                    
                    $$ = maketree(FUNCCALLEXPR);
                    if (entry != NULL) {
                      $$->type = entry->data_type;
                    } else {
                      $$->type = VOID_TYPE;
                    }
                    addChild($$, maketreeWithVal(IDENTIFIER, 0));
                    addChild($$, $4);
                }
                | ID LPAREN RPAREN 
                {
                    symEntry* entry = ST_lookup($1);
                    if (entry == NULL) {
                        yyerror("Undefined function");
                    } else if (entry->symbol_type != FUNCTION) {
                        yyerror("Called identifier is not a function.");
                    } else if (entry->size > 0) {
                        yyerror("Too few arguments provided in function call.");
                    }
                    
                    $$ = maketree(FUNCCALLEXPR);
                    if (entry != NULL) {
                      $$->type = entry->data_type;
                    } else {
                      $$->type = VOID_TYPE;
                    }
                    addChild($$, maketreeWithVal(IDENTIFIER, 0));
                }
                ;

argList         : expression 
                { 
                    $$ = maketree(ARGLIST); 
                    addChild($$, $1); 
                }
                | argList COMMA expression 
                { 
                    $$ = maketree(ARGLIST); 
                    addChild($$, $1); 
                    addChild($$, $3); 
                }
                ;

%%

int yywarning(char *msg){
  printf("warning: line %d: %s\n", yylineno, msg);
  return 0;
}

int yyerror(char * msg){
  printf("error: line %d: %s\n", yylineno, msg);
  return 0;
}