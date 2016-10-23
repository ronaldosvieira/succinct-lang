%{
#include <iostream>
#include <string>
#include <sstream>
#include <map>
#include <fstream>
#include <vector>

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

map<string, string> opMap;
map<string, var_info> varMap;
map<string, string> padraoMap;
int tempGen = 0;

string getNextVar();

int yylex(void);
void yyerror(string);
%}

%token TK_NUM TK_WRITE TK_CHAR TK_BOOL
%token TK_MAIN TK_ID TK_INT_TYPE TK_FLOAT_TYPE TK_CHAR_TYPE
%token TK_DOUBLE_TYPE TK_LONG_TYPE TK_STRING_TYPE TK_BOOL_TYPE
%token TK_FIM TK_ERROR
%token TK_BREAK
%token TK_AND "and"
%token TK_OR "or"
%token TK_GTE ">="
%token TK_LTE "<="
%token TK_NOT "!="
%token TK_EQ "=="

%start S

%left '+' '-'
%left '*' '/'
%left '<' '>' "<=" ">="
%left "!=" "=="
%left "and" "or"

%%

S 			: TK_INT_TYPE TK_MAIN '(' ')' BLOCK {
				cout << 
				"/* Succinct lang */" << endl <<
				"#include <iostream>" << endl <<
				"#include <string.h>" << endl <<
				"#include <stdio.h>" << endl <<
				"int main(void) {" << endl <<
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
			
WRITE		: TK_WRITE '(' EXPR ')' {
				string format, label;
				
				$$.transl = "";
				label = $3.label;
				
				if ($3.type == "int") format = "%d";
				else if ($3.type == "float") format = "%f";
				else if ($3.type == "double") format = "%lf";
				else if ($3.type == "char") format = "%c";
				else if ($3.type == "bool") {
					$$.transl += "\tchar *_bool" + $3.label + ";";
					$$.transl += "\tif (" + $3.label + ") *_bool" + $3.label + " = \"true\";";
					$$.transl += "\telse *_bool" + $3.label + " = \"false\";";
					
					format = "%d";
					label = "_bool" + $3.label;
				}
				
				$$.transl += $3.transl + "\tprintf(\"" + format + "\", " + label + ");\n";
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
							$$.transl = $3.transl + "\t" + info.type + " " + 
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
					
					$$.transl = "\t" + $1.transl + " " + $2.label + " = " + 
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
					$$.transl = $1.transl + $3.transl + 
						"\t" + $$.type + " " + var + " = " + $1.label + " + " + $3.label + ";\n";
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
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " - " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR '*' EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "*" + $3.type];
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " * " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR '/' EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "/" + $3.type];
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " / " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR '<' EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "<" + $3.type];
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " < " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR '>' EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + ">" + $3.type];
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " > " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR "<=" EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "<=" + $3.type];
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " <= " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR ">=" EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + ">=" + $3.type];
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " >= " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR "==" EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "==" + $3.type];
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " == " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR "!=" EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "!=" + $3.type];
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " != " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR "and" EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "&&" + $3.type];
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " && " + $3.label + ";\n";
				$$.label = var;
			}
			| EXPR "or" EXPR {
				string var = getNextVar();
				
				$$.type = opMap[$1.type + "||" + $3.type];
				$$.transl = $1.transl + $3.transl + 
					"\t" + $$.type + " " + var + " = " + $1.label + " || " + $3.label + ";\n";
				$$.label = var;
			}
			| '(' TYPE ')' VALUE_OR_ID {
				string var = getNextVar();
				string type = opMap[$2.transl + "cast" + $4.type];
				
				if (type.size()) {
					$$.type = type;
					$$.transl = $4.transl + 
						"\t" + $$.type + " " + var + " = (" + $2.transl + ") " + $4.label + ";\n";
					$$.label = var;
				} else {
					// throw compile error
					$$.type = "ERROR";
					$$.transl = "ERROR";
				}
			}
			| VALUE_OR_ID;
			
TYPE		: TK_INT_TYPE
			| TK_FLOAT_TYPE
			| TK_DOUBLE_TYPE
			| TK_LONG_TYPE
			| TK_CHAR_TYPE
			| TK_STRING_TYPE
			| TK_BOOL_TYPE
			;
			
VALUE_OR_ID	: TK_NUM {
				string var = getNextVar();
				
				$$.transl = "\t" + $1.type + " " + var + " = " + $1.label + ";\n";
				$$.label = var;
			}
			| TK_BOOL {
				string var = getNextVar();
				
				$1.label = ($1.label == "true"? "1" : "0");
				
				$$.transl = "\tint " + var + " = " + $1.label + ";\n";
				$$.label = var;
			}
			| TK_CHAR {
				string var = getNextVar();
				
				$$.transl = "\t" + $1.type + " " + var + " = " + $1.label + ";\n";
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