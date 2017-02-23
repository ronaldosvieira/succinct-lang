%{
#include <string>
%}

/*
ESPACO [ \t]
DIGITO [0-9]
LETRA [A-Za-z_]

DELIM {ESPACO}+
NUM {DIGITO}+
REAL {NUM}+("."{NUM}+)?
CHAR \'({LETRA}|{NUM})\'
ID {LETRA}({LETRA}|{NUM})*
*/

DIGIT		[0-9]
LOWER		[a-z]
UPPER		[A-Z]
LETTER		{LOWER}|{UPPER}
LOALPHA		{LOWER}|{DIGIT}
UPALPHA 	{UPPER}|{DIGIT}
ALPHA		{LETTER}|{DIGIT}
AMPERSAND	&

BREAK		\r?\n
INDENT		\s{4}|\t
/*Alterei o regex do espaço para qualquer quantidade de espaço*/
SPACE		\s{1,3}

INT     	-?{DIGIT}+
FLOAT   	-?{DIGIT}+(\.{DIGIT}*)?([eE][\-\+]?{DIGIT}+)?[fF]
DOUBLE		-?{DIGIT}+(\.{DIGIT}*)?([eE][\-\+]?{DIGIT}+)?[dD]?
LONG		-?{DIGIT}+[lL]
CHAR		\'[^\'\n]\'
STRING	    \"[^\"]*\"
BOOL        "true"|"false"

ID          {LETTER}{ALPHA}*
/* CONST       [{UPALPHA}_\-]*{UPPER}[{UPALPHA}_\-*]* */

COMMBST	    "/*"
COMMBFN     "*/"
COMMB       {COMMBST}[^{COMMBFN}]*{COMMBFN}
COMML	    "//"[^\n]*

%%

{SPACE} 	{}

"main"		{ return TK_MAIN; }

"if"        { return TK_IF; }
"elif"      { return TK_ELIF; }
"else"      { return TK_ELSE; }
"while"     { return TK_WHILE; }
"for"       { return TK_FOR; }
"do"        { return TK_DO; }

"break"     { return TK_BREAK; }
"continue"  { return TK_CONT; }
"all"       { return TK_ALL; }

"write"     { return TK_WRITE; }
"typeof"    { return TK_TYPEOF; }
"is"        { return TK_IS; }
"endl"      { return TK_ENDL; }
"as"        { return TK_AS; }

"return"    { return TK_RET; }

":"         { return TK_BSTART; }

"int"		{ 
                yylval.transl = yytext; 
                yylval.type = "type";
                return TK_INT_TYPE;
            }
"float"		{ 
                yylval.transl = yytext; 
                yylval.type = "type";
                return TK_FLOAT_TYPE;
            }
"double"	{ 
                yylval.transl = yytext; 
                yylval.type = "type";
                return TK_DOUBLE_TYPE;
            }
"long"		{ 
                yylval.transl = yytext; 
                yylval.type = "type";
                return TK_LONG_TYPE;
            }
"char"		{ 
                yylval.transl = yytext; 
                yylval.type = "type";
                return TK_CHAR_TYPE;
            }
"string"	{ 
                yylval.transl = yytext; 
                yylval.type = "type";
                return TK_STRING_TYPE;
            }
"bool"      { 
                yylval.transl = yytext; 
                yylval.type = "type";
                return TK_BOOL_TYPE;
            }
"func"      { 
                yylval.transl = yytext; 
                yylval.type = "type";
                return TK_FUNC_TYPE;
            }
"const"     { yylval.transl = yytext; return TK_CONST; }
"auto"      { yylval.transl = yytext; return TK_AUTO_TYPE; }

[(){}[\];,]	{ return *yytext; }

[+\-*/=><]	{ return *yytext; }

"=="|"eq"|"equals"  { return TK_EQ; }
"!="|"neq"  { return TK_NEQ; }
">="|"gte"  { return TK_GTE; }
"<="|"lte"  { return TK_LTE; }
"&&"|"and"  { return TK_AND; }
"||"|"or"   { return TK_OR; }
"xor"       { return TK_XOR; }
"!"|"not"   { return TK_NOT; }

"++"        { return TK_INCR; }
"--"        { return TK_DECR; }

"->"        { return TK_ARROW; }

{INT}		{
    yylval.transl = "";
    yylval.label = yytext;
    yylval.type = "int";
    return TK_NUM;
}

{DOUBLE}    { 
    yylval.transl = "";
    yylval.label = yytext;
    yylval.type = "double";
    return TK_NUM;
}

{FLOAT}     { 
    yylval.transl = "";
    yylval.label = yytext;
    yylval.type = "float";
    return TK_NUM;
}

{CHAR}      {
    yylval.transl = "";
    yylval.label = yytext;
    yylval.type = "char";
    return TK_CHAR;
}

{STRING}    {
    string label = yytext;
    
    label.replace(label.begin(), label.begin() + 1, "");
	label.replace(label.end() - 1, label.end(), "");
	
    yylval.transl = "";
    yylval.label = label;
    yylval.type = "string";
    return TK_STRING;
}

{BOOL}      {
    yylval.transl = "";
    yylval.label = yytext;
    yylval.type = "bool";
    return TK_BOOL;
}

{ID}		{
    yylval.label = yytext;
    return TK_ID;
}

{BREAK}		{++line;}

{COMML}     {}

.			{*yytext;}

%%