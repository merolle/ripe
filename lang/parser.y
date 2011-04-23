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

// Options:
%defines "lang/parser.h" // Write out definitions of the terminal symbols
%output  "lang/parser.c" // Location of parser output file
%name-prefix "rc_" // Define the prefix for all symbols
%error-verbose  // Verbose errors

%{
  #include "lang/lang.h"

  Node* operator(Node* a, Node* op, Node* b)
  {
    node_add_child(op, a);
    node_add_child(op, b);
    return op;
  }
%}


%token   ID
%token   INT
%token   DOUBLE
%token   STRING
%token   CHARACTER
%token   SYMBOL
// These are actually never encountered in the grammar, but are used by the
// lexer:
%token   COMMENT
%token   WHITESPACE
%token   UNKNOWN
%token   ETC           // ...
// These are not really tokens but are generated by the lexer (based on
// indentation, etc.)
%token   SEP
%token   START
%token   END
%token   C_CODE
// Keywords are labeled with K_ prefix. All keywords should appear in lex_get2()
// in addition to here.
%token   K_NAMESPACE   "namespace"
%token   K_RETURN      "return"
%token   K_TRUE        "true"
%token   K_FALSE       "false"
%token   K_NIL         "nil"
%token   K_AND         "and"
%token   K_OR          "or"
%token   K_NOT         "not"
%token   K_BIT_AND     "bit_and"
%token   K_BIT_OR      "bit_or"
%token   K_BIT_XOR     "bit_xor"
%token   K_BIT_NOT     "bit_not"
%token   K_MODULO      "modulo"
%token   K_IF          "if"
%token   K_ELSE        "else"
%token   K_ELIF        "elif"
%token   K_WHILE       "while"
%token   K_BREAK       "break"
%token   K_CONTINUE    "continue"
%token   K_LOOP        "loop"
%token   K_SWITCH      "switch"
%token   K_CASE        "case"
%token   K_IS          "is"
%token   K_EOF         "eof"
%token   K_TRY         "try"
%token   K_CATCH       "catch"
%token   K_FINALLY     "finally"
%token   K_RAISE       "raise"
%token   K_FOR         "for"
%token   K_IN          "in"
%token   K_PASS        "pass"
%token   K_CLASS       "class"
%token   K_CONSTRUCTOR "constructor"
%token   K_VIRTUAL_GET "virtual_get"
%token   K_VIRTUAL_SET "virtual_set"
%token   K_GLOBAL      "global"
%token   K_VAR         "var"
%token   K_CONST       "const"
%token   K_ARROW       "=>"
// Operator-like
%token   OP_EQUAL     "=="
%token   OP_NOT_EQUAL "!="
%token   OP_LTE       "<="
%token   OP_GTE       ">="
%left    "or"
%left    "and"
%left    "is" "in"
%left    ':'
%left    '<' "<=" '>' ">="
%left    "==" "!="
%left    "bit_or" "bit_xor"
%left    "bit_and"
%left    '+' '-'
%left    '*' '/' "modulo"
%right   '^'
%left    '.' '['

%% ////////////////////////////////////////////////////////////// Grammar rules

program:   START top_decls END { rc_result = $2; };

// "top" declarations can appear at the top level.
top_decl:  C_CODE              { $$ = $1; };
top_decl:  const               { $$ = $1; };
top_decl:  func                { $$ = $1; };
top_decl:  class               { $$ = $1; };
top_decl:  namespace           { $$ = $1; };
top_decl:  global              { $$ = $1; };

top_decls: top_decls SEP top_decl
                               { $$ = $1;
                                 node_add_child($$, $3); };
top_decls: top_decl            { $$ = node_new(TOPLEVEL_LIST);
                                 node_add_child($$, $1); };

// "middle" declarations can appear within namespaces.
mid_decl:  const               { $$ = $1; };
mid_decl:  func                { $$ = $1; };
mid_decl:  class               { $$ = $1; };
mid_decl:  namespace           { $$ = $1; };

mid_decls: mid_decls SEP mid_decl
                               { $$ = $1;
                                 node_add_child($$, $3); };
mid_decls: mid_decl            { $$ = node_new(TOPLEVEL_LIST);
                                 node_add_child($$, $1); };

// "bottom" declarations can appear within classes
bot_decl:  tl_var              { $$ = $1; };
bot_decl:  C_CODE              { $$ = $1; };
bot_decl:  func                { $$ = $1; };

bot_decls: bot_decls SEP bot_decl
                               { $$ = $1;
                                 node_add_child($$, $3); };
bot_decls: bot_decl            { $$ = node_new(TOPLEVEL_LIST);
                                 node_add_child($$, $1); };

// mixed declarations

