using Symbolics
texto = read("teste.t3", String)
lines = split(texto, '\n')
#remover comentários
for i in eachindex(lines)
    if occursin("#", lines[i])
        partes = split(lines[i], "#")
        # contar aspas corretamente (char -> boolean)
        if count(ch -> ch == '"', partes[1]) % 2 == 0
            lines[i] = partes[1]
            if count(ch -> ch == '"', lines[i]) % 2 != 0
                error("Comentário inválido na linha $(i): aspas não fechadas.")
            end
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
    if expressao_simples(lhs) && expressao_simples(rhs)
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
        s === nothing ||
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





defsvars = ["{val}{spaces}={spaces}{val}", "define {val} como {val}", "set {val} to {val}", "{val} agora é <opt>igual a </opt>{val}", "{val} now is <opt>equal to </opt>{val}"]
impnls = ["printe {val}<opt>, mas</opt> sem <opt>dar </opt>enter", "imprime {val}<opt>, mas</opt> sem <opt>dar </opt>enter", "imprima {val}<opt>, mas</opt> sem <opt>dar </opt>enter", "printnl {val}", "print {val}<opt>, but</opt> without <opt>giving </opt>enter", "mostre {val}<opt>, mas</opt> sem <opt>dar </opt>enter", "show {val}<opt>, but</opt> without <opt>giving </opt>enter"]
imprs = ["printe {val}", "imprime {val}", "imprima {val}", "print {val}", "mostre {val}", "show {val}"]
comandos = []
for linha in lines
    linha = strip(linha)
    if isempty(linha)
        continue
    end
    valores = extrair_valores(linha, defsvars)
    if valores !== nothing
        println("Definição de variável detectada: ", valores)
        push!(comandos, ("var", valores))
        continue
    end
    valores = extrair_valores(linha, impnls)
    if valores !== nothing
        println("Comando de impressão sem enter detectado: ", valores)
        push!(comandos, ("printnl", valores))
        continue
    end
    valores = extrair_valores(linha, imprs)
    if valores !== nothing
        println("Comando de impressão detectado: ", valores)
        push!(comandos, ("print", valores))
        continue
    end
    println("Linha não reconhecida: ", linha)
end
# COMPILAR PARA JULIA
julia_code = ""
for comando in comandos
   global julia_code
   tipo, valores = comando
   if tipo == "var"
        nome_var = valores[1]
        valor_var = valores[2]
        #encontrar qual é a variável a ser modificada
        #identificar o primeiro nome de variável na definição
        m = match(r"[a-zA-Z_]\w*", nome_var*" "*valor_var)
        if m === nothing
            continue
        end
        varname = m.match
        equacao_resolvida = resolver_equacao(nome_var, valor_var, varname)
        julia_code *= equacao_resolvida * "\n"
   elseif tipo == "print"
        valor_print = valores[1]
        julia_code *= "println($valor_print)\n"
    elseif tipo == "printnl"
        valor_print = valores[1]
        julia_code *= "print($valor_print)\n"
   end
end

println("Código Julia gerado:\n", julia_code)
# SALVAR CÓDIGO JULIA
open("output.jl", "w") do file
    write(file, julia_code)
end
println("Código Julia salvo em output.jl")