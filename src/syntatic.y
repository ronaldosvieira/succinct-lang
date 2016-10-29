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
} var_info;

string type1, type2, op, typeRes, value;
ifstream opMapFile, padraoMapFile;

vector<string> decls;
map<string, string> opMap;
map<string, var_info> varMap;
map<string, string> padraoMap;
int tempGen = 0;

string getNextVar();

int yylex(void);
void yyerror(string);
%}

%token TK_NUM TK_CHAR TK_BOOL
%token TK_AS "as"
%token TK_WRITE "write"
%token TK_MAIN TK_ID TK_INT_TYPE TK_FLOAT_TYPE TK_CHAR_TYPE
%token TK_DOUBLE_TYPE TK_LONG_TYPE TK_STRING_TYPE TK_BOOL_TYPE
%token TK_FIM TK_ERROR
%token TK_BREAK
%token TK_AND "and"
%token TK_OR "or"
%token TK_NOT "not"
%token TK_GTE ">="
%token TK_LTE "<="
%token TK_NEQ "!="
%token TK_EQ "=="

%start S

%nonassoc '<' '>' "<=" ">=" "!=" "=="
%right "not"
%left "and" "or"
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
			};
			
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
						
						varMap[$2.label] = {$1.transl, $4.label};
					} else {
						// throw compile error
						$$.type = "ERROR";
						$$.transl = "ERROR";
					}
				} else {
					// throw compile error
					$$.type = "ERROR";
					$$.transl = "ERROR";
				}
			}
			| TK_ID '=' EXPR {
				if (varMap.count($1.label)) {
					var_info info = varMap[$1.label];
					
					// se tipo da expr for igual a do id
					if (info.type == $3.type) {
						varMap[$1.label] = {info.type, $3.label};
						$$.type = $3.type;
						$$.transl = $3.transl;
						$$.label = $3.label;
					} else {
						string var = getNextVar();
						string resType = opMap[info.type + "=" + $3.type];
						
						// se conversão é permitida
						if (resType.size()) {
							decls.push_back("\t" + info.type + " " + var + ";");
							$$.transl = $3.transl + "\t" + 
								var + " = (" + info.type + ") " + $3.label + ";\n";
							$$.type = info.type;
							$$.label = var;
							
							varMap[$1.label] = {info.type, var};
						} else {
							// throw compile error
							$$.type = "ERROR";
							$$.transl = "ERROR";
						}
					}
				} else {
					// throw compile error
					$$.type = "ERROR";
					$$.transl = "ERROR";
				}
			}
			| TYPE TK_ID {
				if (!varMap.count($2.label)) {
					string var = getNextVar();
					
					varMap[$2.label] = {$1.transl, var};
					
					decls.push_back("\t" + $1.type + " " + var + ";");
					$$.transl = "\t" + var + " = " + 
						padraoMap[$1.transl] + ";\n";
					$$.label = var;
					$$.type = $1.transl;
				} else {
					// throw compile error
					$$.type = "ERROR";
					$$.transl = "ERROR";
				}
			};

EXPR 		: EXPR '+' EXPR {
				string var = getNextVar();
				
				string resType = opMap[$1.type + "+" + $3.type];
				
				if (resType.size()) {
					$$.type = resType;
					decls.push_back("\t" + $$.type + " " + var + ";");
					$$.transl = $1.transl + $3.transl + 
						"\t" + var + " = " + $1.label + " + " + $3.label + ";\n";
					$$.label = var;
				} else {
					// throw compile error
					$$.type = "ERROR";
					$$.transl = "ERROR";
				}
			}
			| EXPR '-' EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "-" + $3.type];
				decls.push_back("\t" + $$.type + " " + var + ";");
				$$.transl = $1.transl + $3.transl + 
					"\t" + var + " = " + $1.label + " - " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR '*' EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "*" + $3.type];
				decls.push_back("\t" + $$.type + " " + var + ";");
				$$.transl = $1.transl + $3.transl + 
					"\t" + var + " = " + $1.label + " * " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR '/' EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "/" + $3.type];
				decls.push_back("\t" + $$.type + " " + var + ";");
				$$.transl = $1.transl + $3.transl + 
					"\t" + var + " = " + $1.label + " / " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR '<' EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "<" + $3.type];
				decls.push_back("\tint " + var + ";");
				$$.transl = $1.transl + $3.transl + 
					"\t" + var + " = " + $1.label + " < " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR '>' EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + ">" + $3.type];
				decls.push_back("\tint " + var + ";");
				$$.transl = $1.transl + $3.transl + 
					"\t" + var + " = " + $1.label + " > " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR "<=" EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "<=" + $3.type];
				decls.push_back("\tint " + var + ";");
				$$.transl = $1.transl + $3.transl + 
					"\t" + var + " = " + $1.label + " <= " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR ">=" EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + ">=" + $3.type];
				decls.push_back("\tint " + var + ";");
				$$.transl = $1.transl + $3.transl + 
					"\t" + var + " = " + $1.label + " >= " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR "==" EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "==" + $3.type];
				decls.push_back("\tint " + var + ";");
				$$.transl = $1.transl + $3.transl + 
					"\t" + var + " = " + $1.label + " == " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR "!=" EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "!=" + $3.type];
				decls.push_back("\tint " + var + ";");
				$$.transl = $1.transl + $3.transl + 
					"\t" + var + " = " + $1.label + " != " + $3.label + ";\n";
				$$.label = var;
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
					yyerror("Error: And operation between non-bool values.");
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
					yyerror("Error: Or operation between non-bool values.");
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
					// throw compile error
					$$.type = "ERROR";
					$$.transl = "ERROR";
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
					$$.type = type;
					decls.push_back("\t" + $$.type + " " + var + ";");
					$$.transl = $1.transl + 
						"\t" + var + " = (" + $3.transl + ") " + $1.label + ";\n";
					$$.label = var;
				} else {
					// throw compile error
					$$.type = "ERROR";
					$$.transl = "ERROR";
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
					$$.type = "ERROR";
					$$.transl = "ERROR";
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
	cout << MSG << endl;
	exit (0);
}

string getNextVar() {
    return "t" + to_string(tempGen++);
}