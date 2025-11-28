texto = read("teste.t3", String)
lines = split(texto, '\n')
#remover comentários
for i in eachindex(lines)
    if occursin("#", lines[i])
        partes = split(lines[i], "#")
        lines[i] = partes[1]
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

defsvars = ["{val}{spaces}={spaces}{val}", "define {val} como {val}", "set {val} to {val}", "{val} agora é <opt>igual a </opt>{val}", "{val} now is <opt>equal to </opt>{val}"]
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
      julia_code *= "$nome_var = $valor_var\n"
   elseif tipo == "print"
      valor_print = valores[1]
      julia_code *= "println($valor_print)\n"
   end
end

println("Código Julia gerado:\n", julia_code)
# SALVAR CÓDIGO JULIA
open("output.jl", "w") do file
    write(file, julia_code)
end
println("Código Julia salvo em output.jl")