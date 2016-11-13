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
map<string, string> opMap;
map<string, var_info> varMap;
map<string, string> padraoMap;
int tempGen = 0;
int tempLabel = 0;

string getNextVar();
string getNextLabel();

int yylex(void);
void yyerror(string);
%}

%token TK_NUM TK_CHAR TK_BOOL
%token TK_IF "if"
%token TK_WHILE "while"
%token TK_AS "as"
%token TK_WRITE "write"
%token TK_CONST "const"
%token TK_MAIN TK_ID TK_INT_TYPE TK_FLOAT_TYPE TK_CHAR_TYPE
%token TK_DOUBLE_TYPE TK_LONG_TYPE TK_STRING_TYPE TK_BOOL_TYPE
%token TK_FIM TK_ERROR
%token TK_BREAK TK_BSTART
%token TK_AND "and"
%token TK_OR "or"
%token TK_XOR "xor"
%token TK_NOT "not"
%token TK_GTE ">="
%token TK_LTE "<="
%token TK_NEQ "!="
%token TK_EQ "=="

%start S

%nonassoc '<' '>' "<=" ">=" "!=" "=="
%right "not"
%left "and" "or" "xor"
%left '+' '-'
%left '*' '/'
%left "as"

%%

S 			: TK_INT_TYPE TK_MAIN '(' ')' BLOCK {
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
				$5.transl << 
				"\treturn 0;\n}" << endl;
			};

BLOCK		: '{' STATEMENTS '}' {
				$$.transl = $2.transl;
			};

STATEMENTS	: STATEMENT STATEMENTS {
				$$.transl = $1.transl + "\n" + $2.transl;
			}
			| STATEMENT {
				$$.transl = $1.transl + "\n";
			};

STATEMENT 	: EXPR ';' {
				$$.transl = $1.transl;
			}
			| ATTRIBUTION ';' {
				$$.transl = $1.transl;
			}
			| WRITE ';' {
				$$.transl = $1.transl;
			}
			| CONTROL;
			
CONTROL		: "if" EXPR TK_BSTART BLOCK {
				if ($2.type == "bool") {
					string end = getNextLabel();
					
					$$.transl = $2.transl + 
						"\t" + $2.label + " = !" + $2.label + ";\n" +
						"\tif (" + $2.label + ") goto " + end + ";\n" +
						$4.transl +
						"\t" + end + ":\n";
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
						"\tif (" + $2.label + ") goto " + end + ";\n" +
						$4.transl +
						"\tgoto " + begin + ";\n\t" + end + ":\n";
				} else {
					// throw compile error
					yyerror("Non-bool expression on while condition.");
				}
			}
			;
			
WRITE		: "write" EXPR {
				string format, label;
				
				$$.transl = $2.transl;
				label = $2.label;
				
				if ($2.type == "int") format = "%d";
				else if ($2.type == "float") format = "%f";
				else if ($2.type == "double") format = "%lf";
				else if ($2.type == "char") format = "%c";
				else if ($2.type == "bool") {
					decls.push_back("\tchar *_bool_" + $2.label + ";");
					$$.transl += "\tif (" + $2.label + ") strcpy(_bool_" + $2.label + ", \"true\");\n";
					$$.transl += "\telse strcpy(_bool_" + $2.label + ", \"false\");\n";
					
					format = "%s";
					label = "_bool_" + $2.label;
				}
				
				$$.transl += "\tprintf(\"" + format + "\\n\", " + label + ");\n";
			};
			
ATTRIBUTION	: TYPE TK_ID '=' EXPR {
				if (!varMap.count($2.label)) {
					if ($4.type == $1.transl) {
						$$.transl = $4.transl;
						
						varMap[$2.label] = {$1.transl, $4.label, true};
					} else {
						// throw compile error
						yyerror("Variable assignment with incompatible types " 
							+ $4.type + " and " + $1.transl + ".");
					}
				} else {
					// throw compile error
					yyerror("Variable " + $2.label + " redeclared.");
				}
			}
			| "const" TYPE TK_ID '=' EXPR {
				if (!varMap.count($3.label)) {
					if ($5.type == $2.transl) {
						$$.transl = $5.transl;
						
						varMap[$3.label] = {$2.transl, $5.label, false};
					} else {
						// throw compile error
						yyerror("Variable assignment with incompatible types " 
							+ $5.type + " and " + $2.transl + ".");
					}
				} else {
					// throw compile error
					yyerror("Variable " + $3.label + " redeclared.");
				}
			}
			| TK_ID '=' EXPR {
				if (varMap.count($1.label)) {
					var_info info = varMap[$1.label];
					
					if (!info.isMutable) {
						yyerror("Assignment on constant variable " + $1.label +  ".");
					}
					
					// se tipo da expr for igual a do id
					if (info.type == $3.type) {
						//varMap[$1.label] = {info.type, $3.label, true};
						$$.type = $3.type;
						//$$.transl = $3.transl;
						$$.transl = $3.transl + "\t" + info.name + " = " + $3.label + ";\n";
						$$.label = $3.label;
					} else {
						string var = getNextVar();
						string resType = opMap[info.type + "=" + $3.type];
						
						// se conversão é permitida
						if (resType.size()) {
							decls.push_back("\t" + info.type + " " + var + ";");
							$$.transl = $3.transl + "\t" + 
								var + " = (" + info.type + ") " + $3.label + ";\n\t" +
								info.name + " = " + var + ";\n";
							$$.type = info.type;
							$$.label = var;
							
							//varMap[$1.label] = {info.type, var};
						} else {
							// throw compile error
							yyerror("Variable assignment with incompatible types " 
								+ info.type + " and " + $3.type + ".");
						}
					}
				} else {
					// throw compile error
					yyerror("Variable " + $1.label + " not declared.");
				}
			}
			| TYPE TK_ID {
				if (!varMap.count($2.label)) {
					string var = getNextVar();
					
					varMap[$2.label] = {$1.transl, var, true};
					
					decls.push_back("\t" + $1.type + " " + var + ";");
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
				var_info varInfo = varMap[$1.label];
				
				if (varInfo.name.size()) {
					$$.type = varInfo.type;
					$$.label = varInfo.name;
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

	yyparse();

	return 0;
}

void yyerror( string MSG ) {
	cout << "Error: " << MSG << endl;
	exit (0);
}

string getNextVar() {
    return "t" + to_string(tempGen++);
}

string getNextLabel() {
	return "label" + to_string(tempLabel++);
}