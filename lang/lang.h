// Copyright (C) 2008  Maksim Sipos <msipos@mailc.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#ifndef LANG_H
#define LANG_H

#include "clib/clib.h"

//////////////////////////////////////////////////////////////////////////////
// lang/astnode.c
//////////////////////////////////////////////////////////////////////////////

typedef struct {
  int type;              // Node type.
  Array children;        // Array of Node*.
  Dict props_strings;    // String properties.
  Dict props_nodes;      // Node properties.
  // For token nodes:
  const char* text;      // Text of the token.
  const char* filename;  // Filename.
  int line;              // Line number
} Node;

// Create a token node. Does not duplicate text or filename strings.
Node* node_new_token(int type, const char* text, const char* filename, int line);
Node* node_new(int type);
Node* node_new_inherit(int type, Node* ancestor);

// Children
void  node_add_child(Node* parent, Node* child);
void node_prepend_child(Node* parent, Node* child);
int  node_num_children(Node* parent);
Node* node_get_child(Node* parent, uint i);
void node_extend_children(Node* new_parent, Node* old_parent);

// Properties
void node_set_string(Node* n, const char* key, const char* value);
char* node_get_string(Node* n, const char* key);
bool node_has_string(Node* n, const char* key);
void node_set_node(Node* n, const char* key, Node* value);
Node* node_get_node(Node* n, const char* key);
bool node_has_node(Node* n, const char* key);

void node_draw(Node* ast);

Node* node_new_id(const char* id);
Node* node_new_int(int64 i);
Node* node_new_expr_index1(Node* left, Node* index);
Node* node_new_expr_list(void);
Node* node_new_field_call(Node* callee, const char* field_name, int64 num, ...);
Node* node_new_type(const char* type);

//////////////////////////////////////////////////////////////////////////////
// lang/aster.c
//////////////////////////////////////////////////////////////////////////////
typedef enum {
  FUNCTION,
  METHOD,
  CONSTRUCTOR,
  VIRTUAL_GET,
  VIRTUAL_SET
} FunctionType;

typedef struct {
  // name is full function name
  void (*cb_function) (Node* n, const char* name);
  // name is method name, class_name is full class name
  void (*cb_method) (Node* n,
                     const char* name,
                     const char* class_name,
                     FunctionType type);
  void (*cb_constructor) (Node* n,
                          const char* name,
                          const char* class_name);
  // name is full class name
  void (*cb_class_enter) (Node* n, const char* name);
  void (*cb_class_exit) (Node* n, const char* name);
  // name is full variable name
  void (*cb_var) (Node* n, const char* name);
  void (*cb_property) (Node* n, const char* name, const char* class_name);
  // class_name may be NULL
  void (*cb_ccode) (Node* n, const char* class_name);
} Aster;

void aster_process(Node* ast, Aster* aster);
void aster_init(Aster* aster);

//////////////////////////////////////////////////////////////////////////////
// lang/input.c
//////////////////////////////////////////////////////////////////////////////
typedef struct {
  const char* filename;
  Array lines;
} RipeInput;
void input_from_file(RipeInput* input, const char* filename);
void input_from_string(RipeInput* input, const char* filename, const char* str);

//////////////////////////////////////////////////////////////////////////////
// lang/pp.c
//////////////////////////////////////////////////////////////////////////////

int preprocess(RipeInput* input);

//////////////////////////////////////////////////////////////////////////////
// lang/stran.c
//////////////////////////////////////////////////////////////////////////////

typedef enum {
  CLASS_VIRTUAL,
  CLASS_CDATA,
  CLASS_FIELD
} ClassType;

typedef struct {
  const char* c_name;
} GlobalInfo;

typedef struct {
  const char* ripe_name;
  const char* ret;
  int num_params;
  const char** param_types;
  const char** param_names;
  const char* c_name;
  const char* v_name;
  FunctionType type;
} FuncInfo;

#define PROP_FIELD 1
typedef struct {
  int type;
  int num;
} PropInfo;

typedef struct {
  const char* ripe_name;    // Ripe name of the class
  const char* c_name;       // Name of a variable of type Klass*.
  ClassType type;
  const char* typedef_name; // Only if type == CLASS_CDATA.
  
  Dict methods;             // Regardless of type.
  Dict vg_methods;          // Regardless of type.
  Dict vs_methods;          // Regardless of type.
  
  int num_props;            // Only if type == CLASS_FIELD.
  Dict props;               // Only if type == CLASS_FIELD.
  Dict gets;                // Regardless of type.
  Dict sets;                // Regardless of type.

  // These are populated by stran, and used by genist:
  const char* parent;
  Dict mixins;
  
  // Used by genist:
  #define GENIST_UNVISITED  0
  #define GENIST_VISITING   1
  #define GENIST_VISITED    2
  int genist_marker;        // Initialize to GENIST_UNVISITED
} ClassInfo;

