#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "strtab.h"

int current_sp_offset = 0;
param *working_list_head = NULL;
param *working_list_end = NULL;
table_node* current_scope = NULL;
// Define the global scope (current_scope, working_list_head, etc. are already in strtab.h)
table_node* global_scope = NULL;

char *dataTypeStr[] = {"int", "char", "void", "string"};
char *symbolTypeStr[] = {"scalar", "array", "function"};
symEntry* strTable[MAXIDS];

unsigned long get_hash(char* scope, char* id);

static const char *normalize_scope(const char *scope) {
    if (scope == NULL || strcmp(scope, "global") == 0) {
        return "";
    }

    return scope;
}

static symEntry* lookup_in_scope(table_node *node, char *id) {
    if (node == NULL || id == NULL) {
        return NULL;
    }

    unsigned long index = get_hash(node->scope_name, id);
    unsigned long start_index = index;

    while (node->strTable[index] != NULL) {
        if (strcmp(node->strTable[index]->id, id) == 0) {
            return node->strTable[index];
        }

        index = (index + 1) % MAXIDS;
        if (index == start_index) {
            break;
        }
    }

    return NULL;
}

unsigned long djb2(unsigned char *str) {
    unsigned long hash = 5381;
    int c;
    while ((c = *str++)) {
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */
    }
    return hash;
}

unsigned long get_hash(char* scope, char* id) {
    char key[512] = ""; 
    const char *normalized_scope = normalize_scope(scope);

    if (normalized_scope != NULL) {
        strcat(key, normalized_scope);
    }
    strcat(key, id);
    return djb2((unsigned char*)key) % MAXIDS;
}

int ST_insert(char* id, int data_type, int symbol_type, char* scope) {
    if (current_scope == NULL) return 0; 

    const char *normalized_scope = normalize_scope(scope);
    unsigned long index = get_hash((char *)normalized_scope, id);
    unsigned long start_index = index;
    
    while (current_scope->strTable[index] != NULL) {
        if (strcmp(current_scope->strTable[index]->id, id) == 0) {
            return 0; 
        }
        index = (index + 1) % MAXIDS;
        if (index == start_index) {
            return 0;
        }
    }
    
    symEntry* new_entry = (symEntry*)malloc(sizeof(symEntry));
    new_entry->id = strdup(id);
    new_entry->scope = strdup(normalized_scope);
    new_entry->data_type = data_type;
    new_entry->symbol_type = symbol_type;
    new_entry->size = 0;
    new_entry->params = NULL;
    new_entry->offset = current_sp_offset;
    current_sp_offset += 4;
    current_scope->strTable[index] = new_entry;
    return 1;
}

symEntry* ST_lookup(char* id) {
    table_node* node = current_scope;
    
    while (node != NULL) {
        symEntry *found = lookup_in_scope(node, id);
        if (found != NULL) {
            return found;
        }
        
        node = node->parent;
    }
    
    return NULL;
}

void add_param(int data_type, int symbol_type) {
    param* new_param = (param*)malloc(sizeof(param));
    new_param->data_type = data_type;
    new_param->symbol_type = symbol_type;
    new_param->next = NULL;

    if (working_list_head == NULL) {
        working_list_head = new_param;
        working_list_end = new_param;
    } else {
        working_list_end->next = new_param;
        working_list_end = new_param;
    }
}

void new_scope(char* scope_name) {
    current_sp_offset = 0;
    table_node* new_node = (table_node*)malloc(sizeof(table_node));
    new_node->scope_name = strdup(normalize_scope(scope_name));
    new_node->numChildren = 0;
    new_node->parent = current_scope;
    new_node->first_child = NULL;
    new_node->last_child = NULL;
    new_node->next = NULL;

    for (int i = 0; i < MAXIDS; i++) {
        new_node->strTable[i] = NULL;
    }

    if (current_scope != NULL) {
        current_scope->numChildren++;
        
        if (current_scope->first_child == NULL) {
            current_scope->first_child = new_node;
            current_scope->last_child = new_node;
        } else {
            current_scope->last_child->next = new_node;
            current_scope->last_child = new_node;
        }
    } else {
        global_scope = new_node;
    }
    current_scope = new_node;
}

void up_scope() {
    if (current_scope != NULL && current_scope->parent != NULL) {
        current_scope = current_scope->parent;
    }
}

void connect_params(char* id, int num_params) {
    symEntry* func_entry = lookup_in_scope(current_scope != NULL ? current_scope->parent : NULL, id);
    
    if (func_entry != NULL && func_entry->symbol_type == FUNCTION) {
        func_entry->params = working_list_head;
        func_entry->size = num_params;
    }
    
    working_list_head = NULL;
    working_list_end = NULL;
}

void print_sym_tab() {
    printf("\n--- Symbol Table ---\n");
}