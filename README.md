# Marley

A partir de agora, o nome da linguagem será Marley
por causa do cachorro do meu amigo

##HISTÓRICO DE ATUALIZAÇÕES:
### 2025-11-12: Versão 0.1 criada:
Ele lê o arquivo teste.t3, interpreta as linhas e gera o código Julia correspondente, salvando-o em output.jl.
Ele suporta definições de variáveis e comandos de impressão simples.
### 2025-11-13: Versão 0.2 criada:
Equações matemáticas na definição de variáveis agora são suportadas.
Exemplo: 
    2x = 3 + 4
quando x for printado, será avaliado como 3.5.
também funciona com outras incógnitas, mas a única modificada é a primeira encontrada na expressão.
### 2025-11-15: Versão 0.3 criada:
Alguns bugs corrigidos e pequenas modificações como:
comentários dentro de strings serem ignorados,
espaços antes e depois do texto serem ignorados,
as definições de variáveis agora poderem definir números inteiros,
e a implementação de um print que não dá um enter no final.
### 2025-11-17: Versão 0.4 criada:
implementação de recepção de input do usuário.
organização melhor do código, correção de algumas partes erradas e um sistema de parsing para poder ser rodado com
    julia 0.5.jl teste.t3
por exemplo.
### 2025-11-17: Versão 0.5 criada:
mais expressões para as funções existentes.
### 2025-11-26: Versão 0.6 criada:
suporte a definição de veriáveis com espaço, ex:
    essa variável vale 2
    imprime essa variável
### 2025-11-26: Versão 0.7 criada:
mais algumas pequenas atualizações:
 comentários multilinha usando parênteses
 suporte a strings multilinha
 placeholders com chaves, e no caso do programador querer chaves, ele pode digitar \{}
 e fazer a compilação dentro de placeholders
 mudar o nome da linguagem para Marley
 adicionar funções de incrementação, decrementação, etc.