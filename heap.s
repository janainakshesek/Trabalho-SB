.section .data 
.section .text

.globl setupBrk

# obtém endereço do brk
setupBrk:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax
    movq $0, %rdi
    syscall

    popq %rbp
    ret

