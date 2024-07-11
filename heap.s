.section .data 
.section .text

.globl setupBrk
.globl _start

# obtém endereço do brk
setupBrk:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax
    movq $0, %rdi
    syscall

    popq %rbp
    ret

_start:
    call setupBrk 
    movq %rax, %rdi
    movq $60, %rax
    syscall

