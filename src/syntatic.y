%{
#include <iostream>
#include <string>
#include <sstream>
#include <map>
#include <fstream>
#include <vector>
#include <algorithm>
#include <functional>

#define YYSTYPE attributes

using namespace std;

/******* declarações *******/

typedef struct attributes {
	string label; // nome da variável usada no cód. intermediário (ex: "t0")
	string type; // tipo no código intermediário (ex: "int")
	int size; // tamanho da variável; usado somente com strings
	string transl; // código intermediário (ex: "int t11 = 1;")
} node;

typedef struct var_info {
	string type; // tipo da variável usada no cód. intermediário (ex: "int")
	string name; // nome da variável usada no cód. intermediário (ex: "t0")
	bool isMutable; // se variável é constante ou não
} var_info;

typedef struct loop_info {
	string start; // nome da label do início do bloco
	string increment; // nome da label do início do incremento
	string end; // nome da label do fim do bloco
} loop_info;

typedef function<node(string, node, node)> strategy;

string type1, type2, op, typeRes, strategyName, value;
ifstream opMapFile, padraoMapFile;

int tempGen = 0;
int tempLabel = 0;

// declarações de variáveis
vector<string> decls;

// desalocações de variáveis
vector<string> desacs;

// pilha de mapas de variável
vector<map<string, var_info>> varMap;

// pilha de labels de loops
vector<loop_info> loopMap;

// mapa de tipos
map<string, string> typeMap;

// tipo + op + tipo => tipo resultante
map<string, string> opMap;

// tipo + op + tipo => estratégia a utilizar
map<string, string> preStrategyMap;

// mapa de valores padrão de cada tipo
map<string, string> padraoMap;

// mapa de estratégias
map<string, strategy> strategyMap;

// obtém o próximo nome de variável disponível
string getNextVar();

// obtém o próximo nome de label disponível
string getNextLabel();

// inicia um novo contexto
void pushContext();

// destrói o contexto atual
void popContext();

// procura uma variável na pilha de contextos
var_info* findVar(string label);

// insere uma nova variável no contexto atual
void insertVar(string label, var_info info);

// registra um novo loop
void pushLoop();

// obtém o loop atual
loop_info* getLoop();

// obtém o loop mais exterior
loop_info* getOuterLoop();

// remove o loop atual
void popLoop();

// obtém a estratégia para os tipos e operação especificadas
strategy getStrategy(string op, string type1, string type2);

/* strategy declarations */
node doSimpleAritOp(string op, node left, node right);
node doSimpleRelOp(string op, node left, node right);
node doSimpleLogicOp(string op, node left, node right);
node doStringConcat(string op, node left, node right);
node doSimpleAttrib(string op, node left, node right);
node doStringAttrib(string op, node left, node right);
node fallback(string op, node left, node right);
  
int yylex(void);
void yyerror(string);
%}

%token TK_NUM TK_CHAR TK_STRING TK_BOOL
%token TK_IF "if"
%token TK_WHILE "while"
%token TK_FOR "for"
%token TK_DO "do"
%token TK_ELSE "else"
%token TK_AS "as"
%token TK_WRITE "write"
%token TK_CONST "const"
%token TK_MAIN TK_ID TK_INT_TYPE TK_FLOAT_TYPE TK_CHAR_TYPE
%token TK_DOUBLE_TYPE TK_LONG_TYPE TK_STRING_TYPE TK_BOOL_TYPE
%token TK_FIM TK_ERROR
%token TK_ENDL
%token TK_BSTART
%token TK_AND "and"
%token TK_OR "or"
%token TK_XOR "xor"
%token TK_NOT "not"
%token TK_GTE ">="
%token TK_LTE "<="
%token TK_NEQ "!="
%token TK_EQ "=="
%token TK_INCR "++"
%token TK_DECR "--"
%token TK_BREAK "break"
%token TK_CONT "continue"
%token TK_ALL "all"

%start S

%nonassoc '<' '>' "<=" ">=" "!=" "=="
%right "not"
%left "and" "or" "xor"
%left '+' '-'
%left '*' '/'
%left "as"
%nonassoc "++" "--"

%%

