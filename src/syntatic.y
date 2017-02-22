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
	int size; // tamanho da variável; usado somente com strings
} var_info;

typedef struct loop_info {
	string start; // nome da label do início do bloco
	string increment; // nome da label do início do incremento
	string end; // nome da label do fim do bloco
} loop_info;

typedef struct func_info {
	string label;
	vector<var_info> params;
	string type;
	string transl;
} func_info;

typedef function<node(string, node, node)> strategy;

string type1, type2, op, typeRes, strategyName, value;
ifstream opMapFile, padraoMapFile;

int tempGen = 0;
int tempLabel = 0;
int tempFunc = 0;

int funcStack = 0;

// declarações de variáveis
vector<string> decls;

// desalocações de variáveis
vector<string> desacs;

// declarações de funções
vector<func_info> funcs;

// pilha de mapas de variável
vector<map<string, var_info>> varMap;

// pilha de labels de loops
vector<loop_info> loopMap;

// mapa de funções
map<string, func_info> funcMap;

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

// otém o próximo nome de função disponível
string getNextFunc();

// inicia um novo contexto
void pushContext();

// destrói o contexto atual
void popContext();

// procura uma variável na pilha de contextos
var_info* findVar(string label);

// procura uma variável no primeiro contexto da pilha de contextos
var_info* findVarOnTop(string label);

// insere uma nova variável no contexto atual
void insertVar(string label, var_info info);

// procura uma função no mapa de funções
func_info* findFunc(string var);

// insere uma nova função no mapa de funções
void insertFunc(string var, func_info info);

// registra um novo loop
void pushLoop();

// obtém o loop atual
loop_info* getLoop();

// obtém o loop mais exterior
loop_info* getOuterLoop();

// remove o loop atual
void popLoop();

// separar uma string
template<typename Out>
void split(const string &s, char delim, Out result);

vector<string> split(const string &s, char delim);

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
%token TK_ELIF "elif"
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
%token TK_ARROW "->"
%token TK_FUNC_TYPE "func"
%token TK_RET "return"

%start S

%nonassoc '<' '>' "<=" ">=" "!=" "=="
%right "not"
%left "and" "or" "xor"
%left '+' '-'
%left '*' '/'
%left "as"
%right "++" "--" TK_ID '('

%%

