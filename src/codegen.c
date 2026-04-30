#include <stdio.h>
#include <stdlib.h>
#include "tree.h"
#include "codegen.h"

// --- Simple Register Allocator ---
// We will use MIPS registers $t0 through $t9
static int current_reg = 0;

int get_reg() {
    if (current_reg > 9) {
        printf("  # ERROR: Out of registers!\n");
        return 9; // Fallback to avoid crashing, though spilling to memory is required for complex programs
    }
    return current_reg++;
}

void free_reg() {
    if (current_reg > 0) {
        current_reg--;
    }
}

// --- Traversal Declaration ---
int gen_node(tree *node);

// --- Main Code Gen Entry Point ---
void generate_code(tree *ast_root) {
    if (ast_root == NULL) return;

    // 1. Data Section
    printf(".data\n");
    printf("_nl: .asciiz \"\\n\"\n");
    
    // 2. Text Section (Boilerplate)
    printf("\n.text\n");
    printf(".globl main\n");

    // 3. Start AST Traversal
    gen_node(ast_root);

    // 4. Exit Program cleanly
    printf("\n  # Exit Program\n");
    printf("  li $v0, 10\n");
    printf("  syscall\n");
}

// --- Recursive AST Traversal ---
// Returns the register number where the result of this node is stored.
int gen_node(tree *node) {
    if (node == NULL) return -1;

    switch (node->nodeKind) {
        // --- Structural Nodes (Just pass through to children) ---
        case PROGRAM:
        case DECLLIST:
        case DECL:
        case STATEMENTLIST:
        case STATEMENT:
        case COMPOUNDSTMT:
        case EXPRESSION:
        case FACTOR:
        case TERM:
            for (int i = 0; i < node->numChildren; i++) {
                gen_node(node->children[i]);
            }
            return -1;

        // --- Functions ---
        case FUNDECL:
            // For now, let's just generate the label for the function name
            // The function name identifier is the 2nd child of the FUNCTYPENAME (which is the 1st child of FUNDECL)
            if (node->children[0] != NULL && node->children[0]->children[1] != NULL) {
                // In your tree, the actual string isn't always saved in the identifier node if it's in the symtab, 
                // but for 'main', we know we need a main label.
                printf("\nmain:\n"); 
            }
            
            // Traverse the function body (child 2)
            gen_node(node->children[2]); 
            return -1;

        // --- Leaf Nodes ---
        case INTEGER: {
            int reg = get_reg();
            printf("  li $t%d, %d\n", reg, node->val);
            return reg; // Tell the parent node which register holds this value
        }

        // --- Default (Catch-all for unimplemented nodes) ---
        default:
            for (int i = 0; i < node->numChildren; i++) {
                gen_node(node->children[i]);
            }
            return -1;
    }
}