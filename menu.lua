-- menu.lua - Sistema de Menu e Configurações
local menu = {}
local config

-------------------------------------------------
-- Configurações Padrão
-------------------------------------------------
function menu.configPadrao()
	return {
		tamanhoGrid = 8,
		larguraTela = 1280,
		alturaTela = 800,
		palavrasPorNivel = {
			facil = 5,
			medio = 6,
			dificil = 8,
		},
		permitirVertical = true,
		permitirDiagonal = false,
		permitirReversas = true,
	}
end

-------------------------------------------------
-- JSON Writing (estrutura conhecida)
-------------------------------------------------
function menu.salvarConfig()
	local c = config
	local json = "{\n"
	json = json .. '  "tamanhoGrid": ' .. c.tamanhoGrid .. ",\n"
	json = json .. '  "larguraTela": ' .. c.larguraTela .. ",\n"
	json = json .. '  "alturaTela": ' .. c.alturaTela .. ",\n"
	json = json .. '  "palavrasPorNivel": {\n'
	json = json .. '    "facil": ' .. c.palavrasPorNivel.facil .. ",\n"
	json = json .. '    "medio": ' .. c.palavrasPorNivel.medio .. ",\n"
	json = json .. '    "dificil": ' .. c.palavrasPorNivel.dificil .. "\n"
	json = json .. "  },\n"
	json = json .. '  "permitirVertical": ' .. tostring(c.permitirVertical) .. ",\n"
	json = json .. '  "permitirDiagonal": ' .. tostring(c.permitirDiagonal) .. ",\n"
	json = json .. '  "permitirReversas": ' .. tostring(c.permitirReversas) .. "\n"
	json = json .. "}\n"

	love.filesystem.write("config.json", json)
end

-------------------------------------------------
-- JSON Parser (recursive descent mínimo)
-------------------------------------------------
local function isWhitespace(c)
	return c == " " or c == "\n" or c == "\r" or c == "\t"
end

local function skipWhitespace(str, i)
	while i <= #str and isWhitespace(str:sub(i, i)) do
		i = i + 1
	end
	return i
end

local function parseJSONValue(str, i)
	i = skipWhitespace(str, i)
	if i > #str then
		error("Fim inesperado do JSON")
	end

	local c = str:sub(i, i)

	if c == "{" then
		i = i + 1
		local obj = {}
		while true do
			i = skipWhitespace(str, i)
			if i > #str then
				error("Objeto JSON não finalizado")
			end
			if str:sub(i, i) == "}" then
				return obj, i + 1
			end
			if str:sub(i, i) == "," then
				i = i + 1
				i = skipWhitespace(str, i)
				if str:sub(i, i) == "}" then
					return obj, i + 1
				end
			end

			local key
			key, i = parseJSONValue(str, i)
			if type(key) ~= "string" then
				error("Chave deve ser string")
			end

			i = skipWhitespace(str, i)
			if str:sub(i, i) ~= ":" then
				error("Esperado ':'")
			end
			i = i + 1

			local val
			val, i = parseJSONValue(str, i)
			obj[key] = val
		end
	elseif c == '"' then
		local j = i + 1
		while j <= #str do
			local cc = str:sub(j, j)
			if cc == "\\" then
				j = j + 2
			elseif cc == '"' then
				local s = str:sub(i + 1, j - 1)
				s = s:gsub("\\n", "\n"):gsub('\\"', '"'):gsub("\\\\", "\\")
				return s, j + 1
			else
				j = j + 1
			end
		end
		error("String não finalizada")
	elseif c == "t" then
		assert(str:sub(i, i + 3) == "true", "Esperado 'true'")
		return true, i + 4
	elseif c == "f" then
		assert(str:sub(i, i + 4) == "false", "Esperado 'false'")
		return false, i + 5
	elseif c == "-" or c:match("%d") then
		local rest = str:sub(i)
		local numStr = rest:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*")
		if not numStr then
			error("Número inválido")
		end
		return tonumber(numStr), i + #numStr
	else
		error("Caractere inesperado: " .. c)
	end
end

local function parseJSON(str)
	local val, pos = parseJSONValue(str, 1)
	pos = skipWhitespace(str, pos)
	if pos <= #str then
		error("Conteúdo extra após JSON")
	end
	return val
end

