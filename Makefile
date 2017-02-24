all: 
	test -s ./bin || { mkdir ./bin; }
	clear
	flex -o bin/lex.yy.c src/lexical.l
	yacc -o bin/y.tab.c -d src/syntatic.y
	g++ bin/y.tab.c -o bin/suc -Iinclude/ -lfl -std=c++11

	./bin/suc < examples/example1.su

clean:
	rm -rf ./bin
	clear

exec:
	test -s ./bin || { mkdir ./bin; }
	clear
	flex -o bin/lex.yy.c src/lexical.l
	yacc -o bin/y.tab.c -d src/syntatic.y
	g++ bin/y.tab.c -o bin/suc -Iinclude/ -lfl -std=c++11

	./bin/suc < examples/example1.su > compiled.cpp

	g++ compiled.cpp -o compiled
	./compiled
