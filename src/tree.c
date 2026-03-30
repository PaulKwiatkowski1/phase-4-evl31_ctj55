#include<tree.h>
#include<strtab.h>
#include<stdio.h>
#include<stdlib.h>
#include<string.h>

/* string values for ast node types, makes tree output more readable */
char *nodeNames[33] = {"program", "declList", "decl", "varDecl", "typeSpecifier",
                       "funDecl", "formalDeclList", "formalDecl", "funBody",
                       "localDeclList", "statementList", "statement", "compoundStmt",
                       "assignStmt", "condStmt", "loopStmt", "returnStmt","expression",
                       "relop", "addExpr", "addop", "term", "mulop", "factor",
                       "funcCallExpr", "argList", "integer", "identifier", "var",
                       "arrayDecl", "char", "funcTypeName"};

char *typeNames[3] = {"int", "char", "void"};
char *ops[10] = {"+", "-", "*", "/", "<", "<=", "==", ">=", ">", "!="};

tree *maketree(int kind) {
      tree *this = (tree *) malloc(sizeof(struct treenode));
      this->nodeKind = kind;
      this->numChildren = 0;
      return this;
}

tree *maketreeWithVal(int kind, int val) {
      tree *this = (tree *) malloc(sizeof(struct treenode));
      this->nodeKind = kind;
      this->numChildren = 0;
      this->val = val;
      return this;
}

void addChild(tree *parent, tree *child) {
      if (parent->numChildren == MAXCHILDREN) {
          printf("Cannot add child to parent node\n");
          exit(1);
      }
      nextAvailChild(parent) = child;
      parent->numChildren++;
}

void printAst(tree *node, int nestLevel) {
      char* nodeName = nodeNames[node->nodeKind];
      if(strcmp(nodeName,"identifier") == 0){
          if(node->val == -1)
              printf("%s,%s\n", nodeName,"undeclared variable");
          else
              printf("%s,%s\n", nodeName,get_symbol_id(node->val));
      }
      else if(strcmp(nodeName,"integer") == 0){
          printf("%s,%d\n", nodeName,node->val);
      }
      else if(strcmp(nodeName,"char") == 0){
          printf("%s,%c\n", nodeName,node->val);
      }
      else if(strcmp(nodeName,"typeSpecifier") == 0){
          printf("%s,%s\n", nodeName,typeNames[node->val]);
      }
      else if(strcmp(nodeName,"relop") == 0 || strcmp(nodeName,"mulop") == 0 || strcmp(nodeName,"addop") == 0){
          printf("%s,%s\n", nodeName,ops[node->val]);
      }
      else{
          printf("%s\n", nodeName);
      }

      int i, j;

      for (i = 0; i < node->numChildren; i++)  {
          for (j = 0; j < nestLevel; j++)
              printf("    ");
          printAst(getChild(node, i), nestLevel + 1);
      }

}

void flattenList(tree *list, tree *subList){
    for(int i=0; i < subList->numChildren; i++){
        addChild(list,getChild(subList,i));
    }
}