-------------------------------------------------
-- Carregar / Salvar Configuração
-------------------------------------------------
function menu.carregarConfig()
	local ok, resultado = pcall(function()
		if love.filesystem.getInfo("config.json") then
			return parseJSON(love.filesystem.read("config.json"))
		end
		return nil
	end)

	if ok and resultado then
		config = resultado
	else
		config = menu.configPadrao()
		menu.salvarConfig()
	end
end

-------------------------------------------------
-- Inicialização do Menu (fontes)
-------------------------------------------------
function menu.init()
	menu.fonteTitulo = love.graphics.newFont(48)
	menu.fonteOpcao = love.graphics.newFont(36)
	menu.fonteInfo = love.graphics.newFont(22)
	menu.fontePequena = love.graphics.newFont(20)
end

-------------------------------------------------
-- Estado do Menu Principal
-------------------------------------------------
menu.opcaoSelecionada = 1
menu.opcoes = {
	{ nome = "Jogar", acao = "jogar" },
	{ nome = "Configurações", acao = "config" },
	{ nome = "Sair", acao = "sair" },
}

function menu.drawMenu()
	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()

	love.graphics.setBackgroundColor(0, 0, 0)

	-- Título
	love.graphics.setFont(menu.fonteTitulo)
	love.graphics.setColor(1, 1, 0)
	love.graphics.printf("CAÇA-PALAVRAS", 0, h * 0.12, w, "center")

	-- Subtítulo
	love.graphics.setFont(menu.fontePequena)
	love.graphics.setColor(0.6, 0.6, 0.6)
	love.graphics.printf("Um jogo acessível para todos", 0, h * 0.22, w, "center")

	-- Opções do Menu
	local inicioY = h * 0.35
	local espacamento = 65

	for i, opcao in ipairs(menu.opcoes) do
		local y = inicioY + (i - 1) * espacamento
		local estaSelecionado = (i == menu.opcaoSelecionada)

		love.graphics.setFont(menu.fonteOpcao)

		if estaSelecionado then
			love.graphics.setColor(1, 1, 0)
			love.graphics.printf("> " .. opcao.nome .. " <", 0, y, w, "center")
		else
			love.graphics.setColor(0.8, 0.8, 0.8)
			love.graphics.printf("  " .. opcao.nome, 0, y, w, "center")
		end
	end

	-- Instruções
	love.graphics.setFont(menu.fonteInfo)
	love.graphics.setColor(0.5, 0.5, 0.5)
	love.graphics.printf("Use SETAS CIMA/BAIXO e ENTER para selecionar", 0, h * 0.85, w, "center")
end