void stran_init(void);
// Returns non-zero for error. (see stran_error.text)
void stran_absorb_ast(Node* ast, const char* filename);
void stran_absorb_file(const char* filename);

void stran_dump_to_file(FILE* f);

FuncInfo* stran_get_function(const char* name);
GlobalInfo* stran_query_global(const char* name);
GlobalInfo* stran_get_global(const char* name);
ClassInfo* stran_get_class(const char* name);
FuncInfo* stran_get_method(const char* class_name, const char* name);

void stran_add_function(const char* name, FuncInfo* fi);
void stran_add_class_method(const char* class_name, const char* name, 
                            FuncInfo* fi, FunctionType type);
void stran_add_class_property(const char* class_name, const char* name);

Dict* stran_get_classes(void); // Used by genist.

//////////////////////////////////////////////////////////////////////////////
// lang/proc.c
//////////////////////////////////////////////////////////////////////////////

void proc_process_ast(Node* ast, const char* filename);

//////////////////////////////////////////////////////////////////////////////
// lang/cache.c
//////////////////////////////////////////////////////////////////////////////

void cache_init(void);
void cache_prototype(const char* ripe_name);
const char* cache_dsym(const char* symbol);
const char* cache_type(const char* type);
void cache_global_prototype(const char* global);

//////////////////////////////////////////////////////////////////////////////
// lang/build-tree.c
//////////////////////////////////////////////////////////////////////////////

// Used by the scanner.l
void buf_reset(void);
void buf_cat(const char* text);

// Parse the given file.
typedef enum {
  PARSE_PROGRAM,     // Ast = program
  PARSE_EXPR,        // Ast = single expressions
  PARSE_PROCESSING   // Internally used by build-tree.c
} ParsingMode;
Node* build_tree(RipeInput* in, ParsingMode mode);

// Interface to bison & flex
#define YYSTYPE Node*
extern Node* rc_result;
void rc_error(const char*s);
int rc_parse(void);
int rc_lex(void);
int input_read(char* buf, int max_size); // Used by flex to do reading

// Types of AST nonterminal nodes:
#define TOPLEVEL_LIST     1000
#define NAMESPACE         1001
#define FUNCTION          1002
#define STMT_LIST         1003
#define CLASS             1004
#define PARAM             1006
#define TL_VAR            1008  // Top-level variable (with annotation maybe)
                                // Going to be deprecated
#define GLOBAL_VAR        1007
#define CONST_VAR         1009
#define TOP_VAR           1010

// Types of STMTs
#define STMT_EXPR         1100
#define STMT_RETURN       1101
#define STMT_IF           1102
#define STMT_ELIF         1103
#define STMT_ELSE         1104
#define STMT_PASS         1105
#define STMT_ASSIGN       1106
#define STMT_DESTROY      1107

#define STMT_BREAK        1111
#define STMT_CONTINUE     1112
#define STMT_FOR          1113
#define STMT_LOOP         1114
#define STMT_SWITCH       1115

#define STMT_TRY          1120
#define STMT_CATCH        1121
#define STMT_FINALLY      1122
#define STMT_RAISE        1123

// Types of EXPRs
#define EXPR_INDEX        1232
#define EXPR_ARRAY        1233
#define EXPR_MAP          1234
#define EXPR_FIELD        1235
#define EXPR_AT_VAR       1236
#define EXPR_RANGE_BOUNDED        1240
#define EXPR_RANGE_BOUNDED_LEFT   1241
#define EXPR_RANGE_BOUNDED_RIGHT  1242
#define EXPR_RANGE_UNBOUNDED      1243
#define EXPR_IS_TYPE      1244
#define EXPR_TYPED_ID     1245
#define EXPR_BLOCK        1246
#define EXPR_CALL         1247

// Helper nonterminal nodes
#define ID_LIST           1350
#define EXPR_LIST         1351
#define PARAM_LIST        1352
#define OPTASSIGN_LIST    1353
#define OPTASSIGN         1354
#define TYPE              1355
#define CASE_LIST         1356
#define CASE              1357
#define MAPPING_LIST      1358
#define MAPPING           1359
#define ANNOT_LIST        1360
#define ANNOT             1361

#include "lang/parser.h"
#include "lang/scanner.h"

//////////////////////////////////////////////////////////////////////////////
// lang/tree-morph.c
//////////////////////////////////////////////////////////////////////////////
void tree_morph(Node* ast);

