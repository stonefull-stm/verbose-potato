-------------------------------------------------
local socket = require("socket")
local server

-- Configurações Globais
local TAM_GRID -- Tamanho da grade (8x8)
local TAM_CELULA = 70 -- Células grandes para facilitar a leitura
local OFFSET_X = 50
local OFFSET_Y = 100

local bancoPalavras = {}
local palavrasNivel = {}
local palavrasEncontradas = {}
local celulasEncontradas = {}
local grid = {}
local fonteTitulo = {}
local fonteGrande = {}
local inicializarJogo
local verificarPalavraSelecionada
local carregarBancoDePalavras

local menu = require("menu")
local estado = "menu"
local config

-- Controle do Jogador
local cursorX = 1
local cursorY = 1
local selecionando = false
local inicioX, inicioY = 0, 0

function love.load()
	menu.init()
	menu.carregarConfig()

	-- Pega configurações no arquivo
	config = menu.getConfig()
	TAM_GRID = config["tamanhoGrid"]

	-- Configuração da tela para alta resolução e visibilidade
	love.window.setMode(config["larguraTela"], config["alturaTela"])

	-- Carregar banco de palavras
	carregarBancoDePalavras("palavras.txt")

	-- Fontes nativas grandes para acessibilidade
	fonteGrande = love.graphics.newFont(40)
	fonteTitulo = love.graphics.newFont(48)
	server = assert(socket.bind("0.0.0.0", 8080))
	server:settimeout(0)
end

