#ifndef TREE_H
#define TREE_H

#define MAXCHILDREN 12

enum nodeTypes {
    PROGRAM, DECLLIST, DECL, VARDECL, TYPESPEC, FUNDECL,
    FORMALDECLLIST, FORMALDECL, FUNBODY, LOCALDECLLIST,
    STATEMENTLIST, STATEMENT, COMPOUNDSTMT, ASSIGNSTMT,
    CONDSTMT, LOOPSTMT, RETURNSTMT, EXPRESSION, RELOP,
    ADDEXPR, ADDOP, TERM, MULOP, FACTOR, FUNCCALLEXPR,
  ARGLIST, INTEGER, IDENTIFIER, VAR, ARRAYDECL, CHAR, STRING,
    FUNCTYPENAME
};

enum opType {ADD, SUB, MUL, DIV, LT, LTE, EQ, GTE, GT, NEQ};
/* tree node -
  you may need to add more fields or change this file however you see fit.
  */
struct treenode {
      int nodeKind;
      int numChildren;
      int val;
      char *strval;
      int type;
      struct treenode *parent;
      struct treenode *children[MAXCHILDREN];
};
typedef struct treenode tree;
extern tree *ast;

/* builds sub tree with zeor children  */
struct treenode *maketree(int kind);

/* builds sub tree with leaf node. Leaf nodes typically hold a value. */
struct treenode *maketreeWithVal(int kind, int val);

/* builds sub tree with leaf node that stores a string value. */
struct treenode *maketreeWithStrVal(int kind, char *strval);

/* assigns the subtree
    rooted at 'child' as a child of the subtree rooted at 'parent'.
  Also assigns the 'parent' node as the 'child->parent'.
  */
void addChild(struct treenode *parent, struct treenode *child);

/* prints the ast recursively starting from the root of the ast.
  This function prints
    the warning "undeclared variable"
    or <nodeKind, value> for identifiers and integers,
    or <nodeKind, type name> for typeSpecifiers,
    and <nodeName, the operator symbol> for relational and arithmetic operators.
  For more information,
    take a look at the example in the "Sample Output" section
    of the assignment instructions.
  */
void printAst(struct treenode *root, int nestLevel);

/* collapses pass-through wrapper nodes that only have a single child. */
struct treenode *minimizeAst(struct treenode *root);


#endif