//////////////////////////////////////////////////////////////////////////////
// lang/eval.c
//////////////////////////////////////////////////////////////////////////////

// Data structure representing an evaluated expression (with an associated type)
#define UNTYPED   ((const char*) 1)
typedef struct {
  const char* type;  // If UNTYPED, then unknown type.
  const char* text;  // Guaranteed non-NULL.
} EE;
EE* ee_new(const char* type, const char* text);
const char* ee_Value(EE* ee); // Evaluate ee as a Value.
const char* ee_type(const char* type, EE* ee); // Evaluate ee as a particular
                                               // type. May fatal_* out if
                                               // types not compatible.

// Evaluate an expression
EE* eval_expr(Node* expr);
static inline const char* eval_Value(Node* expr)
{
  return eval_expr(expr)->text;
}

const char* eval_type(Node* n);
const char* eval_index(Node* self, Node* idx, Node* assign);

//////////////////////////////////////////////////////////////////////////////
// lang/generator.c
//////////////////////////////////////////////////////////////////////////////

void genist_run(void);

//////////////////////////////////////////////////////////////////////////////
// lang/generator.c
//////////////////////////////////////////////////////////////////////////////

extern FuncInfo* context_fi;
extern ClassInfo* context_ci;
typedef struct {
  StringBuf sbuf_code;
  SArray closure_names;
  SArray closure_exprs;
  const char* func_name;
} BlockContext;
extern BlockContext* context_block;

// Uses fatal_* mechanism in case of error.
void fatal_node(Node* node, const char* format, ...);
const char* closure_add(const char* name, const char* evaluated);
const char* gen_block(Node* block) ATTR_WARN_UNUSED_RESULT;
void generate(Node* ast, const char* filename);

//////////////////////////////////////////////////////////////////////////////
// lang/operator.c
//////////////////////////////////////////////////////////////////////////////

bool is_unary_op(Node* node);
const char* unary_op_map(int type);

bool is_binary_op(Node* node);
const char* binary_op_map(int type);

//////////////////////////////////////////////////////////////////////////////
// lang/stacker.c
//////////////////////////////////////////////////////////////////////////////
#define STACKER_LOOP    1
#define STACKER_FOR     2
#define STACKER_TRY     3
#define STACKER_FINALLY 4
#define STACKER_CATCH   5

void stacker_init(void);
// Return a unique label.
const char* stacker_label(void);
void stacker_push(int type, const char* break_label, const char* continue_label);
const char* stacker_break(int num);
const char* stacker_continue(int num);
void stacker_pop(void);
int stacker_size(void);

//////////////////////////////////////////////////////////////////////////////
// lang/util.c
//////////////////////////////////////////////////////////////////////////////

const char* util_escape(const char* ripe_name);
const char* util_c_name(const char* ripe_name);
const char* util_dot_id(Node* expr);
const char* util_trim_ends(const char* input);
// In str, replace each character c by string replace
const char* util_replace(const char* str, const char c, const char* replace);
const char* util_node_type(int type);

// util_signature generates a string of the form:
//   "Value __Module_Function(Value, Value, Value)
const char* util_signature(const char* ripe_name);
bool annot_check_simple(Node* annot_list, int num, const char* args[]);
bool annot_check(Node* annot_list, int num, ...);
bool annot_has(Node* annot_list, const char* s);
const char* annot_get(Node* annot_list, const char* key);
const char* annot_get_full(Node* annot_list, const char* key, int num);
void lang_init(void);

//////////////////////////////////////////////////////////////////////////////
// lang/var.c
//////////////////////////////////////////////////////////////////////////////
void var_init(void);
void var_push(void);
void var_pop(void);
void var_add_local(const char* ripe_name, const char* c_name, const char* type);
void var_add_local2(const char* ripe_name, const char* c_name, 
                    const char* type, int kind);
bool var_query(const char* ripe_name);
const char* var_query_type(const char* ripe_name);
const char* var_query_c_name(const char* ripe_name);
int var_query_kind(const char* ripe_name);

#define VAR_REGULAR     1
#define VAR_BLOCK_PARAM 2

//////////////////////////////////////////////////////////////////////////////
// lang/writer.c
//////////////////////////////////////////////////////////////////////////////

#define WR_INIT1A  1
#define WR_INIT1B  2
#define WR_INIT2   3
#define WR_INIT3   4
#define WR_CODE    5
#define WR_HEADER  6

void wr_init(void);
void wr_print(int destination, const char* format, ...);
const char* wr_dump(const char* module_name);

#endif