function inicializarJogo(dificuldade)
	palavrasNivel = {}
	palavrasEncontradas = {}
	celulasEncontradas = {}
	grid = {}
	cursorX, cursorY = 1, 1
	selecionando = false

	-- Define quantidade de palavras por dificuldade
	local qtdPalavras = config["palavrasPorNivel"][dificuldade]

	-- Sorteia palavras sem repetir
	math.randomseed(os.time())
	local bancoCopia = { unpack(bancoPalavras) }
	for i = 1, qtdPalavras do
		_ = i
		if #bancoCopia == 0 then
			break
		end
		local idx = math.random(1, #bancoCopia)
		local palavra = table.remove(bancoCopia, idx)
		table.insert(palavrasNivel, palavra)
		palavrasEncontradas[palavra] = false
	end

	-- Cria a grade vazia
	for y = 1, TAM_GRID do
		grid[y] = {}
		for x = 1, TAM_GRID do
			grid[y][x] = "-"
		end
	end

	-- Insere as palavras na grade
	for _, palavra in ipairs(palavrasNivel) do
		local inserida = false
		local tentativas = 0
		while not inserida do
			tentativas = tentativas + 1
			-- Se exceder tentativas, recria a grade inteira para evitar loop infinito
			if tentativas > 100 then
				inicializarJogo(dificuldade)
				return
			end
			local direcao = 1
			if config["permitirVertical"] then
				direcao = math.random(2) -- 1 (Horizontal) -- 2 (Vertical)
			end
			local x, y
			if direcao == 1 then
				y = math.random(1, TAM_GRID)
				x = math.random(1, TAM_GRID - #palavra + 1)
			else
				x = math.random(1, TAM_GRID)
				y = math.random(1, TAM_GRID - #palavra + 1)
			end

			-- Verifica se o espaço está livre
			local espacoLivre = true
			for c = 1, #palavra do
				if direcao == 1 then
					if grid[y][x + c - 1] ~= "-" then
						espacoLivre = false
					end
				else
					if grid[y + c - 1][x] ~= "-" then
						espacoLivre = false
					end
				end
			end

			-- Insere a palavra letra por letra se o espaço estiver livre
			if espacoLivre then
				for c = 1, #palavra do
					if direcao == 1 then
						grid[y][x + c - 1] = palavra:sub(c, c)
					else
						grid[y + c - 1][x] = palavra:sub(c, c)
					end
				end
				inserida = true
			end
		end
	end

	-- Preenche o restante do espaço com letras aleatórias
	local alfabeto = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for y = 1, TAM_GRID do
		for x = 1, TAM_GRID do
			if grid[y][x] == "-" then
				local idx = math.random(1, #alfabeto)
				grid[y][x] = alfabeto:sub(idx, idx)
			end
		end
	end
end

function love.keypressed(key)
	if estado == "menu" then
		local acao = menu.keypressedMenu(key)
		if acao == "jogar" then
			estado = "jogo"
			inicializarJogo("facil")
		elseif acao == "config" then
			estado = "config"
		elseif acao == "sair" then
			love.event.quit()
		end
	elseif estado == "config" then
		local acao = menu.keypressedConfig(key)
		if acao == "voltar" then
			estado = "menu"
		end
	else
		if key == "escape" then
			estado = "menu"
			return
		end

		-- Movimentação do Cursor
		if key == "up" then
			cursorY = math.max(1, cursorY - 1)
		end
		if key == "down" then
			cursorY = math.min(TAM_GRID, cursorY + 1)
		end
		if key == "left" then
			cursorX = math.max(1, cursorX - 1)
		end
		if key == "right" then
			cursorX = math.min(TAM_GRID, cursorX + 1)
		end

		-- Sistema de Seleção de Palavras (Enter / Espaço)
		if key == "return" or key == "space" then
			if not selecionando then
				-- Inicia a seleção da palavra
				selecionando = true
				inicioX, inicioY = cursorX, cursorY
			else
				-- Finaliza a seleção e checa se formou uma palavra válida
				verificarPalavraSelecionada(inicioX, inicioY, cursorX, cursorY)
				selecionando = false
			end
		end

		-- Atalhos para mudar de nível instantaneamente
		if key == "1" then
			inicializarJogo("facil")
		end
		if key == "2" then
			inicializarJogo("medio")
		end
		if key == "3" then
			inicializarJogo("dificil")
		end
	end
end

function verificarPalavraSelecionada(x1, y1, x2, y2)
	-- Horizontal: mesma linha
	if y1 == y2 then
		local palavraSegmento = ""
		local inicio = math.min(x1, x2)
		local fim = math.max(x1, x2)

		for x = inicio, fim do
			palavraSegmento = palavraSegmento .. grid[y1][x]
		end

		for _, palavra in ipairs(palavrasNivel) do
			if palavraSegmento == palavra or string.reverse(palavraSegmento) == palavra then
				palavrasEncontradas[palavra] = true
				for x = inicio, fim do
					celulasEncontradas[y1 .. "," .. x] = true
				end
			end
		end
	end

	-- Vertical: mesma coluna
	if x1 == x2 then
		local palavraSegmento = ""
		local inicio = math.min(y1, y2)
		local fim = math.max(y1, y2)

		for y = inicio, fim do
			palavraSegmento = palavraSegmento .. grid[y][x1]
		end

		for _, palavra in ipairs(palavrasNivel) do
			if palavraSegmento == palavra or string.reverse(palavraSegmento) == palavra then
				palavrasEncontradas[palavra] = true
				for y = inicio, fim do
					celulasEncontradas[y .. "," .. x1] = true
				end
			end
		end
	end
end

-- Função para ler o arquivo linha por linha
function carregarBancoDePalavras(caminhoDoArquivo)
	-- Verifica se o arquivo existe dentro da pasta do projeto
	if love.filesystem.getInfo(caminhoDoArquivo) then
		-- love.filesystem.lines percorre o arquivo linha por linha de forma eficiente
		for linha in love.filesystem.lines(caminhoDoArquivo) do
			-- Remove espaços em branco extras nas pontas e ignora linhas vazias
			local palavraLimpa = linha:match("^%s*(.-)%s*$")
			if palavraLimpa ~= "" then
				table.insert(bancoPalavras, palavraLimpa:upper()) -- Salva em maiúsculo
			end
		end
	else
		print("Erro: O arquivo " .. caminhoDoArquivo .. " não foi encontrado!")
	end
end

function love.update(dt)
	_ = dt
	local client = server:accept()
	if client then
		client:settimeout(2)

		-- Lê headers
		local requisicao = {}
		local linha
		repeat
			linha = client:receive()
			if linha then
				table.insert(requisicao, linha)
			end
		until not linha or linha == ""

		-- Descobre tamanho do corpo
		---@type integer? -- Evita que LuaLS reclame do cast tonumber(n)
		local tamanho = 0
		for _, h in ipairs(requisicao) do
			local n = h:match("[Cc]ontent%-[Ll]ength:%s*(%d+)")
			if n then
				tamanho = tonumber(n)
			end
		end

		-- Lê corpo
		local comando = ""
		if tamanho > 0 then
			comando = client:receive(tamanho) or ""
		end
		comando = comando:gsub("%s+", "")

		-- Processa comando
		if comando == "up" then
			cursorY = math.max(1, cursorY - 1)
		elseif comando == "down" then
			cursorY = math.min(TAM_GRID, cursorY + 1)
		elseif comando == "left" then
			cursorX = math.max(1, cursorX - 1)
		elseif comando == "right" then
			cursorX = math.min(TAM_GRID, cursorX + 1)
		elseif comando == "enter" then
			if not selecionando then
				-- Inicia a seleção da palavra
				selecionando = true
				inicioX, inicioY = cursorX, cursorY
			else
				-- Finaliza a seleção e checa se formou uma palavra válida
				verificarPalavraSelecionada(inicioX, inicioY, cursorX, cursorY)
				selecionando = false
			end
		end

		-- Resposta com CORS
		client:send("HTTP/1.1 200 OK\r\n")
		client:send("Access-Control-Allow-Origin: *\r\n")
		client:send("Content-Type: text/plain\r\n")
		client:send("Connection: close\r\n\r\n")
		client:send("OK")
		client:close()
	end
end

function love.draw()
	if estado == "menu" then
		menu.drawMenu()
		return
	end
	if estado == "config" then
		menu.drawConfig()
		return
	end

	-- Fundo Preto para Máximo Contraste (Acessibilidade)
	love.graphics.setBackgroundColor(0, 0, 0)

	-- Título e Instruções de Uso
	love.graphics.setFont(fonteTitulo)
	love.graphics.setColor(1, 1, 0) -- Amarelo chamativo
	love.graphics.print("CAÇA-PALAVRAS", OFFSET_X, 20)

	love.graphics.setFont(fonteGrande)
	love.graphics.setColor(0.7, 0.7, 0.7)
	love.graphics.print(
		"Use as SETAS. ENTER para selecionar início/fim. Teclas 1, 2, 3 mudam nível. ESC para menu.",
		OFFSET_X,
		675,
		0,
		0.6,
		0.6
	)

	-- Desenha a Grade de Letras
	for y = 1, TAM_GRID do
		for x = 1, TAM_GRID do
			local posX = OFFSET_X + (x - 1) * TAM_CELULA
			local posY = OFFSET_Y + (y - 1) * TAM_CELULA

			-- Define a cor de destaque se o cursor estiver em cima da letra
			if x == cursorX and y == cursorY then
				love.graphics.setLineWidth(5)
				-- love.graphics.setColor(0, 0.5, 1) -- Azul para o Cursor Ativo
				love.graphics.setColor(1, 0, 0) -- Vermelho para o Cursor Ativo
				love.graphics.rectangle("line", posX, posY, TAM_CELULA, TAM_CELULA, 5, 5)
				love.graphics.setColor(1, 1, 1)
				love.graphics.setLineWidth(1)
			elseif celulasEncontradas[y .. "," .. x] then
				love.graphics.setColor(1, 0.5, 0) -- Laranja para palavras já encontradas
				love.graphics.rectangle("fill", posX, posY, TAM_CELULA, TAM_CELULA, 5, 5)
				love.graphics.setColor(0, 0, 0) -- Texto preto no fundo laranja
			elseif
				selecionando
				and (
					(
						y == inicioY
						and y == cursorY
						and x >= math.min(inicioX, cursorX)
						and x <= math.max(inicioX, cursorX)
					)
					or (
						x == inicioX
						and x == cursorX
						and y >= math.min(inicioY, cursorY)
						and y <= math.max(inicioY, cursorY)
					)
				)
			then
				love.graphics.setColor(1, 0.5, 0) -- Laranja para área sendo arrastada
				love.graphics.rectangle("fill", posX, posY, TAM_CELULA, TAM_CELULA, 5, 5)
				love.graphics.setColor(0, 0, 0) -- Texto preto no fundo laranja
			else
				love.graphics.setColor(0.2, 0.2, 0.2) -- Borda suave
				love.graphics.rectangle("line", posX, posY, TAM_CELULA, TAM_CELULA, 5, 5)
				love.graphics.setColor(1, 1, 1) -- Letras Brancas
			end

			-- Centraliza e imprime a letra grande
			love.graphics.print(grid[y][x], posX + 20, posY + 10)
		end
	end

	-- COLUNA DA DIREITA: Lista de Palavras Ocultas
	local inicioColunaX = 700
	love.graphics.setColor(1, 1, 0)
	love.graphics.print("PALAVRAS NO JOGO:", inicioColunaX, OFFSET_Y)

	for i, palavra in ipairs(palavrasNivel) do
		local posY = OFFSET_Y + 40 + (i * 60)

		if palavrasEncontradas[palavra] then
			love.graphics.setColor(0, 1, 0) -- Verde para palavras encontradas
			love.graphics.print("[X] " .. palavra, inicioColunaX, posY)
		else
			love.graphics.setColor(1, 1, 1) -- Branco para pendentes
			love.graphics.print("[  ] " .. palavra, inicioColunaX, posY)
		end
	end
end
