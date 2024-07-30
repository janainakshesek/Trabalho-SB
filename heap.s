.globl original_brk
.globl stack_top
.section .data 
    original_brk: .quad 0
    stack_top: .quad 0
.section .text

.globl setup_brk
.globl memory_alloc
.globl dismiss_brk
.globl memory_free

# obtém endereço do brk
setup_brk:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax
    movq $0, %rdi
    syscall

    movq %rax, original_brk
    movq %rax, stack_top
    popq %rbp
    ret

# Função de unir dois blocos não ocupados - não utilizamos
merge_block:
    pushq %rbp
    movq %rsp, %rbp

    movq original_brk, %r8

    # percorre todos os blocos da heap 
    _while_merge:
        cmpq $1, (%r8)
        je _iterate_merge

        # r10 contém o tamanho do bloco
        movq 8(%r8), %r10
        # colocando o endereço que estamos em r11
        movq %r8, %r11
        # pulando a header
        addq $16, %r11
        # pssando pro próximo bloco
        addq %r10, %r11

        cmpq stack_top, %r11
        je _iterate_merge
       
        cmpq $1, (%r11)
        je _iterate_merge

        # adicionando o tamanho do bloco 2 no 1
        addq 8(%r11), %r10
        # somando o tamanho da header
        addq $16, %r10

        movq %r10, 8(%r8)
        
        _iterate_merge:
        movq 8(%r8), %r9
        addq %r9, %r8
        addq $16, %r8
        
        cmpq stack_top, %r8
        je _end_merge
    _end_merge:

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
    movq %rax, stack_top
    popq %rbp
    ret

memory_free:
    pushq %rbp
    movq %rsp, %rbp

    # compara se o endereço que está em rdi é menor ao brk original, se for, é inválido
    cmpq original_brk, %rdi
    jl _error

    # tentativa de desalocação acima do que fizemos 
    cmpq stack_top, %rdi
    jge _error

    # zera o bloco, 0 na header
    movq $0, -16(%rdi)
    jmp _end_free

    _error:
    # retorna 0 em caso de erro
    movq $0, %rax

    _end_free:

    popq %rbp
    ret

# Se não encontrar, abre espaço para um novo bloco
open_space:
    pushq %rbp
    movq %rsp, %rbp

    # salvando o tamanho do bloco
    movq %rdi, %r8
    # passa o tamanho da header
    addq $16, %rdi
    # atualizando topo da pilha e brk
    addq stack_top, %rdi
    movq $12, %rax
    syscall
    movq %rax, stack_top

    # retorna o começo do bloco sem o header
    subq %r8, %rax
    
    # marca o bloco como ocupado
    movq $1, -16(%rax)
    # adiciona o tamnho na header
    movq %r8, -8(%rax)

    popq %rbp
    ret

add_info: 
    pushq %rbp
    movq %rsp, %rbp

    # r15 tamanho - tamanho que foi pedido
    movq %r12, %r15
    subq %rdi, %r15

    # se o tamanho que sobrou é menor que 16 não é possível criar novo bloco, então só preenche a header 
    cmpq $16, %r15
    jl _just_fill
    
    # para pular para o próximo bloco (novo alocado)
    # %r10 está com o endereço do bloco com o tamanho escolhido
    movq %r10, %r14
    addq $16, %r14
    addq %rdi, %r14

    # marca novo bloco como desocupado
    movq $0, (%r14)
    # subtrai a nova header
    subq $16, %r15
    movq %r15, 8(%r14)

    # preenche o bloco pedido como ocupado
    movq $1, (%r10)
    movq %rdi, 8(%r10)
    jmp __end_add_info

    # função para preencher a header quando não sobra espaço para outro bloco
    _just_fill:
        # lembrando que em %r10 temos o endereço do bloco que achamos
        movq $1, (%r10)
        movq %r12, 8(%r10)
        
    __end_add_info: 

    # pula a header
    addq $16, %r10
    # atualiza brk
    movq $12, %rax
    movq %r10, %rdi
    syscall

    popq %rbp
    ret


#  Procura bloco livre com tamanho igual ou maior que a requisição
search_block:
    pushq %rbp
    movq %rsp, %rbp

    movq original_brk, %r13

    # se o topo da pilha for igual ao brk original cria o primeiro bloco
    cmpq %r13, stack_top    
    je _call_open

    movq original_brk, %r8

    # r12 é o tamanho atual - começa com 0
    movq $0, %r12

    # percorre todos os blocos da heap 
    _while_search:
        # primeiro endereço está ocupado?
        cmpq $1, (%r8)
        je _iterate_search

        # compara o tamanho dos blocos
        cmpq %r12, 8(%r8) 
        jl _iterate_search
        
        # se o tamanho for maior atualiza o valor
        movq 8(%r8), %r12
        # guarda o endereço do bloco em r10
        movq %r8, %r10

        _iterate_search:
        # pega o tamanho do bloco e coloca em %r9
        movq 8(%r8), %r9
        # soma o tamanho do bloco analisado nele mesmo, brk pula para o proximo bloco 
        addq %r9, %r8
        addq $16, %r8
        
        # vê se está no topo da pilha
        cmpq stack_top, %r8
        je _end_search

        jmp _while_search
    _end_search:

    # se não tiver bloco alocado livre chama a de abrir novo bloco
    cmpq $0, %r12
    je _call_open

    # se o maior tamanho encontrado for menor que o tamanho pedido cria novo bloco
    cmpq %rdi, %r12
    jl _call_open

    # se encontrou bloco do tamanho pedido ou maior adiciona as informações
    call add_info
    jmp _end_search_block

    _call_open:
        call open_space

    _end_search_block:

    popq %rbp
    ret

memory_alloc:
    pushq %rbp
    movq %rsp, %rbp

    # tamanho do bloco(parâmetro) em %rdi
    call search_block 

    popq %rbp
    ret

