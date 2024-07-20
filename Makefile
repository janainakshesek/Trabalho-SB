CC = gcc
CFLAGS = -g -Wall -no-pie -g
PROG = main

all: $(PROG)

$(PROG): main.o heap.o
	$(CC) $(CFLAGS) -o $(PROG) main.o heap.o 

main.o: main.c
	$(CC) $(CFLAGS) -c main.c -o main.o

heap.o: heap.s
	as heap.s -o heap.o -g

purge:
	rm -rf *.o  $(PROG) 