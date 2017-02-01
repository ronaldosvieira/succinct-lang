%{
#include <iostream>
#include <string>
#include <sstream>
#include <map>
#include <fstream>
#include <vector>
#include <algorithm>

#define YYSTYPE attributes

using namespace std;

struct attributes {
	string label; // nome da variável usada no cód. intermediário (ex: "t0")
	string type; // tipo no código intermediário (ex: "int")
	string transl; // código intermediário (ex: "int t11 = 1;")
};

typedef struct var_info {
	string type; // tipo da variável usada no cód. intermediário (ex: "int")
	string name; // nome da variável usada no cód. intermediário (ex: "t0")
	bool isMutable; // se variável é constante ou não
} var_info;

string type1, type2, op, typeRes, value;
ifstream opMapFile, padraoMapFile;

vector<string> decls;
vector<map<string, var_info>> varMap;
map<string, string> opMap;
map<string, string> padraoMap;
int tempGen = 0;
int tempLabel = 0;

string getNextVar();
string getNextLabel();

void pushContext();
void popContext();

var_info* findVar(string label);
void insertVar(string label, var_info info);

int yylex(void);
void yyerror(string);
%}

%token TK_NUM TK_CHAR TK_BOOL
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
%token TK_BREAK TK_BSTART
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
				"int main(void) {" << endl;
				
				for (string decl : decls) {
					cout << decl << endl;
				}
				
				cout << "\n" << 
				$1.transl << 
				"\treturn 0;\n}" << endl;
			};
			
PUSH_SCOPE: {
				pushContext();
				
				$$.transl = "";
				$$.label = "";
			}
			
POP_SCOPE:	{
				popContext();
				
				$$.transl = "";
				$$.label = "";
			}

BLOCK		: PUSH_SCOPE '{' STATEMENTS '}' POP_SCOPE {
				$$.transl = $3.transl;
			};

STATEMENTS	: STATEMENT STATEMENTS {
				$$.transl = $1.transl + "\n" + $2.transl;
			}
			| { $$.transl = ""; }
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
			| "while" EXPR TK_BSTART BLOCK {
				if ($2.type == "bool") {
					string var = getNextVar();
					string begin = getNextLabel();
					string end = getNextLabel();
					
					decls.push_back("\tint " + var + ";");
					
					$$.transl = $2.transl + 
						begin + ":\t" + var + " = !" + $2.label + ";\n" +
						"\tif (" + var + ") goto " + end + ";\n" +
						$4.transl +
						"\tgoto " + begin + ";\n\t" + end + ":\n";
				} else {
					// throw compile error
					yyerror("Non-bool expression on while condition.");
				}
			}
			| "do" BLOCK "while" EXPR ';' {
				if ($4.type == "bool") {
					string begin = getNextLabel();
					
					$$.transl = begin + ":" + $2.transl
						+ $4.transl + "\tif (" 
						+ $4.label + ") goto " + begin + ";\n";
				} else {
					// throw compile error
					yyerror("Non-bool expression on do-while condition.");
				}
			}
			| "for" DECL_OR_ATTR ';' EXPR ';' ATTRIBUTION TK_BSTART BLOCK {
				if ($4.type == "bool") {
					string var = getNextVar();
					string begin = getNextLabel();
					string end = getNextLabel();
					
					decls.push_back("\tint " + var + ";");
					
					$$.transl = $2.transl + begin + ":" + $4.transl + 
						"\t" + var + " = !" + $4.label + ";\n" +
						"\tif (" + var + ") goto " + end + ";\n" +
						$8.transl + $6.transl +
						"\tgoto " + begin + ";\n\t" + 
						end + ":\n";
				} else {
					// throw compile error
					yyerror("Non-bool expression on for condition.");
				}
			}
			;
			
WRITE		: "write" WRITE_ARGS {
				$$.transl = "\tstd::cout" + $2.transl + ";\n";
			};
		
WRITE_ARGS	: WRITE_ARG WRITE_ARGS {
				$$.transl = $1.transl + $2.transl;
			}
			| WRITE_ARG { $$.transl = $1.transl; };
			
