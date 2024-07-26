.globl original_brk
.globl topo_pilha
.section .data 
    original_brk: .quad 0
    topo_pilha: .quad 0
    tamanho_do_novo_bloco: .quad 0
.section .text

.globl setup_brk
.globl memory_alloc
.globl dismiss_brk
.globl memory_free

# obtém endereço do brk
setup_brk:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax    # Número da chamada de sistema para brk
    movq $0, %rdi     # Novo endereço de brk (0 para obter o atual)
    syscall

    movq %rax, original_brk
    movq %rax, topo_pilha
    popq %rbp
    ret

merge_block:
    pushq %rbp
    movq %rsp, %rbp

    movq original_brk, %r8

    # percorre todos os blocos da heap 
    _while_merge:
        cmpq $1, (%r8)
        je _itera_merge

        # r10 contém o tamanho do bloco
        movq 8(%r8), %r10
        # colocando o endereço que estamos em r11
        movq %r8, %r11
        # pulando a header
        addq $16, %r11
        # pulando para o próximo bloco
        addq %r10, %r11

        cmpq topo_pilha, %r11
        ja _itera_merge
       
        cmpq $1, (%r11)
        je _itera_merge

        # adicionando o tamanho do bloco 2 no 1
        addq 8(%r11), %r10
        # somando o tamanho da header
        addq $16, %r10

        movq %r10, 8(%r8)
        
        _itera_merge:
        # pega o tamanho do bloco e coloca em %r9
        movq 8(%r8), %r9
        # avança o ponteiro para o próximo bloco
        addq %r9, %r8
        addq $16, %r8
        
        cmpq topo_pilha, %r8
        ja _fim_merge
        jmp _while_merge
        
    _fim_merge:
    popq %rbp
    ret

# volta o brk para o valor original, zera a heap
dismiss_brk:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax
    movq original_brk, %rdi
    syscall

    movq %rax, original_brk
    movq %rax, topo_pilha
    popq %rbp
    ret

memory_free:
    pushq %rbp
    movq %rsp, %rbp

    movq $0, -16(%rdi)    # Marca o bloco como livre

    call merge_block

    popq %rbp
    ret

# Se não encontrar, abre espaço para um novo bloco
open_space:
    pushq %rbp
    movq %rsp, %rbp

    # salvando o tamanho do bloco
    movq %rdi, %r8

    addq $16, %rdi
    # atualizando topo da pilha
    movq topo_pilha, %rax
    addq %rdi, %rax
    movq %rax, %rdi
    movq $12, %rax
    syscall
    movq %rax, topo_pilha

    # retorna o começo do bloco sem o header
    subq %r8, %rax
    
    movq $1, (%rax)
    movq %r8, 8(%rax)

    popq %rbp
    ret

add_info: 
    pushq %rbp
    movq %rsp, %rbp

    movq %rdi, %r8
    subq (%rdi), %r15

    cmpq $16, %r15
    jl _soh_enfiar

    # nova header
    movq %r10, %r14
    addq $16, %r14
    addq (%rdi), %r14

    movq $0, (%r14)
    movq %r15, 8(%r14)

    _soh_enfiar:
        # lembrando que em r10 temos o endereço do bloco que achamos
        movq $1, (%r10)
        # r13 só para poder acessar o valor já que não pode acessar duas memórias
        movq %r12, %r13
        movq %r13, 8(%r10)

    popq %rbp
    ret

# Procura bloco livre com tamanho igual ou maior que a requisição
search_block:
    pushq %rbp
    movq %rsp, %rbp

    movq original_brk, %r13

    cmpq %r13, topo_pilha    
    je _n_call

    movq original_brk, %r8

    # r12 é o tamanho atual
    movq $0, %r12

    # percorre todos os blocos da heap 
    _while_search:
        # verifica se o bloco está ocupado
        cmpq $1, (%r8)
        je _itera_search

        # compara o tamanho dos blocos
        cmpq %r12, 8(%r8)
        jl _itera_search
        
        # se o tamanho for maior atualiza o valor
        movq 8(%r8), %r12
        # guarda o endereço do bloco em r10
        movq %r8, %r10

        _itera_search:
        # pega o tamanho do bloco e coloca em %r9
        movq 8(%r8), %r9
        # avança o ponteiro para o próximo bloco
        addq %r9, %r8
        addq $16, %r8
        
        cmpq topo_pilha, %r8
        ja _fim_search
        jmp _while_search
        
    _fim_search:

    # se não tiver bloco alocado livre chama a função de abrir
    cmpq $0, %r12
    je _n_call

    call add_info
    jmp _cu

    # temos o bloco 
    _n_call:
        call open_space

    _cu:
    popq %rbp
    ret

memory_alloc:
    pushq %rbp
    movq %rsp, %rbp

    # tamanho do bloco(parâmetro) em %rdi
    call search_block 

    popq %rbp
    ret
