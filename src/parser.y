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


typedef struct treenode tree;
extern tree *ast;

/* nodeTypes refer to different types of internal and external nodes
  that can be part of the abstract syntax tree.
  */

/* NOTE: mC has two kinds of scopes for variables : local and global.
  Variables declared outside any function are considered globals,
    whereas variables (and parameters) declared inside a function foo
    are local to foo.
  You should update the scope variable whenever you are inside a production
    that matches function definition (funDecl production).
  The rationale is that you are entering that function, so all variables,
    arrays, and other functions should be within this scope.
  You should pass this variable whenever you are
    calling the ST_insert or ST_lookup functions.
  This variable should be updated to scope = ""
    to indicate global scope whenever funDecl finishes.
  Treat these hints as helpful directions only.
  You may implement all of the functions as you like
    and not adhere to my instructions.
  As long as the directory structure is correct and the file names are correct,
    we are okay with it.
  */
char* scope = "";
%}

/* the union describes the fields available in the yylval variable */
%union
{
    int value;
    struct treenode *node;
    char *strval;
}

/*Add token declarations below.
  The type <value> indicates that the associated token will be
    of a value type such as integer, float etc.,
    and <strval> indicates that the associated token will be of string type.
  */
/* Tokens with values (passed via yylval) */
%token <strval> ID STRCONST
%token <value> INTCONST CHARCONST
/* Keywords */
%token KWD_IF KWD_ELSE KWD_WHILE KWD_INT KWD_STRING KWD_CHAR KWD_RETURN KWD_VOID

/* Operators */
%token OPER_INC OPER_DEC OPER_ADD OPER_SUB OPER_MUL OPER_DIV OPER_MOD
%token OPER_LTE OPER_GTE OPER_EQ OPER_NEQ OPER_LT OPER_GT OPER_ASGN
%token OPER_AND OPER_OR OPER_NOT OPER_AT

/* Punctuation and Brackets */
%token LSQ_BRKT RSQ_BRKT LCRLY_BRKT RCRLY_BRKT LPAREN RPAREN COMMA SEMICLN

/* Error handling */
%token ERROR



%type <node> program declList decl varDecl typeSpecifier funDecl
%type <node> formalDeclList formalDecl funBody localDeclList
%type <node> statementList statement compoundStmt assignStmt
%type <node> condStmt loopStmt returnStmt expression relop
%type <node> addExpr addop term mulop factor funCallExpr argList var



%start program

%%



program         : declList 
                { $$ = maketree(PROGRAM); addChild($$, $1); ast = $$; }
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
                    int idx = ST_insert($2, scope, $1->val, ARRAY); 
                    addChild($$, maketreeWithVal(IDENTIFIER, idx));
                    addChild($$, maketreeWithVal(INTEGER, $4));
                }
                | typeSpecifier ID SEMICLN 
                { 
                    $$ = maketree(VARDECL); 
                    addChild($$, $1);
                    int idx = ST_insert($2, scope, $1->val, SCALAR); 
                    addChild($$, maketreeWithVal(IDENTIFIER, idx));
                }
                ;

typeSpecifier   : KWD_INT  { $$ = maketree(TYPESPEC); $$->val = INT_TYPE; }
                | KWD_CHAR { $$ = maketree(TYPESPEC); $$->val = CHAR_TYPE; }
                | KWD_VOID { $$ = maketree(TYPESPEC); $$->val = VOID_TYPE; }
                | KWD_STRING { $$ = maketree(TYPESPEC); $$->val = STRING_TYPE; }
                ;