function menu.keypressedMenu(key)
	if key == "up" then
		menu.opcaoSelecionada = ((menu.opcaoSelecionada - 2) % #menu.opcoes) + 1
	elseif key == "down" then
		menu.opcaoSelecionada = (menu.opcaoSelecionada % #menu.opcoes) + 1
	elseif key == "return" or key == "space" then
		return menu.opcoes[menu.opcaoSelecionada].acao
	end
	return nil
end

-------------------------------------------------
-- Estado das Configurações
-------------------------------------------------
menu.configOpcaoSelecionada = 1
menu.configEditando = false

menu.configItens = {
	{ nome = "Tamanho do Grid", chave = "tamanhoGrid", tipo = "numero", min = 4, max = 20 },
	{
		nome = "Largura da Tela",
		chave = "larguraTela",
		tipo = "numero",
		min = 640,
		max = 2560,
		passo = 10,
	},
	{
		nome = "Altura da Tela",
		chave = "alturaTela",
		tipo = "numero",
		min = 480,
		max = 1440,
		passo = 10,
	},
	{
		nome = "Palavras - Fácil",
		chave = "facil",
		tipo = "sub",
		sub = "palavrasPorNivel",
		min = 3,
		max = 12,
	},
	{
		nome = "Palavras - Médio",
		chave = "medio",
		tipo = "sub",
		sub = "palavrasPorNivel",
		min = 4,
		max = 16,
	},
	{
		nome = "Palavras - Difícil",
		chave = "dificil",
		tipo = "sub",
		sub = "palavrasPorNivel",
		min = 5,
		max = 20,
	},
	{ nome = "Palavras na Vertical", chave = "permitirVertical", tipo = "booleano" },
	{ nome = "Palavras na Diagonal", chave = "permitirDiagonal", tipo = "booleano" },
	{ nome = "Palavras Reversas", chave = "permitirReversas", tipo = "booleano" },
}

function menu.getConfigValue(item)
	if item.tipo == "sub" then
		return config[item.sub][item.chave]
	else
		return config[item.chave]
	end
end

function menu.setConfigValue(item, valor)
	if item.tipo == "sub" then
		config[item.sub][item.chave] = valor
	else
		config[item.chave] = valor
	end
end

function menu.formatConfigValue(item)
	local val = menu.getConfigValue(item)
	if item.tipo == "booleano" then
		return val and "SIM" or "NÃO"
	else
		return tostring(val)
	end
end

function menu.drawConfig()
	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()

	love.graphics.setBackgroundColor(0, 0, 0)

	-- Título
	love.graphics.setFont(menu.fonteTitulo)
	love.graphics.setColor(1, 1, 0)
	love.graphics.printf("CONFIGURAÇÕES", 0, h * 0.05, w, "center")

	-- Itens de configuração
	local inicioY = h * 0.16
	local espacamento = 42

	for i, item in ipairs(menu.configItens) do
		local y = inicioY + (i - 1) * espacamento
		local estaSelecionado = (i == menu.configOpcaoSelecionada)
		local valorStr = menu.formatConfigValue(item)

		love.graphics.setFont(menu.fonteInfo)

		local prefixo
		local corTexto

		if estaSelecionado then
			if menu.configEditando then
				prefixo = "> "
				corTexto = { 1, 0.8, 0 } -- laranja para editando
			else
				prefixo = "> "
				corTexto = { 1, 1, 0 } -- amarelo para selecionado
			end
		else
			prefixo = "  "
			corTexto = { 0.8, 0.8, 0.8 } -- cinza claro
		end

		love.graphics.setColor(corTexto)

		-- Rótulo à esquerda
		love.graphics.print(prefixo .. item.nome, 60, y)

		-- Valor à direita
		local valorTexto = valorStr
		if estaSelecionado and menu.configEditando and item.tipo ~= "booleano" then
			valorTexto = "< " .. valorStr .. " >"
		elseif item.tipo == "booleano" and estaSelecionado then
			valorTexto = "[ " .. valorStr .. " ]"
		end

		love.graphics.printf(valorTexto, 0, y, w - 60, "right")
	end

	-- Instruções
	love.graphics.setFont(menu.fontePequena)
	love.graphics.setColor(0.5, 0.5, 0.5)

	love.graphics.printf("CIMA/BAIXO Navegar   ENTER Editar/Alterar   ESC Voltar", 0, h * 0.88, w, "center")

	love.graphics.printf("As alterações são salvas automaticamente.", 0, h * 0.93, w, "center")
end

function menu.keypressedConfig(key)
	if menu.configEditando then
		local item = menu.configItens[menu.configOpcaoSelecionada]

		if key == "escape" or key == "return" or key == "space" then
			menu.configEditando = false
			return nil
		end

		if item.tipo == "numero" or item.tipo == "sub" then
			local passo = item.passo or 1
			local min = item.min or 3
			local max = item.max or 99
			local val = menu.getConfigValue(item)

			if key == "up" or key == "right" then
				val = math.min(max, val + passo)
			elseif key == "down" or key == "left" then
				val = math.max(min, val - passo)
			end
			menu.setConfigValue(item, val)
			menu.salvarConfig()
		end
	else
		if key == "up" then
			menu.configOpcaoSelecionada = ((menu.configOpcaoSelecionada - 2) % #menu.configItens) + 1
		elseif key == "down" then
			menu.configOpcaoSelecionada = (menu.configOpcaoSelecionada % #menu.configItens) + 1
		elseif key == "escape" then
			return "voltar"
		elseif key == "return" or key == "space" then
			local item = menu.configItens[menu.configOpcaoSelecionada]
			if item.tipo == "booleano" then
				local val = menu.getConfigValue(item)
				menu.setConfigValue(item, not val)
				menu.salvarConfig()
			else
				menu.configEditando = true
			end
		end
	end

	return nil
end

-------------------------------------------------
-- Retorna a configuração atual
-------------------------------------------------
function menu.getConfig()
	return config
end

return menu