tl_var: ID optassign_plus      { $$ = node_new(TL_VAR);
                                 node_set_string($$, "annotation", $1->text);
                                 node_add_child($$, $2); };

global: "global" optassign_plus
                               { $$ = node_new(GLOBAL_VAR);
                                 node_add_child($$, $2); };

const: "const" optassign_plus  { $$ = node_new(CONST_VAR);
                                 node_add_child($$, $2); };

namespace: "namespace" ID START mid_decls END
                               { $$ = node_new(NAMESPACE);
                                 node_set_string($$, "name", $2->text);
                                 node_add_child($$, $4); };

class: "class" ID START bot_decls END
                               { $$ = node_new(CLASS);
                                 node_set_string($$, "name", $2->text);
                                 node_add_child($$, $4); };

func: ID '(' param_star ')' opt_annotation block
                               { $$ = node_new(FUNCTION);
                                 if ($5 != NULL)
                                   node_set_node($$, "annotation", $5);
                                 node_set_string($$, "name", $1->text);
                                 node_add_child($$, $3);
                                 node_add_child($$, $6); };

block:     START stmt_list END { $$ = $2; };

stmt_list: stmt_list SEP stmt  { $$ = $1;
                                 node_add_child($$, $3); };
stmt_list: stmt                { $$ = node_new(STMT_LIST);
                                 node_add_child($$, $1); };
stmt_list: /* empty */         { $$ = node_new(STMT_LIST); };

stmt:      "if" rvalue block   { $$ = node_new(STMT_IF);
                                 node_add_child($$, $2);
                                 node_add_child($$, $3); };
stmt:      "else" block        { $$ = node_new(STMT_ELSE);
                                 node_add_child($$, $2); };
stmt:      "elif" rvalue block { $$ = node_new(STMT_ELIF);
                                 node_add_child($$, $2);
                                 node_add_child($$, $3); };
stmt:      lvalue_plus '=' rvalue
                               { $$ = node_new(STMT_ASSIGN);
                                 node_add_child($$, $1);
                                 node_add_child($$, $3); };
stmt:      expr                { $$ = node_new(STMT_EXPR);
                                 node_add_child($$, $1); };
stmt:      "return" rvalue     { $$ = node_new(STMT_RETURN);
                                 node_add_child($$, $2); };
stmt:      "return"            { $$ = node_new(STMT_RETURN);
                                 node_add_child($$, node_new(K_NIL)); };
stmt:      "try" block         { $$ = $2;
                                 $$->type = STMT_TRY; };
stmt:      "catch" block       { $$ = $2;
                                 $$->type = STMT_CATCH_ALL; };
stmt:      "finally" block     { $$ = $2;
                                 $$->type = STMT_FINALLY; };
stmt:      "raise" expr        { $$ = node_new(STMT_RAISE);
                                 node_add_child($$, $2); };
stmt:      "while" rvalue block
                               { $$ = node_new(STMT_WHILE);
                                 node_add_child($$, $2);
                                 node_add_child($$, $3); };
stmt:      "loop" block        { $$ = node_new(STMT_LOOP);
                                 node_add_child($$, $2); };
stmt:      "for" lvalue_plus "in" expr block
                               { $$ = node_new(STMT_FOR);
                                 node_add_child($$, $2);
                                 node_add_child($$, $4);
                                 node_add_child($$, $5); };
stmt:      "switch" expr START case_list END
                               { $$ = node_new(STMT_SWITCH);
                                 node_add_child($$, $2);
                                 node_add_child($$, $4); };
stmt:      "break"             { $$ = node_new_inherit(STMT_BREAK, $1); };
stmt:      "continue"          { $$ = node_new_inherit(STMT_CONTINUE, $1); };
stmt:      "pass"              { $$ = node_new_inherit(STMT_PASS, $1); };

case:      "case" expr block   { $$ = node_new(CASE);
                                 node_add_child($$, $2);
                                 node_add_child($$, $3); };
case_list: case                { $$ = node_new(CASE_LIST);
                                 node_add_child($$, $1); };
case_list: case_list SEP case  { $$ = $1; node_add_child($$, $3); };

// 4 types of expressions:
//   those that are lvalues but are not rvalues l_expr
//   those that are both lvalues and rvalues    lr_expr
//   those that are only rvalues                r_expr
//   subset of r_expr are d_expr, expressions that are direct_values
expr:      l_expr              { $$ = $1; };
expr:      lr_expr             { $$ = $1; };
expr:      r_expr              { $$ = $1; };

lvalue:    l_expr              { $$ = $1; };
lvalue:    lr_expr             { $$ = $1; };

rvalue:    r_expr              { $$ = $1; };
rvalue:    lr_expr             { $$ = $1; };