S 			: STATEMENTS {
				cout << 
				"/* Succinct lang */" << endl << endl <<
				"#include <iostream>" << endl <<
				"#include <string.h>" << endl <<
				"#include <stdio.h>" << endl <<
				"#include <stdlib.h>" << endl << endl <<
				"int main(void) {" << endl;
				
				for (string decl : decls) {
					cout << decl << endl;
				}
				
				cout << endl << $1.transl; 
				
				for (string desac : desacs) {
					cout << "\tfree(" << desac << ");" << endl;
				}
				
				cout << endl << "\treturn 0;\n}" << endl;
			};
			
PUSH_SCOPE: {
				pushContext();
				
				$$.transl = "";
				$$.label = "";
			};
			
POP_SCOPE:	{
				popContext();
				
				$$.transl = "";
				$$.label = "";
			};
			
PUSH_LOOP:	{
				pushLoop();
				
				$$.transl = "";
				$$.label = "";
			};
			
POP_LOOP:	{
				popLoop();
				
				$$.transl = "";
				$$.label = "";
			};

BLOCK		: PUSH_SCOPE '{' STATEMENTS '}' POP_SCOPE {
				$$.transl = $3.transl;
			};

STATEMENTS	: STATEMENT STATEMENTS {
				$$.transl = $1.transl + "\n" + $2.transl;
			}
			| {$$.transl = "";}
			;

STATEMENT 	: EXPR ';' {
				$$.transl = $1.transl;
			}
			| DECL_OR_ATTR ';' {
				$$.transl = $1.transl;
			}
			| WRITE ';' {
				$$.transl = $1.transl;
			}
			| CONTROL
			| LOOP_CTRL ';' {
				$$.transl = $1.transl;
			}
			
LOOP_CTRL	: "break" {
				loop_info* loop = getLoop();
				
				if (loop != nullptr) {
					$$.transl = "\tgoto " + loop->end + ";\n";
				} else {
					yyerror("Break statements should be used inside a loop.");
				}
			}
			| "break" "all" {
				loop_info* loop = getOuterLoop();
				
				if (loop != nullptr) {
					$$.transl = "\tgoto " + loop->end + ";\n";
				} else {
					yyerror("Break statements should be used inside a loop.");
				}
			}
			| "continue" {
				loop_info* loop = getLoop();
				
				if (loop != nullptr) {
					$$.transl = "\tgoto " + loop->increment + ";\n";
				} else {
					yyerror("Continue statements should be used inside a loop.");
				}
			}
			| "continue" "all" {
				loop_info* loop = getOuterLoop();
				
				if (loop != nullptr) {
					$$.transl = "\tgoto " + loop->increment + ";\n";
				} else {
					yyerror("Continue statements should be used inside a loop.");
				}
			}
			;
			
CONTROL		: "if" EXPR TK_BSTART BLOCK {
				if ($2.type == "bool") {
					string var = getNextVar();
					string end = getNextLabel();
					
					decls.push_back("\tint " + var + ";");
					
					$$.transl = $2.transl + 
						"\t" + var + " = !" + $2.label + ";\n" +
						"\tif (" + var + ") goto " + end + ";\n" +
						$4.transl +
						"\t" + end + ":\n";
				} else {
					// throw compile error
					yyerror("Non-bool expression on if condition.");
				}
			}
			| "if" EXPR TK_BSTART BLOCK "else" TK_BSTART BLOCK {
				if ($2.type == "bool") {
					string var = getNextVar();
					string endif = getNextLabel();
					string endelse = getNextLabel();
					
					decls.push_back("\tint " + var + ";");
					
					$$.transl = $2.transl + 
						"\t" + var + " = !" + $2.label + ";\n" +
						"\tif (" + var + ") goto " + endif + ";\n" +
						$4.transl +
						"\tgoto " + endelse + ";\n" +
						endif + ":" + $7.transl +
						endelse + ":";
				} else {
					// throw compile error
					yyerror("Non-bool expression on if condition.");
				}
			}
			| PUSH_LOOP LOOP POP_LOOP {$$.transl = $2.transl;};
			;
			
