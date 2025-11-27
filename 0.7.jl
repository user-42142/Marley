#= Este será o compilador do código em trilang, versão 0.1.
    HISTÓRICO DE ATUALIZAÇÕES:
    2025-11-12: Versão 0.1 criada:
        Ele lê o arquivo teste.t3, interpreta as linhas e gera o código Julia correspondente, salvando-o em output.jl.
        Ele suporta definições de variáveis e comandos de impressão simples.
    2025-11-13: Versão 0.2 criada:
        Equações matemáticas na definição de variáveis agora são suportadas.
        Exemplo: 2x = 3 + 4
        quando x for printado, será avaliado como 3.5.
        também funciona com outras incógnitas, mas a única modificada é a primeira encontrada na expressão.
    2025-11-15: Versão 0.3 criada:
      Alguns bugs corrigidos e pequenas modificações como:
        comentários dentro de strings serem ignorados,
        espaços antes e depois do texto serem ignorados,
        as definições de variáveis agora poderem definir números inteiros,
        e a implementação de um print que não dá um enter no final.
    2025-11-17: Versão 0.4 criada:
        implementação de recepção de input do usuário.
        organização melhor do código, correção de algumas partes erradas e um sistema de parsing para poder ser rodado com
        julia 0.5.jl teste.t3, por exemplo.
    2025-11-17: Versão 0.5 criada:
        mais expressões para as funções existentes.
    2025-11-26: Versão 0.6 criada:
        suporte a definição de veriáveis com espaço, ex:
        essa variável vale 2
        imprime essa variável
    2025-11-26: Versão 0.7 criada:
        mais algumas pequenas atualizações:
         comentários multilinha usando parênteses
         suporte a strings multilinha
         placeholders com chaves, e no caso do programador querer chaves, ele pode digitar \{}
         e fazer a compilação dentro de placeholders
         mudar o nome da linguagem para Marley
         adicionar funções de incrementação, decrementação, etc.
   =#
using Symbolics
using ArgParse
settings = ArgParseSettings()
@add_arg_table settings begin
    "input_file"
        help = "Arquivo a ser compilado"
        arg_type = String
        default = "teste.t3"
    "--output"
        help = "Saída do compilador"
        arg_type = String
        default = nothing
    "--debug"
        help = "Modo de Debug"
        action = :store_true
end
args = parse_args(settings)
texto = read(args["input_file"], String)
lines = split(texto, '\n')
#remover comentários
for i in eachindex(lines)
    if occursin("#", lines[i])
        partes = split(lines[i], "#")
        # contar aspas corretamente (char -> boolean)
        if count(ch -> ch == '"', partes[1]) % 2 == 0
            lines[i] = partes[1]
        end
        if count(ch -> ch == '"', lines[i]) % 2 != 0
            error("Comentário inválido na linha $(i): aspas não fechadas.")
        end
    end
end
function extrair_valores(linha::AbstractString, padroes::Vector{String})
    for padrao in padroes
        # Escapar caracteres regex perigosos
        regex = replace(padrao, r"([\\\.\+\*\?\[\]\(\)\^\$\|])" => s"\\\1")

        # Substituir os elementos especiais
        regex = replace(regex, r" " => " +")  # espaço normal = ao menos um espaço
        regex = replace(regex, "{spaces}" => " *")
        regex = replace(regex, r"<opt>(.*?)</opt>" => s"(?:\1)?")
        regex = replace(regex, "{val}" => "(.+?)")

        # Regex de correspondência completa
        re = Regex("^" * regex * "\$", "i")
        m = match(re, linha)
        if m !== nothing
            return [String(v) for v in m.captures if v !== nothing]
        end
    end
    return nothing
end
function limpar_floats(texto)
    replace(texto, r"(\d+)\.0+\b" => s"\1")
end

using Symbolics