S 			: STATEMENTS {
				cout << 
				"/* Succinct lang */" << endl << endl <<
				"#include <iostream>" << endl <<
				"#include <string.h>" << endl <<
				"#include <stdio.h>" << endl <<
				"#include <stdlib.h>" << endl << endl;
				
				for (string decl : decls) {
					cout << decl << endl;
				}
				
				cout << endl;
				
				for (func_info func : funcs) {
					cout << func.type + " " + func.label + "(";
					
					for (int i = 0; i < func.params.size(); ++i) {
						cout << func.params[i].type + " " + func.params[i].name;
						if (i < func.params.size() - 1) cout << ", ";
					}
					
					cout << ") {\n" + func.transl + "}\n" << endl;
				}
				
				cout << "int main(void) {" << endl << $1.transl;
				
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
			
PUSH_FUNC:	{
				pushContext();
				++funcStack;
				
				$$.transl = "";
				$$.label = "";
			};

POP_FUNC:	{
				popContext();
				--funcStack;
				
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
			| FUNCTION
			| FUNC_CTRL ';' {
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
			
FUNC_CTRL	: "return" EXPR {
				if (funcStack > 0) {
					// todo: validar tipo do retorno
					$$.transl = $2.transl + "\treturn " + $2.label + ";\n";
				} else {
					yyerror("Return statements should be used inside a function.");
				}
			}
			;
			
CONTROL		: "if" EXPR TK_BSTART BLOCK {
				if ($2.type == "bool") {
					string var = getNextVar();
					string end = getNextLabel();
					
					decls.push_back("int " + var + ";");
					
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
			| "if" EXPR TK_BSTART BLOCK IF_PREDS {
				if ($2.type != "bool") {
					// throw compile error
					yyerror("Non-bool expression on if condition.");
				}
				
				string var = getNextVar();
				string endif = getNextLabel();
				
				decls.push_back("int " + var + ";");
				
				$$.transl = $2.transl + 
					"\t" + var + " = !" + $2.label + ";\n" +
					"\tif (" + var + ") goto " + endif + ";\n" +
					$4.transl +
					"\tgoto " + $5.label + ";\n" +
					endif + ":" + $5.transl;
			}
			| PUSH_LOOP LOOP POP_LOOP {$$.transl = $2.transl;};
			;
			
IF_PREDS	: "elif" EXPR TK_BSTART BLOCK {
				string var = getNextVar();
				string endelif = getNextLabel();
				
				decls.push_back("int " + var + ";");
				
				$$.transl = $2.transl + 
					"\t" + var + " = !" + $2.label + ";\n" +
					"\tif (" + var + ") goto " + endelif + ";\n" +
					$4.transl +
					endelif + ":";
				$$.label = endelif;
			}
			| "elif" EXPR TK_BSTART BLOCK IF_PREDS {
				string var = getNextVar();
				string endelif = getNextLabel();
				
				decls.push_back("int " + var + ";");
				
				$$.transl = $2.transl + 
					"\t" + var + " = !" + $2.label + ";\n" +
					"\tif (" + var + ") goto " + endelif + ";\n" +
					$4.transl +
					"\tgoto " + $5.label + ";\n" +
					endelif + ":" + $5.transl;
				$$.label = $5.label;
			}
			| "else" TK_BSTART BLOCK {
				string endelse = getNextLabel();
				
				$$.transl = $3.transl + endelse + ":";
				$$.label = endelse;
			}
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
					
					decls.push_back("int " + var + ";");
					
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
				$$.transl = $2.transl + 
					"\tstd::cout" + $2.label + ";\n";
			}
			;
		
WRITE_ARGS	: WRITE_ARG WRITE_ARGS {
				$$.transl = $1.transl + $2.transl;
				$$.label = $1.label + $2.label;
			}
			| WRITE_ARG {
				$$.transl = $1.transl;
				$$.label = $1.label;
			}
			;
			
WRITE_ARG	: EXPR {
				$$.transl = $1.transl;
				$$.label = " << " + $1.label;
			}
			| TK_ENDL {
				$$.transl = "";
				$$.label = " << std::endl";
			}
			;
			
FOR_ATTR	: ATTRIBUTION
			| INCR_OR_DECR
			;

DECL_OR_ATTR: DECLARATION
			| ATTRIBUTION
			| DECL_AND_ATTR
			;
			
DECLARATION : TYPE TK_ID {
				var_info* info = findVarOnTop($2.label);
				
				if (info == nullptr) {
					string var = getNextVar();
					
					insertVar($2.label, {$1.transl, var, true, 0});
					
					decls.push_back($1.transl + " " + var + ";");
					$$.transl = "\t" + var + " = " + 
						padraoMap[$1.transl] + ";\n";
					$$.label = var;
					$$.type = $1.transl;
				} else {
					// throw compile error
					yyerror("Variable " + $2.label + " redeclared.");
				}
			}
			| TYPE TK_ID DIMENSION {
				var_info* info = findVarOnTop($2.label);
				
				if (info == nullptr) {
				 	string var = getNextVar();
					
				 	insertVar($2.label, {$1.transl, var, true, 0});
					
				 	decls.push_back($3.transl + "\t" + $1.transl + " " 
				 		+ var + "[" + $3.label + "];");
					$$.transl = "";

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


DIMENSION:	DIMENSION '[' EXPR ']' {
				if ($3.type != "int") {
					cout << "List size must be defined by integers, "
						<< $3.type << " given.";
				}

				string var = getNextVar();
				decls.push_back("int " + var + ";");

				$$.transl = $1.transl + $3.transl + "\n\t" + var + " = " 
					+ $1.label + " * " + $3.label + ";\n";
				$$.label = var;
			}
			| '[' EXPR ']' {
				if ($2.type != "int") {
					cout << "List size must be defined by integers, "
						<< $3.type << " given.";
				}
				
				$$.transl = $2.transl;
				$$.label = $2.label;
			}

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
					decls.push_back("int " + var + ";");
					
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
							decls.push_back(resType + " " + var2 + ";");
							
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
			| TK_ID "++" {
				var_info* info = findVar($1.label);
				
				if (info != nullptr) {
					if (!info->isMutable) {
						yyerror("Increment on constant variable " + $1.label +  ".");
					}
					
					string var = getNextVar();
					string var2 = getNextVar();
					decls.push_back("int " + var + ";");
					decls.push_back(info->type + " " + var2 + ";");
					
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
			}
			;
			
DECREMENT	: "--" TK_ID {
				var_info* info = findVar($2.label);
				
				if (info != nullptr) {
					if (!info->isMutable) {
						yyerror("Decrement on constant variable " + $2.label +  ".");
					}
					
					string var = getNextVar();
					decls.push_back("int " + var + ";");
					
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
							decls.push_back(resType + " " + var2 + ";\n");
							
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
			| TK_ID "--" {
				var_info* info = findVar($1.label);
				
				if (info != nullptr) {
					if (!info->isMutable) {
						yyerror("Increment on constant variable " + $1.label +  ".");
					}
					
					string var = getNextVar();
					string var2 = getNextVar();
					decls.push_back("int " + var + ";");
					decls.push_back(info->type + " " + var2 + ";");
					
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
			}
			;

DECL_AND_ATTR: TYPE TK_ID '=' EXPR {
				var_info* info = findVarOnTop($2.label);
				
				if (info != nullptr) {
					// throw compile error
					yyerror("Variable " + $2.label + " redeclared.");
				}
				
				if ($4.type == $1.transl) {
					$$.transl = $4.transl;
					
					insertVar($2.label, 
						{$1.transl, $4.label, true, $4.size});
				} else {
					string var = getNextVar();
					string resType = opMap[$1.transl + "=" + $4.type];
					
					// se conversão é permitida
					if (resType.size()) {
						decls.push_back($1.transl + " " + var + ";");
						
						$$.transl = $4.transl + "\t" + 
							var + " = (" + $1.transl + ") " + $4.label + 
							";\n\t";
					
						insertVar($2.label, {$1.transl, var, true, $4.size});	
					} else {
						// throw compile error
						yyerror("Variable assignment with incompatible types " 
							+ $1.transl + " and " + $4.type + ".");
					}
				}
			}
			| "const" TYPE TK_ID '=' EXPR {
				var_info* info = findVarOnTop($3.label);
				
				if (info == nullptr) {
					if ($5.type == $2.transl) {
						$$.transl = $5.transl;
						
						insertVar($3.label, 
							{$2.transl, $5.label, false, $5.size});
					}  else {
						string var = getNextVar();
						string resType = opMap[$2.transl + "=" + $5.type];
						
						// se conversão é permitida
						if (resType.size()) {
							decls.push_back($2.transl + " " + var + ";");
							
							$$.transl = $5.transl + "\t" + 
								var + " = (" + $2.transl + ") " + $5.label + 
								";\n\t";
						
							insertVar($3.label, 
								{$2.transl, var, false, $5.size});	
						} else {
							// throw compile error
							yyerror("Variable assignment with incompatible types " 
								+ $2.transl + " and " + $5.type + ".");
						}
					}
				} else {
					// throw compile error
					yyerror("Variable " + $3.label + " redeclared.");
				}
			}
			;
			
FUNCTION	: "func" PUSH_FUNC TK_ID FUNC_PARAMS "->" TYPE 
					TK_BSTART BLOCK POP_FUNC {
				string func = getNextFunc();
				vector<var_info> params;
				string paramsType = "";
				
				string returnType = $6.transl;
				if (returnType == "string") returnType = "char*";
				
				for (string param : split($4.transl, ';')) {
					vector<string> info = split(param, ' ');
					
					params.push_back({info[0], info[1], true, 0});
				}
				
				for (int i = 0; i < params.size(); ++i) {
					if (params[i].type == "string") paramsType += "char*";
					else paramsType += params[i].type;

					if (i < params.size() - 1) paramsType += ", ";
				}
				
				$$.transl = "";
				
				insertFunc($3.label, {func, params, returnType, $8.transl});
			}
			;
			
FUNC_PARAMS	: FUNC_PARAM ',' FUNC_PARAMS {
				$$.transl = $1.transl + ";" + $3.transl;
			}
			| FUNC_PARAM {
				$$.transl = $1.transl;
			}
			;
			
FUNC_PARAM	: TYPE TK_ID {
				string var = getNextVar();
				
				decls.push_back($1.transl + " " + var + ";");
				insertVar($2.label, {$1.transl, var, true, 0});
				
				$$.transl = $1.transl + " " + var;
			}
			| "const" TYPE TK_ID {
				string var = getNextVar();
				
				decls.push_back($2.transl + " " + var + ";");
				insertVar($3.label, {$2.transl, var, false, 0});
				
				$$.transl = $2.transl + " " + var;
			}
			
FUNC_APPL	: TK_ID '(' FUNC_ARGS ')' {
				$$.transl = $3.transl;
				func_info* func = findFunc($1.label);
				
				if (func == nullptr) {
					yyerror("Function application on '" + $1.label 
						+ "' non-func variable.");
				}
				
				vector<var_info> args;
				string argsStr;
				
				// obtém lista de argumentos passados
				for (string arg : split($3.label, ';')) {
					vector<string> info = split(arg, ' ');
					
					args.push_back({info[0], info[1], true, 0});
				}
				
				string resType, tempOp = "=";
				
				// valida qtd de argumentos passados
				if (func->params.size() != args.size()) {
					yyerror("Function takes " + to_string(func->params.size()) 
						+ " arguments, " + to_string(args.size()) + " given.");
				}
				
				// valida tipo dos argumentos passados
				for (int i = 0; i < func->params.size(); ++i) {
					var_info* param = &func->params[i];
					var_info* arg = &args[i];
					
					if (param->type != arg->type) {
						do {
							resType = opMap[param->type + tempOp + arg->type];
							tempOp = typeMap[tempOp];
						} while (resType.empty() && !tempOp.empty());
						
						if (resType.empty()) {
							yyerror("Argument " + to_string(i + 1) 
								+ " of function '" + $1.label + "' expects " 
								+ param->type + ", " + arg->type + " given.");
						}
						
						string var2 = getNextVar();
						decls.push_back(param->type + " " + var2 + ";");

						$$.transl += "\t" + var2 + " = (" + param->type 
							+ ") " + arg->name + ";\n";
					}
				}
				
				string var = getNextVar();
				
				$$.type = func->type;
				$$.label = var;
				
				// monta lista de argumentos para cód. interm.
				for (int i = 0; i < args.size(); ++i) {
					argsStr += args[i].name;
					if (i < args.size() - 1) argsStr += ", ";
				}
				
				decls.push_back($$.type + " " + $$.label + ";");
				$$.transl += "\t" + var + " = " + func->label 
					+ "(" + argsStr + ");\n";
			}
			;
			
FUNC_ARGS	: EXPR ',' FUNC_ARGS {
				$$.transl = $1.transl + $3.transl;
				$$.label = $1.type + " " + $1.label + ";" + $3.label;
				$$.size = $3.size + 1;
			}
			| EXPR {
				$$.transl = $1.transl;
				$$.label = $1.type + " " + $1.label;
				$$.size = 1;
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
					decls.push_back("int " + var[0] + ";");
					decls.push_back("int " + var[1] + ";");
					decls.push_back("int " + var[2] + ";");
					decls.push_back("int " + var[3] + ";");
					
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
					decls.push_back("int " + var + ";");
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
					decls.push_back(type + " " + var + ";");
					$$.transl = $1.transl + 
						"\t" + var + " = (" + $3.transl + ") " + $1.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Invalid cast from " + $1.type + " to " + $3.transl + ".");
				}
			}
			| INCR_OR_DECR
			| FUNC_APPL
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
				
				decls.push_back($1.type + " " + var + ";");
				$$.transl = "\t" + var + " = " + value + ";\n";
				$$.label = var;
			}
			| TK_BOOL {
				string var = getNextVar();
				
				$1.label = ($1.label == "true"? "1" : "0");
				
				decls.push_back("int " + var + ";");
				$$.transl = "\t" + var + " = " + $1.label + ";\n";
				$$.label = var;
			}
			| TK_CHAR {
				string var = getNextVar();
				
				decls.push_back($1.type + " " + var + ";");
				$$.transl = "\t" + var + " = " + $1.label + ";\n";
				$$.label = var;
			}
			| TK_STRING {
				string var = getNextVar();
				
				decls.push_back("char* " + var + ";");
				
				$$.transl = "\t" + var + " = (char*) \"" + $1.label + "\";\n";
				$$.size = $1.label.size();
				$$.label = var;
			}
			| TK_ID {
				var_info* info = findVar($1.label);
				
				if (info != nullptr && info->name.size()) {
					$$.type = info->type;
					$$.label = info->name;
					$$.size = info->size;
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
	cout << "Error on line " << line << ": " << MSG << endl;
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

var_info* findVarOnTop(string label) {
	if (varMap[varMap.size() - 1].count(label)) {
		return &varMap[varMap.size() - 1][label];
	}
	
	return nullptr;
}

void insertVar(string label, var_info info) {
	varMap[varMap.size() - 1][label] = info;
}

func_info* findFunc(string var) {
	if (funcMap.count(var)) {
		return &funcMap[var];
	}
	
	return nullptr;
}

void insertFunc(string var, func_info info) {
	funcs.push_back(info);
	
	funcMap[var] = info;
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

string getNextFunc() {
	return "func" + to_string(tempFunc++);
}

template<typename Out>
void split(const string &s, char delim, Out result) {
    stringstream ss;
    ss.str(s);
    string item;
    while (getline(ss, item, delim)) {
        *(result++) = item;
    }
}

vector<string> split(const string &s, char delim) {
    vector<string> elems;
    split(s, delim, back_inserter(elems));
    return elems;
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
		decls.push_back(resType + " " + var1 + ";");
		
		result.transl += "\t" + var1 + " = (" + 
			resType + ") " + left.label + ";\n";
		
		left.label = var1;
	}
	
	// if right needs conversion
	if (right.type != resType) {
		string var1 = getNextVar();
		decls.push_back(resType + " " + var1 + ";");
		
		result.transl += "\t" + var1 + " = (" + 
			resType + ") " + right.label + ";\n";
		
		right.label = var1;
	}
	
	result.type = resType;
	decls.push_back(result.type + " " + var + ";");
	
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
		decls.push_back(resType + " " + var1 + ";");
		result.transl += "\t" + var1 + " = (" + 
			resType + ") " + left.label + ";\n";
		
		left.label = var1;
	}
	
	if (right.type != resType) {
		string var1 = getNextVar();
		decls.push_back(resType + " " + var1 + ";");
		result.transl += "\t" + var1 + " = (" + 
			resType + ") " + right.label + ";\n";
		
		right.label = var1;
	}

	result.type = "bool";
	decls.push_back("int " + var + ";");
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
	decls.push_back("int " + var + ";");
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
	decls.push_back("char* " + var + ";");
	desacs.push_back(var);
	
	result.transl += 
		"\t" + var + " = (char*) malloc(" + 
		to_string(left.size + right.size) + 
		" * sizeof(char));\n\tstrcpy(" + var + ", " + left.label + 
		");\n\tstrcat(" + var + ", " + right.label + ");\n";
	result.label = var;
	result.size = left.size + right.size;
	
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
			decls.push_back(info->type + " " + var + ";");
			
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
			decls.push_back(info->type + " " + var + ";");
			
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