LOOP		: "while" EXPR TK_BSTART BLOCK {
				if ($2.type == "bool") {
					string var = getNextVar();
					loop_info* loop = getLoop();
					
					decls.push_back("\tint " + var + ";");
					
					$$.transl = loop->start + ":\n" 
						+ loop->increment + ":" + $2.transl
						+ "\t" + var + " = !" + $2.label + ";\n" +
						"\tif (" + var + ") goto " + loop->end + ";\n" +
						$4.transl +
						"\tgoto " + loop->start + ";\n" + loop->end + ":\n";
				} else {
					// throw compile error
					yyerror("Non-bool expression on while condition.");
				}
			}
			| "do" BLOCK "while" EXPR ';' {
				if ($4.type == "bool") {
					loop_info* loop = getLoop();
					
					$$.transl = loop->start + ":\n" 
						+ loop->increment + ":" + $2.transl
						+ $4.transl + "\tif (" 
						+ $4.label + ") goto " + loop->start + ";\n"
						+ loop->end + ":\n";
				} else {
					// throw compile error
					yyerror("Non-bool expression on do-while condition.");
				}
			}
			| "for" DECL_OR_ATTR ';' EXPR ';' FOR_ATTR TK_BSTART BLOCK {
				if ($4.type == "bool") {
					string var = getNextVar();
					loop_info* loop = getLoop();
					
					decls.push_back("\tint " + var + ";");
					
					$$.transl = $2.transl + loop->start + ":" + $4.transl + 
						"\t" + var + " = !" + $4.label + ";\n" +
						"\tif (" + var + ") goto " + loop->end + ";\n" +
						$8.transl + loop->increment + ":" + $6.transl +
						"\tgoto " + loop->start + ";\n" + 
						loop->end + ":\n";
				} else {
					// throw compile error
					yyerror("Non-bool expression on for condition.");
				}
			}
			;
			
WRITE		: "write" WRITE_ARGS {
				$$.transl = "\tstd::cout" + $2.transl + ";\n";
			}
			;
		
WRITE_ARGS	: WRITE_ARG WRITE_ARGS {
				$$.transl = $1.transl + $2.transl;
			}
			| WRITE_ARG {$$.transl = $1.transl;}
			;
			
WRITE_ARG	: EXPR {$$.transl = " << " + $1.label;}
			| TK_ENDL {$$.transl = " << std::endl";}
			;
			
FOR_ATTR	: ATTRIBUTION
			| INCR_OR_DECR
			;

DECL_OR_ATTR: DECLARATION
			| ATTRIBUTION
			| DECL_AND_ATTR
			;
			
DECLARATION : TYPE TK_ID {
				var_info* info = findVar($2.label);
				
				if (info == nullptr) {
					string var = getNextVar();
					
					insertVar($2.label, {$1.transl, var, true});
					
					decls.push_back("\t" + $1.transl + " " + var + ";");
					$$.transl = "\t" + var + " = " + 
						padraoMap[$1.transl] + ";\n";
					$$.label = var;
					$$.type = $1.transl;
				} else {
					// throw compile error
					yyerror("Variable " + $2.label + " redeclared.");
				}
			}
			| "const" TYPE TK_ID {
				yyerror("Constant variables must be given a value at its declaration.");
			}
			;
	
ATTRIBUTION	: TK_ID '=' EXPR {
				strategy strat = getStrategy("=", $1.type, $3.type);
				
				$$ = strat("=", $1, $3);
			}
			;
			
INCR_OR_DECR: INCREMENT
			| DECREMENT
			;
			
INCREMENT	: "++" TK_ID {
				var_info* info = findVar($2.label);
				
				if (info != nullptr) {
					if (!info->isMutable) {
						yyerror("Increment on constant variable " + $2.label +  ".");
					}
					
					string var = getNextVar();
					decls.push_back("\tint " + var + ";");
					
					// se incremento é permitido
					if (info->type == "int") {
						$$.type = $2.type;
						$$.transl = "\t" + var + " = 1;\n\t" + 
							info->name + " = " + info->name + " + " + var + ";\n";
						$$.label = info->name;
					} else {
						string var2 = getNextVar();
						string resType = opMap[info->type + "=int"];
						
						// se conversão é permitida
						if (resType.size()) {
							decls.push_back("\t" + resType + " " + var2 + ";");
							
							$$.type = $2.type;
							$$.transl = "\t" + var + " = 1;\n\t" + 
								var2 + " = (" + info->type + ") " + var + 
								";\n\t" +
								info->name + " = " + info->name + " + " + var2 + ";\n";
							$$.label = info->name;
						} else {
							// throw compile error
							yyerror("Variable increment with incompatible type " 
								+ info->type + ".");
						}
					}
				} else {
					// throw compile error
					yyerror("Variable " + $2.label + " not declared.");
				}
			}
			/*| TK_ID "++" {
				var_info* info = findVar($1.label);
				
				if (info != nullptr) {
					if (!info->isMutable) {
						yyerror("Increment on constant variable " + $1.label +  ".");
					}
					
					string var = getNextVar();
					string var2 = getNextVar();
					decls.push_back("\tint " + var + ";");
					decls.push_back("\t" + info->type + " " + var2 + ";");
					
					// se incremento é permitido
					if (info->type == "int") {
						$$.type = $1.type;
						$$.transl = "\t" + var2 + " = " + info->name + 
							";\n\t" + var + " = 1;\n\t" + 
							info->name + " = " + info->name + " + " + var + ";\n";
						$$.label = var2;
					} else {
						string var3 = getNextVar();
						string resType = opMap[info->type + "=int"];
						
						// se conversão é permitida
						if (resType.size()) {
							$$.type = $1.type;
							$$.transl = "\t" + var2 + " = " + info->name + 
							";\n\t" + var + " = 1;\n\t" + 
								var3 + " = (" + info->type + ") " + var + 
								";\n\t" +
								info->name + " = " + info->name + " + " + var3 + ";\n";
							$$.label = var2;
						} else {
							// throw compile error
							yyerror("Variable increment with incompatible type " 
								+ info->type + ".");
						}
					}
				} else {
					// throw compile error
					yyerror("Variable " + $1.label + " not declared.");
				}
			}*/
			;
			