funDecl         : typeSpecifier ID LPAREN 
                { 
                    ST_insert($2, "", $1->val, FUNCTION); 
                    scope = $2; 
                }
                formalDeclList RPAREN funBody 
                { 
          tree *funcTypeName = maketree(FUNCTYPENAME);
                    $$ = maketree(FUNDECL); 
          addChild(funcTypeName, $1);
          addChild(funcTypeName, maketreeWithVal(IDENTIFIER, ST_lookup($2, "")));
          addChild($$, funcTypeName);
                    addChild($$, $5); /* formalDeclList is now at $5 */
                    addChild($$, $7); /* funBody is now at $7 */
                    scope = ""; 
                }
                | typeSpecifier ID LPAREN 
                { 
                    ST_insert($2, "", $1->val, FUNCTION); 
                    scope = $2; 
                }
                RPAREN funBody 
                { 
                  tree *funcTypeName = maketree(FUNCTYPENAME);
                    $$ = maketree(FUNDECL); 
                  addChild(funcTypeName, $1);
                  addChild(funcTypeName, maketreeWithVal(IDENTIFIER, ST_lookup($2, "")));
                  addChild($$, funcTypeName);
                    addChild($$, $6); /* funBody is now at $6 */
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
                    int idx = ST_insert($2, scope, $1->val, SCALAR);
                    addChild($$, maketreeWithVal(IDENTIFIER, idx)); 
                }
                | typeSpecifier ID LSQ_BRKT RSQ_BRKT 
                { 
                    $$ = maketree(FORMALDECL); 
                    addChild($$, $1); 
                    int idx = ST_insert($2, scope, $1->val, ARRAY);
                    addChild($$, maketreeWithVal(IDENTIFIER, idx)); 
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
                { $$ = maketree(ASSIGNSTMT); addChild($$, $1); addChild($$, $3); }
                | expression SEMICLN 
                { $$ = maketree(ASSIGNSTMT); addChild($$, $1); }
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
                    int idx = ST_lookup($1, scope);
                    if (idx == -1) {
                        idx = ST_lookup($1, "");
                    }
                    
                    if (idx == -1) {
                        yywarning("undeclared variable"); 
                    }
                    addChild($$, maketreeWithVal(IDENTIFIER, idx)); 
                }
                | ID LSQ_BRKT addExpr RSQ_BRKT 
                { 
                    $$ = maketree(VAR); 
                    int idx = ST_lookup($1, scope);
                    if (idx == -1) idx = ST_lookup($1, "");
                    
                    if (idx == -1) {
                        yywarning("undeclared variable");
                    }
                    addChild($$, maketreeWithVal(IDENTIFIER, idx)); 
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

factor          : LPAREN expression RPAREN { $$ = maketree(FACTOR); addChild($$, $2); }
                | var           { $$ = maketree(FACTOR); addChild($$, $1); }
                | funCallExpr   { $$ = maketree(FACTOR); addChild($$, $1); }
                | INTCONST      { $$ = maketree(FACTOR); addChild($$, maketreeWithVal(INTEGER, $1)); }
                | CHARCONST     { $$ = maketree(FACTOR); addChild($$, maketreeWithVal(CHAR, $1)); }
                | STRCONST      { $$ = maketree(FACTOR); addChild($$, maketreeWithStrVal(STRING, $1)); }
                ;

funCallExpr     : ID LPAREN argList RPAREN 
        {
          int idx = ST_lookup($1, scope);
          if (idx == -1) {
            idx = ST_lookup($1, "");
          }
          if (idx == -1) {
            yywarning("undeclared variable");
          }
          $$ = maketree(FUNCCALLEXPR);
          addChild($$, maketreeWithVal(IDENTIFIER, idx));
          addChild($$, $3);
        }
                | ID LPAREN RPAREN 
        {
          int idx = ST_lookup($1, scope);
          if (idx == -1) {
            idx = ST_lookup($1, "");
          }
          if (idx == -1) {
            yywarning("undeclared variable");
          }
          $$ = maketree(FUNCCALLEXPR);
          addChild($$, maketreeWithVal(IDENTIFIER, idx));
        }
                ;

argList         : expression 
                { $$ = maketree(ARGLIST); addChild($$, $1); }
                | argList COMMA expression 
                { $$ = maketree(ARGLIST); addChild($$, $1); addChild($$, $3); }
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
