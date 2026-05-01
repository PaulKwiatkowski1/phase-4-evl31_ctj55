#include <stdio.h>
#include <stdlib.h>
#include "tree.h"
#include "codegen.h"
#include "strtab.h"

static int current_reg = 0;

int get_reg() {
    if (current_reg > 9) {
        return 9; 
    }
    return current_reg++;
}

void free_reg() {
    if (current_reg > 0) {
        current_reg--;
    }
}

int gen_node(tree *node);

void generate_code(tree *ast_root) {
    if (ast_root == NULL) return;

    printf(".data\n");
    printf("_nl: .asciiz \"\\n\"\n");
    
    printf("\n.text\n");
    printf(".globl main\n");

    gen_node(ast_root);

    printf("\n");
    printf("  li $v0, 10\n");
    printf("  syscall\n");
}

int gen_node(tree *node) {
    if (node == NULL) return -1;

    switch (node->nodeKind) {
        case PROGRAM:
        case DECLLIST:
        case DECL:
        case STATEMENTLIST:
        case STATEMENT:
        case COMPOUNDSTMT:
            for (int i = 0; i < node->numChildren; i++) {
                gen_node(node->children[i]);
            }
            return -1;

        case EXPRESSION:
        case FACTOR:
            if (node->numChildren > 0) {
                return gen_node(node->children[0]);
            }
            return -1;

        case FUNDECL:
            if (node->children[0] != NULL && node->children[0]->children[1] != NULL) {
                printf("\nmain:\n"); 
            }
            
            for (int i = 0; i < node->numChildren; i++) {
                gen_node(node->children[i]);
            }
            return -1;

        case ASSIGNSTMT: {
            int right_reg = gen_node(node->children[1]);
            int var_offset = node->children[0]->offset;

            printf("  sw $t%d, %d($sp)\n", right_reg, var_offset);

            free_reg(); 
            return -1;
        }

        case VAR: {
            int var_offset = node->offset;
            int reg = get_reg();

            printf("  lw $t%d, %d($sp)\n", reg, var_offset);
            
            return reg;
        }

        case ADDEXPR: {
            if (node->numChildren == 1) {
                return gen_node(node->children[0]);
            }
            
            int left_reg = gen_node(node->children[0]);
            int right_reg = gen_node(node->children[2]);
            int op = node->children[1]->val; 

            if (op == ADD) {
                printf("  add $t%d, $t%d, $t%d\n", left_reg, left_reg, right_reg);
            } else if (op == SUB) {
                printf("  sub $t%d, $t%d, $t%d\n", left_reg, left_reg, right_reg);
            }

            free_reg(); 
            return left_reg; 
        }

        case TERM: {
            if (node->numChildren == 1) {
                return gen_node(node->children[0]);
            }
            
            int left_reg = gen_node(node->children[0]);
            int right_reg = gen_node(node->children[2]);
            int op = node->children[1]->val; 

            if (op == MUL) {
                printf("  mul $t%d, $t%d, $t%d\n", left_reg, left_reg, right_reg);
            } else if (op == DIV) {
                printf("  div $t%d, $t%d\n", left_reg, right_reg);
                printf("  mflo $t%d\n", left_reg); 
            }

            free_reg();
            return left_reg;
        }

        case INTEGER: {
            int reg = get_reg();
            printf("  li $t%d, %d\n", reg, node->val);
            return reg; 
        }

        default:
            for (int i = 0; i < node->numChildren; i++) {
                gen_node(node->children[i]);
            }
            return -1;
    }
}