DECREMENT	: "--" TK_ID {
				var_info* info = findVar($2.label);
				
				if (info != nullptr) {
					if (!info->isMutable) {
						yyerror("Decrement on constant variable " + $2.label +  ".");
					}
					
					string var = getNextVar();
					decls.push_back("\tint " + var + ";");
					
					// se incremento é permitido
					if (info->type == "int") {
						$$.type = $2.type;
						$$.transl = "\t" + var + " = 1;\n\t" + 
							info->name + " = " + info->name + " - " + var + ";\n";
						$$.label = info->name;
					} else {
						string var2 = getNextVar();
						string resType = opMap[info->type + "=int"];
						
						// se conversão é permitida
						if (resType.size()) {
							decls.push_back("\t" + resType + " " + var2 + ";\n");
							
							$$.type = $2.type;
							$$.transl = "\t" + var + " = 1;\n\t" + 
								var2 + " = (" + info->type + ") " + var + 
								";\n\t" +
								info->name + " = " + info->name + " - " + var2 + ";\n";
							$$.label = info->name;
						} else {
							// throw compile error
							yyerror("Variable increment with incompatible type " 
								+ info->type + ".");
						}
					}
				} else {
					// throw compile error
					yyerror("Variable " + $2.label + " not declared.");
				}
			}
			/*| TK_ID "--" {
				var_info* info = findVar($1.label);
				
				if (info != nullptr) {
					if (!info->isMutable) {
						yyerror("Increment on constant variable " + $1.label +  ".");
					}
					
					string var = getNextVar();
					string var2 = getNextVar();
					decls.push_back("\tint " + var + ";");
					decls.push_back("\t" + info->type + " " + var2 + ";");
					
					// se incremento é permitido
					if (info->type == "int") {
						$$.type = $1.type;
						$$.transl = "\t" + var2 + " = " + info->name + 
							";\n\t" + var + " = 1;\n\t" + 
							info->name + " = " + info->name + " - " + var + ";\n";
						$$.label = var2;
					} else {
						string var3 = getNextVar();
						string resType = opMap[info->type + "=int"];
						
						// se conversão é permitida
						if (resType.size()) {
							$$.type = $1.type;
							$$.transl = "\t" + var2 + " = " + info->name + 
							";\n\t" + var + " = 1;\n\t" + 
								var3 + " = (" + info->type + ") " + var + 
								";\n\t" +
								info->name + " = " + info->name + " - " + var3 + ";\n";
							$$.label = var2;
						} else {
							// throw compile error
							yyerror("Variable increment with incompatible type " 
								+ info->type + ".");
						}
					}
				} else {
					// throw compile error
					yyerror("Variable " + $1.label + " not declared.");
				}
			}*/
			;

