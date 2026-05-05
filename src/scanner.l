%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "y.tab.h"
int scancol = 1;
int yycol = 1;
int scanlineno = 1;
int yyerror(char *msg);
void updateCol();
void countLines();
int processString();
%}
%option noyywrap
%option yylineno
newline         \n
whitespace      [ \t\r]+
integer         [1-9][0-9]*|0
character       '[^'\n']'
string          \"([^"\n\\]|\\.)*\"
untermstring    \"([^\"\n\\]|\\.)*\n|\"([^\"\n\\]|\\.)*
comment         "/*"([^*]|\*+[^*/])*\*+"/"
untermcomment   "/*"([^*]|\*+[^*/])*
identifier      [a-zA-Z][a-zA-Z0-9]*
illidentifier   [0-9]+[a-zA-Z][a-zA-Z0-9]*
%%
"if"            { updateCol(); return KWD_IF; }
"else"          { updateCol(); return KWD_ELSE; }
"while"         { updateCol(); return KWD_WHILE; }
"int"           { updateCol(); return KWD_INT; }
"string"        { updateCol(); return KWD_STRING; }
"char"          { updateCol(); return KWD_CHAR; }
"return"        { updateCol(); return KWD_RETURN; }
"void"          { updateCol(); return KWD_VOID; }
"++"            { updateCol(); return OPER_INC; }
"--"            { updateCol(); return OPER_DEC; }
"+"             { updateCol(); return OPER_ADD; }
"-"             { updateCol(); return OPER_SUB; }
"*"             { updateCol(); return OPER_MUL; }
"/"             { updateCol(); return OPER_DIV; }
"%"             { updateCol(); return OPER_MOD; }
"<="            { updateCol(); return OPER_LTE; }
">="            { updateCol(); return OPER_GTE; }
"=="            { updateCol(); return OPER_EQ; }
"!="            { updateCol(); return OPER_NEQ; }
"<"             { updateCol(); return OPER_LT; }
">"             { updateCol(); return OPER_GT; }
"="             { updateCol(); return OPER_ASGN; }
"&&"            { updateCol(); return OPER_AND; }
"||"            { updateCol(); return OPER_OR; }
"!"             { updateCol(); return OPER_NOT; }
"@"             { updateCol(); return OPER_AT; }
"["             { updateCol(); return LSQ_BRKT; }
"]"             { updateCol(); return RSQ_BRKT; }
"{"             { updateCol(); return LCRLY_BRKT; }
"}"             { updateCol(); return RCRLY_BRKT; }
"("             { updateCol(); return LPAREN; }
")"             { updateCol(); return RPAREN; }
","             { updateCol(); return COMMA; }
";"             { updateCol(); return SEMICLN; }
{identifier}    { updateCol(); yylval.strval = strdup(yytext); return ID; }
{illidentifier} { updateCol(); yyerror("Illegal token"); yylval.strval = strdup(yytext); return ERROR; }
{integer}       { updateCol(); yylval.value = atoi(yytext); return INTCONST; }
{character}     { updateCol(); yylval.value = yytext[1]; return CHARCONST; }
{string}        { updateCol(); return processString(); }
{untermstring}  { updateCol(); yyerror("Unterminated string constant"); yylval.strval = strdup(yytext); return ERROR; }
{comment}       { updateCol(); }
{untermcomment} { yycol = scancol; yyerror("Unterminated comment"); return ERROR; }
{newline}       { countLines(); }
{whitespace}    { updateCol(); }
.               { return ERROR; }
%%
void updateCol(){
    yycol = scancol;
    scancol += yyleng;
}
void countLines(){
    scancol = 1;
    yycol = 1;
}
int processString(){
    static char buf[4096];
    int i, j;
    int len = yyleng - 2;
    char *src = yytext + 1;
    int had_error = 0;
    int original_col = yycol; 
    j = 0;
    for (i = 0; i < len; i++) {
        if (src[i] == '\\') {
            i++;
            if (src[i] == 'n') {
                buf[j++] = '\n';
            } else if (src[i] == 't') {
                buf[j++] = '\t';
            } else if (src[i] == '"') {
                buf[j++] = '"';
            } else if (src[i] == '\\') {
                buf[j++] = '\\';
            } else {
                if (!had_error) yycol = original_col + i; 
                yyerror("Unrecognized escape character in String");
                had_error = 1;
                buf[j++] = src[i];
            }
        } else {
            buf[j++] = src[i];
        }
    }
    buf[j] = '\0';
    yycol = original_col; 
    if (had_error) {
        yylval.strval = strdup(yytext); 
        return ERROR;
    }
    yylval.strval = strdup(buf);
    return STRCONST;
}