l_expr:    type_like ID        { $$ = node_new(EXPR_TYPED_ID);
                                 node_set_string($$, "name", $2->text);
                                 node_set_node($$, "type", $1); };

lr_expr:   '@' ID              { $$ = node_new_inherit(EXPR_AT_VAR, $2);
                                 node_set_string($$, "name", $2->text); };
lr_expr:   type_like           { $$ = $1; };
lr_expr:   rvalue '[' rvalue_plus ']'
                               { $$ = node_new(EXPR_INDEX);
                                 node_add_child($$, $1);
                                 node_add_child($$, $3); };

type_like: ID                  { $$ = $1; };
type_like: rvalue '.' ID       { $$ = node_new(EXPR_FIELD);
                                 node_add_child($$, $1);
                                 node_set_string($$, "name", $3->text); };

r_expr:    rvalue '.' ID '(' rvalue_star ')'
                               { $$ = node_new(EXPR_FIELD_CALL);
                                 node_add_child($$, $1);
                                 node_set_string($$, "name", $3->text);
                                 node_add_child($$, $5); };
r_expr:    ID '(' rvalue_star ')'
                               { $$ = node_new(EXPR_ID_CALL);
                                 node_add_child($$, $1);
                                 node_add_child($$, $3); };
r_expr:    '[' rvalue_star ']' { $$ = node_new(EXPR_ARRAY);
                                 node_add_child($$, $2); };
r_expr:    '{' mapping_plus '}' { $$ = node_new(EXPR_MAP);
                                  node_add_child($$, $2); };
r_expr:    '(' rvalue ')'      { $$ = $2; };
r_expr:    rvalue '+' rvalue   { $$ = operator($1, $2, $3); };
r_expr:    rvalue '-' rvalue   { $$ = operator($1, $2, $3); };
r_expr:    rvalue '*' rvalue   { $$ = operator($1, $2, $3); };
r_expr:    rvalue '/' rvalue   { $$ = operator($1, $2, $3); };
r_expr:    rvalue '^' rvalue   { $$ = operator($1, $2, $3); };
r_expr:    rvalue "==" rvalue  { $$ = operator($1, $2, $3); };
r_expr:    rvalue "!=" rvalue  { $$ = operator($1, $2, $3); };
r_expr:    rvalue "and" rvalue { $$ = operator($1, $2, $3); };
r_expr:    rvalue "or" rvalue  { $$ = operator($1, $2, $3); };
r_expr:    rvalue "bit_and" rvalue
                               { $$ = operator($1, $2, $3); };
r_expr:    rvalue "bit_or" rvalue
                               { $$ = operator($1, $2, $3); };
r_expr:    rvalue "bit_xor" rvalue
                               { $$ = operator($1, $2, $3); };
r_expr:    rvalue "modulo" rvalue
                               { $$ = operator($1, $2, $3); };
r_expr:    rvalue '<' rvalue   { $$ = operator($1, $2, $3); };
r_expr:    rvalue "<=" rvalue  { $$ = operator($1, $2, $3); };
r_expr:    rvalue '>' rvalue   { $$ = operator($1, $2, $3); };
r_expr:    rvalue ">=" rvalue  { $$ = operator($1, $2, $3); };
r_expr:    rvalue "is" type    { $$ = node_new(EXPR_IS_TYPE);
                                 node_add_child($$, $1);
                                 node_add_child($$, $3); };
r_expr:    rvalue "in" rvalue  { $$ = operator($1, $2, $3); };
r_expr:    rvalue ':' rvalue   { $$ = node_new(EXPR_RANGE_BOUNDED);
                                 node_add_child($$, $1);
                                 node_add_child($$, $3); };
r_expr:    rvalue ':'          { $$ = node_new(EXPR_RANGE_BOUNDED_LEFT);
                                 node_add_child($$, $1); };
r_expr:    ':' rvalue          { $$ = node_new(EXPR_RANGE_BOUNDED_RIGHT);
                                 node_add_child($$, $2); };
r_expr:    ':'                 { $$ = node_new(EXPR_RANGE_UNBOUNDED); };
r_expr:    '-' rvalue %prec '*'
                               { $$ = $1; node_add_child($$, $2); };
r_expr:    "not" rvalue %prec "and"
                               { $$ = $1; node_add_child($$, $2); };
r_expr:    "bit_not" rvalue %prec "bit_and"
                               { $$ = $1; node_add_child($$, $2); };
r_expr:    d_expr              { $$ = $1; };

d_expr:    C_CODE              { $$ = $1; };
d_expr:    INT                 { $$ = $1; };
d_expr:    DOUBLE              { $$ = $1; };
d_expr:    string              { $$ = $1; };
d_expr:    CHARACTER           { $$ = $1; };
d_expr:    "nil"               { $$ = $1; };
d_expr:    "true"              { $$ = $1; };
d_expr:    "false"             { $$ = $1; };
d_expr:    "eof"               { $$ = $1; };
d_expr:    SYMBOL              { $$ = $1; };