function resolver_equacao(lhs::AbstractString, rhs::AbstractString, varname::AbstractString)
    function expressao_simples(txt)
        occursin(r"^[a-zA-Z_]\w*$", txt) || occursin(r"^\".*\"$", txt)
    end
    
    # Check if rhs contains a function call like readline()
    if occursin(r"\w+\s*\(.*\)", rhs)
        return limpar_floats("$(varname) = $(rhs)")
    end
    
    if expressao_simples(lhs) && expressao_simples(rhs)
        return limpar_floats("$(varname) = $(rhs)")
    end
    if lhs == varname
        return limpar_floats("$(varname) = $(rhs)")
    end
    texto_total = lhs * " " * rhs
    nomes_vars = unique([m.match for m in eachmatch(r"[a-zA-Z_]\w*", texto_total)])
    simbolos = Dict{String,Any}()
    for nome in nomes_vars
        simbolos[nome] = Symbolics.variable(Symbol(nome))
    end
    function substituir(expr)
        if expr isa Symbol
            s = String(expr)
            if haskey(simbolos, s)
                return simbolos[s]
            else
                return expr
            end
        elseif expr isa Number
            return expr
        elseif expr isa Expr
            return Expr(expr.head, substituir.(expr.args)...)
        else
            return expr
        end
    end
    lhs_parsed = Meta.parse(lhs)
    rhs_parsed = Meta.parse(rhs)
    lhs_sub = substituir(lhs_parsed)
    rhs_sub = substituir(rhs_parsed)
    lhs_eval = eval(lhs_sub)
    rhs_eval = eval(rhs_sub)
    eq = lhs_eval ~ rhs_eval
    if !haskey(simbolos, varname)
        return limpar_floats("variável $(varname) não encontrada nas expressões")
    end
    var = simbolos[varname]
    sol = try
        Symbolics.solve_for(eq, var)
    catch
        nothing
    end
    function invalido(s)
        isnothing(s) ||
        s == [] ||
        (isa(s, Number) && isnan(s)) ||
        string(s) == string(eq)
    end
    if invalido(sol)
        isolado = simplify(rhs_eval - (lhs_eval - var))
        return limpar_floats("$(varname) = $(string(isolado))")
    else
        sol = sol isa AbstractArray ? sol[1] : sol
        sol_simp = simplify(sol)
        return limpar_floats("$(varname) = $(string(sol_simp))")
    end
end
function substituir_vars(texto::AbstractString, lista)
    # aceitar tanto {vars[n]} quanto {vals[n]}
    regex = r"\{(?:vars|vals)\[(\d+)\]\}"
    io = IOBuffer()
    pos = 1
    for m in eachmatch(regex, texto)
        start = m.offset
        stop = m.offset + lastindex(m.match) - 1
        n = parse(Int, m.captures[1])
        print(io, texto[pos:start-1])
        print(io, lista[n])
        pos = stop + 1
    end
    print(io, texto[pos:end])
    String(take!(io))
end





__vars__ = String[]

# registra/retorna placeholder para um nome de variável (aceita nomes com espaços)
function get_var_placeholder(nome::AbstractString)
    idx = findfirst(x -> x == nome, __vars__)
    if idx === nothing
        push!(__vars__, nome)
        idx = length(__vars__)
    end
    return "variable_$idx"
end

# substitui valores capturados por placeholders se forem nomes registrados em __vars__
function valores_para_placeholders(vals::Vector{String})
    [ (findfirst(x -> x == v, __vars__) === nothing) ? v : "variable_$(findfirst(x->x==v,__vars__))" for v in vals ]
end


defsvars = ["{val}{spaces}={spaces}{val}", 
            "define {val} como {val}", 
            "set {val} to {val}", 
            "{val} agora é <opt>igual a </opt>{val}", 
            "{val} now is <opt>equal to </opt>{val}",
            "{val} passa a ser <opt>igual a </opt>{val}",
            "{val} se torna {val}",
            "declare {val} como {val}",
            "ajuste {val} para {val}",
            "mude {val} para {val}",
            "<opt>define que </opt>{val} <opt>vale</opt><opt>é igual</opt><opt> a</opt><opt> á</opt> {val}",
            "faça {val} <opt>ser </opt><opt>igual a </opt>{val}",
            "configure {val} para {val}",
            "define {val} as {val}",
            "{val} becomes {val}",
            "change {val} to {val}",
            "{val} equals {val}",
            "{val} is equal to {val}",
            "adjust {val} to {val}",
            "update {val} to {val}",
            "var {val}{spaces}={spaces}{val}",
            "let {val}{spaces}={spaces}{val}",
            "assign {val} {val}"]
impnls = ["printe {val}<opt>, mas</opt> sem <opt>dar </opt>enter",
          "imprime {val}<opt>, mas</opt> sem <opt>dar </opt>enter", 
          "imprima {val}<opt>, mas</opt> sem <opt>dar </opt>enter", 
          "printnl {val}", 
          "print {val}<opt>, but</opt> without <opt>giving </opt>enter", 
          "mostre {val}<opt>, mas</opt> sem <opt>dar </opt>enter", 
          "show {val}<opt>, but</opt> without <opt>giving </opt>enter",
          "write {val}<opt>, but</opt> without <opt>giving </opt>enter",
          "display {val}<opt>, but</opt> without <opt>giving </opt>enter",
          "echo {val}<opt>, but</opt> without <opt>giving </opt>enter",
          "output {val}<opt>, but</opt> without <opt>giving </opt>enter",
          "echonl {val}",
          "outnl {val}",
          "writenl {val}"]
imprs = ["printe {val}", 
         "imprime {val}", 
         "imprima {val}", 
         "print {val}", 
         "mostre <opt>linha </opt><opt>na tela </opt>{val}<opt> na tela</opt>",
         "mostra <opt>linha </opt><opt>na tela </opt>{val}<opt> na tela</opt>",
         "show {val}",
         "escreva <opt>linha </opt>{val}",
         "exiba {val}",
         "display {val}",
         "write {val}",
         "echo {val}",
         "output {val}",
         "println {val}",
         "out {val}"]