DECL_AND_ATTR: TYPE TK_ID '=' EXPR {
				var_info* info = findVar($2.label);
				
				if (info == nullptr) {
					if ($4.type == $1.transl) {
						$$.transl = $4.transl;
						
						insertVar($2.label, {$1.transl, $4.label, true});
					} else {
						string var = getNextVar();
						string resType = opMap[$1.transl + "=" + $4.type];
						
						// se conversão é permitida
						if (resType.size()) {
							decls.push_back("\t" + $1.transl + " " + var + ";");
							
							$$.transl = $4.transl + "\t" + 
								var + " = (" + $1.transl + ") " + $4.label + 
								";\n\t";
						
							insertVar($2.label, {$1.transl, var, true});	
						} else {
							// throw compile error
							yyerror("Variable assignment with incompatible types " 
								+ info->type + " and " + $3.type + ".");
						}
					}
				} else {
					// throw compile error
					yyerror("Variable " + $2.label + " redeclared.");
				}
			}
			| "const" TYPE TK_ID '=' EXPR {
				var_info* info = findVar($3.label);
				
				if (info == nullptr) {
					if ($5.type == $2.transl) {
						$$.transl = $5.transl;
						
						insertVar($3.label, {$2.transl, $5.label, false});
					}  else {
						string var = getNextVar();
						string resType = opMap[$2.transl + "=" + $5.type];
						
						// se conversão é permitida
						if (resType.size()) {
							decls.push_back("\t" + $2.transl + " " + var + ";");
							
							$$.transl = $5.transl + "\t" + 
								var + " = (" + $2.transl + ") " + $5.label + 
								";\n\t";
						
							insertVar($3.label, {$2.transl, var, true});	
						} else {
							// throw compile error
							yyerror("Variable assignment with incompatible types " 
								+ info->type + " and " + $3.type + ".");
						}
					}
				} else {
					// throw compile error
					yyerror("Variable " + $3.label + " redeclared.");
				}
			}
			;

EXPR 		: EXPR '+' EXPR {
				strategy strat = getStrategy("+", $1.type, $3.type);
				
				$$ = strat("+", $1, $3);
			}
			| EXPR '-' EXPR {
				strategy strat = getStrategy("-", $1.type, $3.type);
				
				$$ = strat("-", $1, $3);
			}
			| EXPR '*' EXPR {
				strategy strat = getStrategy("*", $1.type, $3.type);
				
				$$ = strat("*", $1, $3);
			}
			| EXPR '/' EXPR {
				strategy strat = getStrategy("/", $1.type, $3.type);
				
				$$ = strat("/", $1, $3);
			}
			| EXPR '<' EXPR {
				strategy strat = getStrategy("<", $1.type, $3.type);
				
				$$ = strat("<", $1, $3);
			}
			| EXPR '>' EXPR {
				strategy strat = getStrategy(">", $1.type, $3.type);
				
				$$ = strat(">", $1, $3);
			}
			| EXPR "<=" EXPR {
				strategy strat = getStrategy("<=", $1.type, $3.type);
				
				$$ = strat("<=", $1, $3);
			}
			| EXPR ">=" EXPR {
				strategy strat = getStrategy(">=", $1.type, $3.type);
				
				$$ = strat(">=", $1, $3);
			}
			| EXPR "==" EXPR {
				strategy strat = getStrategy("==", $1.type, $3.type);
				
				$$ = strat("==", $1, $3);
			}
			| EXPR "!=" EXPR {
				strategy strat = getStrategy("!=", $1.type, $3.type);
				
				$$ = strat("!=", $1, $3);
			}
			| EXPR "and" EXPR {
				strategy strat = getStrategy("&&", $1.type, $3.type);
				
				$$ = strat("&&", $1, $3);
			}
			| EXPR "or" EXPR {
				strategy strat = getStrategy("||", $1.type, $3.type);
				
				$$ = strat("||", $1, $3);
			}
			| EXPR "xor" EXPR {
				string var[4] = {getNextVar(), getNextVar(), 
					getNextVar(), getNextVar()};
				
				if ($1.type == "bool" && $3.type == "bool") {
					decls.push_back("\tint " + var[0] + ";");
					decls.push_back("\tint " + var[1] + ";");
					decls.push_back("\tint " + var[2] + ";");
					decls.push_back("\tint " + var[3] + ";");
					
					$$.type = "bool";
					$$.transl = $1.transl + $3.transl +
						"\t" + var[0] + " = " + $1.label + " || " + $3.label + ";\n" +
						"\t" + var[1] + " = " + $1.label + " && " + $3.label + ";\n" +
						"\t" + var[2] + " = !" + var[1] + ";\n" +
						"\t" + var[3] + " = " + var[0] + " && " + var[2] + ";\n";
					$$.label = var[3];
				} else {
					// throw compiler error
					yyerror("Logic operation between non-bool values.");
				}
			}
			| "not" EXPR {
				string var = getNextVar();
				
				if ($2.type == "bool") {
					$$.type = $2.type;
					$$.label = var;
					decls.push_back("\tint " + var + ";");
					$$.transl = $2.transl +
						"\t" + var + " = !" + $2.label + ";\n";
				} else {
					// throw compiler error
					yyerror("Logic operation with non-bool value.");
				}
			}
			| '(' EXPR ')' {
				$$.type = $2.type;
				$$.label = $2.label;
				$$.transl = $2.transl;
			}
			| EXPR "as" TYPE {
				string var = getNextVar();
				string type = opMap[$3.transl + "cast" + $1.type];
				
				if (type.size()) {
					$$.type = $3.transl;
					decls.push_back("\t" + type + " " + var + ";");
					$$.transl = $1.transl + 
						"\t" + var + " = (" + $3.transl + ") " + $1.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Invalid cast from " + $1.type + " to " + $3.transl + ".");
				}
			}
			| INCR_OR_DECR
			| VALUE_OR_ID
			;
			
