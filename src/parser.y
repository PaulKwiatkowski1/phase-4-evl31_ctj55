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
int argCount = 0;
typedef struct treenode tree;
extern tree *ast;

char* scope = "";
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
                        yyerror("Multiply declared identifier");
                    }
                    
                    addChild($$, maketreeWithVal(IDENTIFIER, 0));
                    addChild($$, maketreeWithVal(INTEGER, $4));
                }
                | typeSpecifier ID SEMICLN 
                { 
                    $$ = maketree(VARDECL); 
                    addChild($$, $1);
                    
                    if (ST_insert($2, $1->val, SCALAR, current_scope->scope_name) == 0) {
                        yyerror("Multiply declared identifier");
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
                        yyerror("Multiply declared identifier");
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
                        yyerror("Multiply declared identifier");
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
                        yyerror("Multiply declared identifier");
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
                        yyerror("Multiply declared identifier");
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
                    $$ = maketree(ASSIGNSTMT); 
                    addChild($$, $1); 
                    addChild($$, $3); 

                    if ($1->type != $3->type) {
                        yyerror("Type mismatch in assignment");
                    }
                }
                | expression SEMICLN 
                { 
                    $$ = maketree(ASSIGNSTMT); 
                    addChild($$, $1); 
                }
                ;

condStmt        : KWD_IF LPAREN expression RPAREN statement 
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
                    if (entry != NULL) {
                        $$->type = entry->data_type;
                    }
                    addChild($$, maketreeWithVal(IDENTIFIER, 0)); 
                }
                | ID LSQ_BRKT addExpr RSQ_BRKT 
                { 
                    $$ = maketree(VAR); 
                    symEntry* entry = ST_lookup($1);
                    if (entry != NULL) {
                        $$->type = entry->data_type;
                    }
                    
                    if ($3->type != INT_TYPE) {
                        yyerror("Array index must be an integer");
                    }
                    
                    addChild($$, maketreeWithVal(IDENTIFIER, 0)); 
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

funCallExpr     : ID LPAREN argList RPAREN 
                {
                    symEntry* entry = ST_lookup($1);
                    if (entry == NULL) {
                        yyerror("Undeclared function");
                    } else if (entry->symbol_type != FUNCTION) {
                        yyerror("Called identifier is not a function");
                    } else if (entry->size != argCount) {
                        // THIS IS THE NEW CHECK
                        yyerror("Number of arguments does not match function definition");
                    }
                    
                    $$ = maketree(FUNCCALLEXPR);
                    if (entry != NULL) {
                      $$->type = entry->data_type;
                    }
                    addChild($$, maketreeWithVal(IDENTIFIER, 0));
                    addChild($$, $3);
                }
                | ID LPAREN RPAREN 
                {
                    symEntry* entry = ST_lookup($1);
                    if (entry == NULL) {
                        yyerror("Undeclared function");
                    } else if (entry->symbol_type != FUNCTION) {
                        yyerror("Called identifier is not a function");
                    } else if (entry->size != 0) {
                        // Check for functions that expect parameters but got none
                        yyerror("Number of arguments does not match function definition");
                    }
                    
                    $$ = maketree(FUNCCALLEXPR);
                    if (entry != NULL) {
                      $$->type = entry->data_type;
                    }
                    addChild($$, maketreeWithVal(IDENTIFIER, 0));
                }
                ;

argList         : expression 
                { 
                    $$ = maketree(ARGLIST); 
                    addChild($$, $1); 
                    argCount = 1; // Start the count
                }
                | argList COMMA expression 
                { 
                    $$ = maketree(ARGLIST); 
                    addChild($$, $1); 
                    addChild($$, $3); 
                    argCount++; // Increment for each additional argument
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