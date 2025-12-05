# Marley

## HISTÓRICO DE ATUALIZAÇÕES:

### 2025-11-12: Versão 0.1 criada:
Ele lê o arquivo teste.t3, interpreta as linhas e gera o código Julia correspondente, salvando-o em output.jl.  
Ele suporta definições de variáveis e comandos de impressão simples.

### 2025-11-13: Versão 0.2 criada:
Equações matemáticas na definição de variáveis agora são suportadas.  
Exemplo:

```julia
2x = 3 + 4
```

Quando x for printado, será avaliado como 3.5.  
Também funciona com outras incógnitas, mas a única modificada é a primeira encontrada na expressão.

### 2025-11-15: Versão 0.3 criada:
Alguns bugs corrigidos e pequenas modificações como:
- comentários dentro de strings serem ignorados,
- espaços antes e depois do texto serem ignorados,
- as definições de variáveis agora poderem definir números inteiros,
- e a implementação de um print que não dá um enter no final.

### 2025-11-17: Versão 0.4 criada:
Implementação de recepção de input do usuário.  
Organização melhor do código, correção de algumas partes erradas e um sistema de parsing para poder ser rodado com:

```bash
julia 0.5.jl teste.t3
```

por exemplo.

### 2025-11-17: Versão 0.5 criada:
Mais expressões para as funções existentes.

### 2025-11-26: Versão 0.6 criada:
Suporte a definição de variáveis com espaço, por exemplo:

```marley
essa variável vale 2
imprime essa variável
```

### 2025-12-05: Versão 0.7 criada:
Mais algumas pequenas atualizações:
- comentários multilinha usando parênteses,
- suporte a strings multilinha,
- placeholders com chaves (e no caso do programador querer chaves, ele pode digitar \{}),
- fazer a compilação dentro de placeholders,
- mudar o nome da linguagem para Marley,
- adicionar funções de incrementação, decrementação, etc.