inputsquest = ["responda {val}", 
               "answer {val}",
               "input {val}", 
               "entrada {val}", 
               "ask {val}", 
               "pergunte {val}",
               "<opt>a </opt>resposta <opt>do usuário </opt>para<opt> a pergunta{spaces}</opt><opt>:</opt>{spaces}{val}",
               "<opt>o </opt>texto escrito pelo usuário em resposta a{spaces}<opt>:<opt>{spaces}{val}",
               "<opt>the </opt><opt>user's </opt>answer to<opt> the question{spaces}</opt><opt>:</opt>{spaces}{val}",
               "<opt>the </opt>text written by the user in response to{spaces}<opt>:<opt>{spaces}{val}"]
readlines = ["readline",
             "read line",
             "ler linha", 
             "lerlinha", 
             "input",
             "<opt>a </opt>linha digitada<opt> pelo usuário</opt>", 
             "<opt>the </opt>typed line",
             "the line typed by the user",
             "esperar o usuário apertar enter",
             "wait for the user <opt>to </opt>press enter",
             "<opt>a </opt> entrada do teclado",
             "<opt>the </opt>keyboard's input",
             "<opt>o </opt>texto escrito pelo usuário"]
funcs = Dict(defsvars => "var", 
             impnls => "print({vals[1]})",
             imprs => "println({vals[1]})",
             inputsquest => "input({vals[1]})",
             readlines => "readline()",
             ["\$"] => "\\\$")
strfuncs = Dict(["\\{{val}}"] => "{{vals[1]}}",
                ["{{val}}"] => "\$({vals[1]})")
             
comandos = []
for linha_sub in lines
    linha = strip(String(linha_sub))
    if isempty(linha)
        continue
    end
    for (k,v) in funcs
        if !occursin("{val}",k[1])
            for s in k
                linha = replace(linha, s => v)
            end
            continue
        end
        vals = extrair_valores(linha,k)
        if isnothing(vals)
            continue
        end

        # Ajuste de sintaxe em strings usando strfuncs (ex: {{val}} -> $(val), \{{val}} -> {val})
        for i in eachindex(vals)
            for (ks, vs) in strfuncs
                inner = extrair_valores(vals[i], ks)
                if inner !== nothing
                    # substituir usando o template definido em strfuncs
                    vals[i] = substituir_vars(vs, inner)
                    break
                end
            end
        end

        push!(comandos,(v,vals))
        break
    end
    if args["debug"]
        println("Linha não reconhecida: ", linha)
    end
end
# COMPILAR PARA JULIA
julia_code = "function input(question)
    print(question)
    return readline()
end
"
for comando in comandos
    global julia_code
    tipo, valores = comando
    if args["debug"]
        println("Processando comando do tipo '$tipo' com valores: ", valores)
    end
    if tipo == "var"
        nome_var = valores[1]
        valor_var = valores[2]

        # Registrar nome completo da variável e usar placeholder
        placeholder = get_var_placeholder(nome_var)
        # Substituir ocorrências literais do nome na expressão por placeholder
        # (nome_var vem do capture {val} e deve corresponder exatamente)
        nome_var_sub = replace(nome_var, nome_var => placeholder)
        valor_var_sub = replace(valor_var, nome_var => placeholder)

        # Tentar casar o RHS com outros padrões (por exemplo perguntas) e convertê‑lo
        # em um template de código (ex: input("...")) usando funcs.
        for (kp, vp) in funcs
            if vp != "var"  # ignorar padrões de definição de variável
                vals_match = extrair_valores(valor_var_sub, kp)
                if vals_match !== nothing
                    # antes de aplicar substituir_vars, transformar possíveis nomes já registrados
                    vals_match = valores_para_placeholders(vals_match)
                    valor_var_sub = substituir_vars(vp, vals_match)
                    break
                end
            end
        end

        #identificar o primeiro nome de variável na definição (agora deve ser placeholder válido)
        m = match(r"[A-Za-z_]\w*", nome_var_sub*"="*valor_var_sub)
        if isnothing(m)
            continue
        end
        varname = m.match
        equacao_resolvida = resolver_equacao(nome_var_sub, valor_var_sub, varname)
        julia_code *= equacao_resolvida * "\n"
        continue
    end

    # Para comandos não-var: substituir valores que sejam nomes registrados por placeholders
    valores_sub = valores_para_placeholders(valores)

    nova_linha = substituir_vars(tipo,valores_sub)
    julia_code *= nova_linha * "\n"
end
if args["debug"]
    println("Código Julia gerado:\n", julia_code)
end
# SALVAR CÓDIGO JULIA
if isnothing(args["output"])
   output = replace(args["input_file"],".t3" => ".jl")
   output = replace(output,".trilang" => ".jl")
else
    output = args["output"]
end
open(output, "w") do file
    write(file, julia_code)
end
if args["debug"]
    println("Código Julia salvo em $output")
end