WRITE_ARG	: EXPR { $$.transl = " << " + $1.label; }
			| TK_ENDL { $$.transl = " << std::endl"; }
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
				var_info* info = findVar($1.label);
				
				if (info != nullptr) {
					if (!info->isMutable) {
						yyerror("Assignment on constant variable " + $1.label +  ".");
					}
					
					// se tipo da expr for igual a do id
					if (info->type == $3.type) {
						//varMap[$1.label] = {info.type, $3.label, true};
						$$.type = $3.type;
						//$$.transl = $3.transl;
						$$.transl = $3.transl + "\t" + info->name + " = " + $3.label + ";\n";
						$$.label = $3.label;
					} else {
						string var = getNextVar();
						string resType = opMap[info->type + "=" + $3.type];
						
						// se conversão é permitida
						if (resType.size()) {
							decls.push_back("\t" + info->type + " " + var + ";");
							$$.transl = $3.transl + "\t" + 
								var + " = (" + info->type + ") " + $3.label + ";\n\t" +
								info->name + " = " + var + ";\n";
							$$.type = info->type;
							$$.label = var;
							
							//varMap[$1.label] = {info.type, var};
						} else {
							// throw compile error
							yyerror("Variable assignment with incompatible types " 
								+ info->type + " and " + $3.type + ".");
						}
					}
				} else {
					// throw compile error
					yyerror("Variable " + $1.label + " not declared.");
				}
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
				string var = getNextVar();
				string resType = opMap[$1.type + "arit" + $3.type];
				
				if (resType.size()) {
					$$.transl = $1.transl + $3.transl;
					
					if ($1.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $1.label + ";\n";
						
						$1.label = var1;
					}
					
					if ($3.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $3.label + "\n";
						
						$3.label = var1;
					}
					
					$$.type = resType;
					decls.push_back("\t" + $$.type + " " + var + ";");
					$$.transl += "\t" + var + " = " + 
						$1.label + " + " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compile error
					yyerror("Arithmetic operation between types " 
					+ $1.type + " and " + $3.type + " is not defined.");
				}
			}
			| EXPR '-' EXPR {
				string var = getNextVar();
				string resType = opMap[$1.type + "arit" + $3.type];
				
				if (resType.size()) {
					$$.transl = $1.transl + $3.transl;
					
					if ($1.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $1.label + ";\n";
						
						$1.label = var1;
					}
					
					if ($3.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $3.label + "\n";
						
						$3.label = var1;
					}
					
					$$.type = resType;
					decls.push_back("\t" + $$.type + " " + var + ";");
					$$.transl += "\t" + var + " = " + 
						$1.label + " - " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Arithmetic operation between types " 
					+ $1.type + " and " + $3.type + " is not defined.");
				}
			}
			| EXPR '*' EXPR {
				string var = getNextVar();
				string resType = opMap[$1.type + "arit" + $3.type];
				
				if (resType.size()) {
					$$.transl = $1.transl + $3.transl;
					
					if ($1.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $1.label + ";\n";
						
						$1.label = var1;
					}
					
					if ($3.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $3.label + "\n";
						
						$3.label = var1;
					}
					
					$$.type = resType;
					decls.push_back("\t" + $$.type + " " + var + ";");
					$$.transl += "\t" + var + " = " + 
						$1.label + " * " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Arithmetic operation between types " 
					+ $1.type + " and " + $3.type + " is not defined.");
				}
			}
			| EXPR '/' EXPR {
				string var = getNextVar();
				string resType = opMap[$1.type + "arit" + $3.type];
				
				if (resType.size()) {
					$$.transl = $1.transl + $3.transl;
					
					if ($1.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $1.label + ";\n";
						
						$1.label = var1;
					}
					
					if ($3.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $3.label + "\n";
						
						$3.label = var1;
					}
					
					$$.type = resType;
					decls.push_back("\t" + $$.type + " " + var + ";");
					$$.transl += "\t" + var + " = " + 
						$1.label + " / " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Arithmetic operation between types " 
					+ $1.type + " and " + $3.type + " is not defined.");
				}
			}
			| EXPR '<' EXPR {
				string var = getNextVar();
				string resType = opMap[$1.type + "rel" + $3.type];
				
				if (resType.size()) {
					$$.transl = $1.transl + $3.transl;
					
					if ($1.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $1.label + ";\n";
						
						$1.label = var1;
					}
					
					if ($3.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $3.label + "\n";
						
						$3.label = var1;
					}
				
					$$.type = "bool";
					decls.push_back("\tint " + var + ";");
					$$.transl += "\t" + var + " = " + 
						$1.label + " < " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Relational operation between non-bools.");
				}
			}
			| EXPR '>' EXPR {
				string var = getNextVar();
				string resType = opMap[$1.type + "rel" + $3.type];
				
				if (resType.size()) {
					$$.transl = $1.transl + $3.transl;
					
					if ($1.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $1.label + ";\n";
						
						$1.label = var1;
					}
					
					if ($3.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $3.label + "\n";
						
						$3.label = var1;
					}
				
					$$.type = "bool";
					decls.push_back("\tint " + var + ";");
					$$.transl += "\t" + var + " = " + 
						$1.label + " > " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Relational operation between non-bools.");
				}
			}
			| EXPR "<=" EXPR {
				string var = getNextVar();
				string resType = opMap[$1.type + "rel" + $3.type];
				
				if (resType.size()) {
					$$.transl = $1.transl + $3.transl;
					
					if ($1.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $1.label + ";\n";
						
						$1.label = var1;
					}
					
					if ($3.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $3.label + "\n";
						
						$3.label = var1;
					}
				
					$$.type = "bool";
					decls.push_back("\tint " + var + ";");
					$$.transl += "\t" + var + " = " + 
						$1.label + " <= " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Relational operation between non-bools.");
				}
			}
			| EXPR ">=" EXPR {
				string var = getNextVar();
				string resType = opMap[$1.type + "rel" + $3.type];
				
				if (resType.size()) {
					$$.transl = $1.transl + $3.transl;
					
					if ($1.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $1.label + ";\n";
						
						$1.label = var1;
					}
					
					if ($3.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $3.label + "\n";
						
						$3.label = var1;
					}
				
					$$.type = "bool";
					decls.push_back("\tint " + var + ";");
					$$.transl = $1.transl + $3.transl + 
						"\t" + var + " = " + $1.label + " >= " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Relational operation between non-bools.");
				}
			}
			| EXPR "==" EXPR {
				string var = getNextVar();
				string resType = opMap[$1.type + "rel" + $3.type];
				
				if (resType.size()) {
					$$.transl = $1.transl + $3.transl;
					
					if ($1.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $1.label + ";\n";
						
						$1.label = var1;
					}
					
					if ($3.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $3.label + "\n";
						
						$3.label = var1;
					}
				
					$$.type = "bool";
					decls.push_back("\tint " + var + ";");
					$$.transl = $1.transl + $3.transl + 
						"\t" + var + " = " + $1.label + " == " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Relational operation between non-bools.");
				}
			}
			| EXPR "!=" EXPR {
				string var = getNextVar();
				string resType = opMap[$1.type + "rel" + $3.type];
				
				if (resType.size()) {
					$$.transl = $1.transl + $3.transl;
					
					if ($1.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $1.label + ";\n";
						
						$1.label = var1;
					}
					
					if ($3.type != resType) {
						string var1 = getNextVar();
						decls.push_back("\t" + resType + " " + var1 + ";");
						$$.transl += "\t" + var1 + " = (" + 
							resType + ") " + $3.label + "\n";
						
						$3.label = var1;
					}
				
					$$.type = "bool";
					decls.push_back("\tint " + var + ";");
					$$.transl = $1.transl + $3.transl + 
						"\t" + var + " = " + $1.label + " != " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Relational operation between non-bools.");
				}
			}
			| EXPR "and" EXPR {
				string var = getNextVar();
				
				if ($1.type == "bool" && $3.type == "bool") {
					$$.type = "bool";
					decls.push_back("\tint " + var + ";");
					$$.transl = $1.transl + $3.transl + 
					"\t" + var + " = " + $1.label + " && " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Logic operation between non-bool values.");
				}
			}
			| EXPR "or" EXPR {
				string var = getNextVar();
				
				if ($1.type == "bool" && $3.type == "bool") {
					$$.type = "bool";
					decls.push_back("\tint " + var + ";");
					$$.transl = $1.transl + $3.transl + 
						"\t" + var + " = " + $1.label + " || " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compiler error
					yyerror("Logic operation between non-bool values.");
				}
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
			| VALUE_OR_ID;
			
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

int yyparse();

int main(int argc, char* argv[]) {
	/*#ifdef YYDEBUG
	    extern int yydebug;
	    yydebug = 1;
	#endif*/

	opMapFile.open("util/opmap.dat");
	padraoMapFile.open("util/default.dat");
	
	if (opMapFile.is_open()) {
		while (opMapFile >> type1 >> op >> type2 >> typeRes) {
	    	opMap[type1 + op + type2] = typeRes;
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

string getNextVar() {
    return "t" + to_string(tempGen++);
}

string getNextLabel() {
	return "lbl" + to_string(tempLabel++);
}