VALUE_OR_ID	: TK_NUM {
				string var = getNextVar();
				string value = $1.label;
				
				if ($1.type == "float") {
					value = to_string(stof(value));
				} else if ($1.type == "double") {
					value = to_string(stod(value));
				} else if ($1.type == "long") {
					value = to_string(stol(value));
				}
				
				decls.push_back("\t" + $1.type + " " + var + ";");
				$$.transl = "\t" + var + " = " + value + ";\n";
				$$.label = var;
			}
			| TK_BOOL {
				string var = getNextVar();
				
				$1.label = ($1.label == "true"? "1" : "0");
				
				decls.push_back("\tint " + var + ";");
				$$.transl = "\t" + var + " = " + $1.label + ";\n";
				$$.label = var;
			}
			| TK_CHAR {
				string var = getNextVar();
				
				decls.push_back("\t" + $1.type + " " + var + ";");
				$$.transl = "\t" + var + " = " + $1.label + ";\n";
				$$.label = var;
			}
			| TK_STRING {
				string var = getNextVar();
				
				decls.push_back("\tchar* " + var + ";");
				
				$$.transl = "\t" + var + " = (char*) \"" + $1.label + "\";\n";
				$$.size = $1.label.size();
				$$.label = var;
			}
			| TK_ID {
				var_info* info = findVar($1.label);
				
				if (info != nullptr && info->name.size()) {
					$$.type = info->type;
					$$.label = info->name;
					$$.transl = "";
				} else {
					// throw compile error
					yyerror("Variable " + $1.label + " not declared.");
				}
			}
			;
			
TYPE		: TK_INT_TYPE
			| TK_FLOAT_TYPE
			| TK_DOUBLE_TYPE
			| TK_LONG_TYPE
			| TK_CHAR_TYPE
			| TK_STRING_TYPE
			| TK_BOOL_TYPE
			;

%%

#include "lex.yy.c"

/********* util functions **********/

int yyparse();

int main(int argc, char* argv[]) {
	/*#ifdef YYDEBUG
	    extern int yydebug;
	    yydebug = 1;
	#endif*/

	opMapFile.open("util/opmap.dat");
	padraoMapFile.open("util/default.dat");
	
	if (opMapFile.is_open()) {
		while (opMapFile >> type1 >> op >> type2 >> typeRes >> strategyName) {
	    	opMap[type1 + op + type2] = typeRes;
	    	preStrategyMap[type1 + op + type2] = strategyName;
		}
		
		opMapFile.close();
	} else {
		cout << "Unable to open operator map file";
	}
	
	if (padraoMapFile.is_open()) {
		while (padraoMapFile >> type1 >> value) {
	    	padraoMap[type1] = value;
		}
		
		padraoMapFile.close();
	} else {
		cout << "Unable to open default values file";
	}
	
	// register type generalization
	typeMap["+"] = "arit";
	typeMap["-"] = "arit";
	typeMap["*"] = "arit";
	typeMap["/"] = "arit";
	typeMap["<"] = "rel";
	typeMap["<="] = "rel";
	typeMap[">"] = "rel";
	typeMap[">="] = "rel";
	typeMap["=="] = "rel";
	typeMap["!="] = "rel";
	typeMap["&&"] = "logic";
	typeMap["||"] = "logic";
	
	// register strategies
	strategyMap["simple-aritmethic"] = doSimpleAritOp;
	strategyMap["simple-relational"] = doSimpleRelOp;
	strategyMap["simple-logic"] = doSimpleLogicOp;
	strategyMap["string-concat"] = doStringConcat;
	strategyMap["simple-attrib"] = doSimpleAttrib;
	strategyMap["string-attrib"] = doStringAttrib;
	
	// insert global context
	map<string, var_info> globalContext;
	varMap.push_back(globalContext);

	yyparse();

	return 0;
}