string:    STRING              { $$ = $1; };
string:    string STRING       { $$ = node_new(STRING);
                                 StringBuf sb_temp;
                                 sbuf_init(&sb_temp, $1->text);
                                 sbuf_cat(&sb_temp, $2->text);
                                 $$->text = mem_strdup(sb_temp.str);
                                 sbuf_deinit(&sb_temp); };

opt_annotation: '|' annot_plus { $$ = $2; };
opt_annotation: /* empty */    { $$ = NULL; };
annot_plus:   annot_plus ',' annot
                               { $$ = $1;
                                 node_add_child($$, $3); };
annot_plus:   annot            { $$ = node_new(ANNOT_LIST);
                                 node_add_child($$, $1); };
annot:     ID                  { $$ = node_new(ANNOT);
                                 node_add_child($$, $1); };
annot:     ID '=' type         { $$ = node_new(ANNOT);
                                 node_add_child($$, $1);
                                 node_add_child($$, $3); };

type:      type '.' ID         { $$ = node_new(EXPR_FIELD);
                                 node_add_child($$, $1);
                                 node_set_string($$, "name", $3->text); };
type:      ID                  { $$ = $1; };

mapping_plus: mapping_plus ',' mapping
                               { $$ = $1;
                                 node_add_child($$, $3); };
mapping_plus: mapping          { $$ = node_new(MAPPING_LIST);
                                 node_add_child($$, $1); };

mapping:     rvalue            { $$ = node_new(MAPPING);
                                 node_add_child($$, $1); };
mapping:     rvalue "=>" rvalue
                               { $$ = node_new(MAPPING);
                                 node_add_child($$, $1);
                                 node_add_child($$, $3); };

rvalue_star: rvalue_star ',' rvalue
                               { $$ = $1;
                                 node_add_child($$, $3); };
rvalue_star: rvalue            { $$ = node_new(EXPR_LIST);
                                 node_add_child($$, $1); };
rvalue_star: /* empty */       { $$ = node_new(EXPR_LIST); };

rvalue_plus: rvalue_plus ',' rvalue
                               { $$ = $1;
                                 node_add_child($$, $3); };
rvalue_plus: rvalue            { $$ = node_new(EXPR_LIST);
                                 node_add_child($$, $1); };

lvalue_plus: lvalue_plus ',' lvalue
                               { $$ = $1;
                                 node_add_child($$, $3); };
lvalue_plus: lvalue            { $$ = node_new(EXPR_LIST);
                                 node_add_child($$, $1); };

assign_plus: assign_plus ',' assign
                               { $$ = $1;
                                 node_add_child($$, $3); };
assign_plus: assign            { $$ = node_new(ASSIGN_LIST);
                                 node_add_child($$, $1); };

assign: ID '=' r_expr          { $$ = node_new_inherit(ASSIGN, $1);
                                 node_set_string($$, "name", $1->text);
                                 node_set_node($$, "value", $3); };

optassign_plus: optassign_plus ',' optassign
                               { $$ = $1;
                                 node_add_child($$, $3); };
optassign_plus: optassign      { $$ = node_new(OPTASSIGN_LIST);
                                 node_add_child($$, $1); };

optassign: ID                  { $$ = node_new_inherit(OPTASSIGN, $1);
                                 node_set_string($$, "name", $1->text);
                                 node_add_child($$, node_new(K_NIL)); };
optassign: ID '=' r_expr       { $$ = node_new_inherit(OPTASSIGN, $1);
                                 node_set_string($$, "name", $1->text);
                                 node_add_child($$, $3); };
optassign: type ID '=' r_expr  { $$ = node_new_inherit(OPTASSIGN, $2);
                                 node_set_string($$, "name", $2->text);
                                 node_set_node($$, "type", $1);
                                 node_add_child($$, $4); };

param:     '*' ID              { $$ = node_new(PARAM);
                                 node_set_string($$, "array", "array");
                                 node_set_string($$, "name", $2->text); };
param:     type ID             { $$ = node_new(PARAM);
                                 node_set_node($$, "type", $1);
                                 node_set_string($$, "name", $2->text); };
param:     ID                  { $$ = node_new(PARAM);
                                 node_set_string($$, "name", $1->text); };

param_star: param_star ',' param
                               { $$ = $1;
                                 node_add_child($$, $3); };
param_star: param              { $$ = node_new(PARAM_LIST);
                                 node_add_child($$, $1); };
param_star: /* empty */        { $$ = node_new(PARAM_LIST); };
