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
    2025-11-16: Versão 0.4 criada:
        implementação de recepção de input do usuário.
        organização melhor do código, correção de algumas partes erradas e um sistema de parsing para poder ser rodado com
        julia 0.5.jl teste.t3, por exemplo.
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






defsvars = ["{val}{spaces}={spaces}{val}", 
            "define {val} como {val}", 
            "set {val} to {val}", 
            "{val} agora é <opt>igual a </opt>{val}", 
            "{val} now is <opt>equal to </opt>{val}"]
impnls = ["printe {val}<opt>, mas</opt> sem <opt>dar </opt>enter",
          "imprime {val}<opt>, mas</opt> sem <opt>dar </opt>enter", 
          "imprima {val}<opt>, mas</opt> sem <opt>dar </opt>enter", 
          "printnl {val}", 
          "print {val}<opt>, but</opt> without <opt>giving </opt>enter", 
          "mostre {val}<opt>, mas</opt> sem <opt>dar </opt>enter", 
          "show {val}<opt>, but</opt> without <opt>giving </opt>enter"]
imprs = ["printe {val}", 
         "imprime {val}", 
         "imprima {val}", 
         "print {val}", 
         "mostre {val}", 
         "show {val}"]
inputsquest = ["responda {val}", 
               "answer {val}",
               "input {val}", 
               "entrada {val}", 
               "ask {val}", 
               "pergunte {val}"]
readlines = ["readline",
             "read line",
             "ler linha", 
             "lerlinha", 
             "a linha digitada<opt> pelo usuário</opt>", 
             "the typed line",
             "the line typed by the user"]
funcs = Dict(defsvars => "var", 
             impnls => "print({vals[1]})",
             imprs => "println({vals[1]})",
             inputsquest => "input({vals[1]})",
             readlines => "readline()")
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
        # Se o RHS corresponder a um padrão de "readline" (ex.: "a linha digitada"),
        # convertê-lo para readline() antes de tentar resolver a equação.
        if extrair_valores(valor_var, readlines) !== nothing
            valor_var = "readline()"
        end
        #encontrar qual é a variável a ser modificada
        #identificar o primeiro nome de variável na definição
        m = match(r"[a-zA-Z_]\w*", nome_var*" "*valor_var)
        if isnothing(m)
            continue
        end
        varname = m.match
        equacao_resolvida = resolver_equacao(nome_var, valor_var, varname)
        julia_code *= equacao_resolvida * "\n"
        continue
    end
    nova_linha = substituir_vars(tipo,valores)
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