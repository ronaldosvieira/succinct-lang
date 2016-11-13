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
INDENT		" "{4}|\t
/*Alterei o regex do espaço para qualquer quantidade de espaço*/
SPACE		[" "]{1,3}

INT     	{DIGIT}+
FLOAT   	{DIGIT}+(\.{DIGIT}*)?([eE][\-\+]?{DIGIT}+)?[fF]
DOUBLE		{DIGIT}+(\.{DIGIT}*)?([eE][\-\+]?{DIGIT}+)?[dD]?
LONG		{DIGIT}+[lL]
CHAR		\'[^\'\n]\'
STRING		\'[^\'\n]+\'|\"[^\'\n]+\"
BOOL        "true"|"false"

ID          {ALPHA}{ALPHA}*
/* CONST       [{UPALPHA}_\-]*{UPPER}[{UPALPHA}_\-*]* */

COMMBST	    "/*"
COMMBFN     "*/"
COMMB       {COMMBST}[^{COMMBFN}]*{COMMBFN}
COMML	    "//".*\n

%%

{SPACE} 	{}

"main"		{ return TK_MAIN; }

"write"     { return TK_WRITE; }
"as"        { return TK_AS; }

"int"		{ yylval.transl = yytext; return TK_INT_TYPE; }
"float"		{ yylval.transl = yytext; return TK_FLOAT_TYPE; }
"double"	{ yylval.transl = yytext; return TK_DOUBLE_TYPE; }
"long"		{ yylval.transl = yytext; return TK_LONG_TYPE; }
"char"		{ yylval.transl = yytext; return TK_CHAR_TYPE; }
"string"	{ yylval.transl = yytext; return TK_STRING_TYPE; }
"bool"      { yylval.transl = yytext; return TK_BOOL_TYPE; }
"const"     { yylval.transl = yytext; return TK_CONST; }

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

{BOOL}      {
    yylval.transl = "";
    yylval.label = yytext;
    yylval.type = "bool";
    return TK_BOOL;
}

{ID}		{ yylval.label = yytext; return TK_ID; }

{BREAK}		{}

.			{ *yytext; }

%%