void yyerror(string MSG) {
	cout << "Error: " << MSG << endl;
	exit (0);
}

var_info* findVar(string label) {
	for (int i = varMap.size() - 1; i >= 0; i--) {
		if (varMap[i].count(label)) {
			return &varMap[i][label];
		}
	}
	
	return nullptr;
}

void insertVar(string label, var_info info) {
	varMap[varMap.size() - 1][label] = info;
}

void pushContext() {
	map<string, var_info> newContext;
	varMap.push_back(newContext);
}

void popContext() {
	return varMap.pop_back();
}

void pushLoop() {
	loop_info newLoop = {getNextLabel(), getNextLabel(), getNextLabel()};
	loopMap.push_back(newLoop);
}

loop_info* getLoop() {
	if (loopMap.size()) {
		return &loopMap[loopMap.size() - 1];
	} else {
		return nullptr;
	}
}

loop_info* getOuterLoop() {
	if (loopMap.size()) {
		return &loopMap[0];
	} else {
		return nullptr;
	}
}

void popLoop() {
	return loopMap.pop_back();
}

string getNextVar() {
    return "t" + to_string(tempGen++);
}

string getNextLabel() {
	return "lbl" + to_string(tempLabel++);
}

strategy getStrategy(string op, string type1, string type2) {
	string strategyName;
	
	do {
		strategyName = preStrategyMap[type1 + op + type2];
		op = typeMap[op];
	} while (strategyName.empty() && !op.empty());
	
	if (!strategyMap.count(strategyName)) {
		return fallback;
	}
	
	return strategyMap[strategyName];
}

/********** strategies **********/

node doSimpleAritOp(string op, node left, node right) {
	node result;
	string var = getNextVar();
	string resType, tempOp = op;
	
	do {
		resType = opMap[left.type + tempOp + right.type];
		tempOp = typeMap[tempOp];
	} while (resType.empty() && !tempOp.empty());
	
	if (resType.empty()) {
		// throw compile error
		yyerror("Arithmetic operator '" + op + "' between types " 
		+ left.type + " and " + right.type + " is not defined.");
	}
	
	result.transl = left.transl + right.transl;
	
	// if left needs conversion
	if (left.type != resType) {
		string var1 = getNextVar();
		decls.push_back("\t" + resType + " " + var1 + ";");
		
		result.transl += "\t" + var1 + " = (" + 
			resType + ") " + left.label + ";\n";
		
		left.label = var1;
	}
	
	// if right needs conversion
	if (right.type != resType) {
		string var1 = getNextVar();
		decls.push_back("\t" + resType + " " + var1 + ";");
		
		result.transl += "\t" + var1 + " = (" + 
			resType + ") " + right.label + ";\n";
		
		right.label = var1;
	}
	
	result.type = resType;
	decls.push_back("\t" + result.type + " " + var + ";");
	
	result.transl += "\t" + var + " = " + 
		left.label + " " + op + " " + right.label + ";\n";
	result.label = var;
	
	return result;
}

node doSimpleRelOp(string op, node left, node right) {
	node result;
	string var = getNextVar();
	string resType, tempOp = op;
	
	do {
		resType = opMap[left.type + tempOp + right.type];
		tempOp = typeMap[tempOp];
	} while (resType.empty() && !tempOp.empty());
	
	if (resType.empty()) {
		// throw compile error
		yyerror("Relational operator '" + op + "' between types " 
		+ left.type + " and " + right.type + " is not defined.");
	}
	
	result.transl = left.transl + right.transl;
	
	if (left.type != resType) {
		string var1 = getNextVar();
		decls.push_back("\t" + resType + " " + var1 + ";");
		result.transl += "\t" + var1 + " = (" + 
			resType + ") " + left.label + ";\n";
		
		left.label = var1;
	}
	
	if (right.type != resType) {
		string var1 = getNextVar();
		decls.push_back("\t" + resType + " " + var1 + ";");
		result.transl += "\t" + var1 + " = (" + 
			resType + ") " + right.label + ";\n";
		
		right.label = var1;
	}

	result.type = "bool";
	decls.push_back("\tint " + var + ";");
	result.transl += "\t" + var + " = " + 
		left.label + " " + op + " " + right.label + ";\n";
	result.label = var;
	
	return result;
}

