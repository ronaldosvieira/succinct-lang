all: 
	clear
	flex -o bin/lex.yy.c src/lexical.l
	yacc -o bin/y.tab.c -d src/syntatic.y
	g++ bin/y.tab.c -o bin/suc -Iinclude/ -ll -std=c++11

	./bin/suc < examples/conditional_example.su

	