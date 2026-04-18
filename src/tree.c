#include "tree.h"
#include "strtab.h"
#include<stdio.h>
#include<stdlib.h>
#include<string.h>


const char *nodeKindStr[] = {
    "program", "declList", "decl", "varDecl", "typeSpecifier", "funDecl",
    "formalDeclList", "formalDecl", "funBody", "localDeclList",
    "statementList", "statement", "compoundStmt", "assignStmt",
    "condStmt", "loopStmt", "returnStmt", "expression", "relop",
    "addExpr", "addop", "term", "mulop", "factor", "funcCallExpr",
    "argList", "integer", "identifier", "var", "arrayDecl", "char", "string",
    "funcTypeName"
};

const char *opsStr[] = {"+", "-", "*", "/", "<", "<=", "==", ">=", ">", "!="};

typedef struct treenode tree;

tree *ast;
extern struct strEntry strTable[MAXIDS];

static int is_passthrough_node(int nodeKind) {
    switch (nodeKind) {
        case DECLLIST:
        case DECL:
        case LOCALDECLLIST:
        case STATEMENTLIST:
        case STATEMENT:
        case EXPRESSION:
        case ADDEXPR:
        case TERM:
        case FACTOR:
        case ARGLIST:
            return 1;
        default:
            return 0;
    }
}

tree *maketree(int kind) {
  tree *newNode = (tree *)malloc(sizeof(tree));
  newNode->nodeKind = kind;
  newNode->numChildren = 0;
  newNode->val = 0;
    newNode->strval = NULL;
  newNode->parent = NULL;
    newNode->type = VOID_TYPE;
  for(int i = 0; i < MAXCHILDREN; i++) {
      newNode->children[i] = NULL;
  }
  return newNode;
}

tree *maketreeWithVal(int kind, int val) {
  tree *newNode = maketree(kind);
  newNode->val = val;
  newNode->type = VOID_TYPE;
  return newNode;
}

tree *maketreeWithStrVal(int kind, char *strval) {
    tree *newNode = maketree(kind);
    newNode->strval = strdup(strval);
    newNode->type = VOID_TYPE;
    return newNode;
}

void addChild(tree *parent, tree *child) {
  if (parent == NULL || child == NULL) return;

  if (parent->numChildren < MAXCHILDREN) {
      parent->children[parent->numChildren] = child;
      child->parent = parent;
      parent->numChildren++;
  } else {
      printf("Error: Max children exceeded for node kind %d\n", parent->nodeKind);
  }
}

tree *minimizeAst(tree *root) {
    if (root == NULL) {
        return NULL;
    }

    for (int i = 0; i < root->numChildren; i++) {
        root->children[i] = minimizeAst(root->children[i]);
        if (root->children[i] != NULL) {
            root->children[i]->parent = root;
        }
    }

    if (is_passthrough_node(root->nodeKind) && root->numChildren == 1) {
        tree *child = root->children[0];
        if (child != NULL) {
            child->parent = root->parent;
        }
        return child;
    }

    return root;
}

void printAst(tree *root, int nestLevel) {
    if (!root) return;

    printf("%*s", nestLevel * 4, "");

    printf("%s", nodeKindStr[root->nodeKind]);

    if (root->nodeKind == INTEGER || root->nodeKind == CHAR) {
        printf(",%d", root->val);
    } else if (root->nodeKind == STRING) {
        printf(",%s", root->strval == NULL ? "" : root->strval);
    } else if (root->nodeKind == IDENTIFIER) {
        if (root->val >= 0 && root->val < MAXIDS && strTable[root->val].id != NULL) {
            printf(",%s", strTable[root->val].id);
        } else {
            printf(",%d", root->val);
        }
    } else if (root->nodeKind == TYPESPEC) {
        extern const char *dataTypeStr[4];
        printf(",%s", dataTypeStr[root->val]);
    } else if (root->nodeKind == RELOP || root->nodeKind == ADDOP || root->nodeKind == MULOP) {
        printf(",%s", opsStr[root->val]);
    }

    printf("\n");

    for (int i = 0; i < root->numChildren; i++) {
        printAst(root->children[i], nestLevel + 1);
    }
}