node doSimpleLogicOp(string op, node left, node right) {
	node result;
	string var = getNextVar();
	string resType, tempOp = op;
	
	do {
		resType = opMap[left.type + tempOp + right.type];
		tempOp = typeMap[tempOp];
	} while (resType.empty() && !tempOp.empty());
	
	if (resType.empty()) {
		// throw compiler error
		yyerror("Logic operation between non-bool values.");
	}
	
	result.type = "bool";
	decls.push_back("\tint " + var + ";");
	result.transl = left.transl + right.transl + 
	"\t" + var + " = " + left.label + " " + op + " " + right.label + ";\n";
	result.label = var;
	
	return result;
}

node doStringConcat(string op, node left, node right) {
	node result;
	string var = getNextVar();
	string resType, tempOp = op;
	
	do {
		resType = opMap[left.type + tempOp + right.type];
		tempOp = typeMap[tempOp];
	} while (resType.empty() && !tempOp.empty());
	
	result.transl = left.transl + right.transl;
	
	result.type = resType;
	decls.push_back("\tchar* " + var + ";");
	desacs.push_back(var);	
	
	result.transl += 
		"\t" + var + " = (char*) malloc(" + to_string(left.size + right.size) + 
		" * sizeof(char));\n\tstrcpy(" + var + ", " + left.label + 
		");\n\tstrcat(" + var + ", " + right.label + ");\n";
	result.label = var;
	
	return result;
}

node doSimpleAttrib(string op, node left, node right) {
	node result;
	var_info* info = findVar(left.label);
	
	if (info == nullptr) {
		// throw compile error
		yyerror("Variable " + left.label + " not declared.");
	}
	
	if (!info->isMutable) {
		yyerror("Assignment on constant variable " 
			+ left.label +  ".");
	}
	
	// se tipo da expr for igual a do id
	if (info->type == right.type) {
		string label = right.label;
		
		result.type = right.type;
		result.transl = right.transl + "\t" + info->name 
			+ " = " + label + ";\n";
		result.label = right.label;
	} else {
		string var = getNextVar();
		string resType = opMap[info->type + "=" + right.type];
		
		// se conversão é permitida
		if (resType.size()) {
			decls.push_back("\t" + info->type + " " + var + ";");
			
			result.transl = right.transl + "\t" + 
				var + " = (" + info->type + ") " + 
				right.label + ";\n\t" + info->name + 
				" = " + var + ";\n";
			result.type = info->type;
			result.label = var;
		} else {
			// throw compile error
			yyerror("Variable assignment with incompatible types " 
				+ info->type + " and " + right.type + ".");
		}
	}
	
	return result;
}

node doStringAttrib(string op, node left, node right) {
	node result;
	var_info* info = findVar(left.label);
	
	if (info == nullptr) {
		// throw compile error
		yyerror("Variable " + left.label + " not declared.");
	}
	
	if (!info->isMutable) {
		yyerror("Assignment on constant variable " 
			+ left.label +  ".");
	}
	
	// se tipo da expr for igual a do id
	if (info->type == right.type) {
		string label = "strdup(" + right.label + ")";
		
		result.type = right.type;
		result.size = right.size;
		result.transl = right.transl + "\t" + info->name 
			+ " = " + label + ";\n";
		result.label = right.label;
	} else {
		string var = getNextVar();
		string resType = opMap[info->type + "=" + right.type];
		
		// se conversão é permitida
		if (resType.size()) {
			decls.push_back("\t" + info->type + " " + var + ";");
			
			result.transl = right.transl + "\t" + 
				var + " = (" + info->type + ") " + 
				right.label + ";\n\t" + info->name + 
				" = " + var + ";\n";
			result.type = info->type;
			result.size = right.size;
			result.label = var;
		} else {
			// throw compile error
			yyerror("Variable assignment with incompatible types " 
				+ info->type + " and " + right.type + ".");
		}
	}
	
	return result;
}

node fallback(string op, node left, node right) {
	yyerror("Operation '" + op + "' between types " 
		+ left.type + " and " + right.type 
		+ " is not defined.");
}
