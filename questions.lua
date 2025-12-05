local Questions = {}

-- Perguntas organizadas por dificuldade (1 = fácil, 2 = médio, 3 = difícil)
-- Total: 20 perguntas para 10 rodadas de perguntas (waves 2,4,6,8,10,12,14,16,18,20)
local questionsByDifficulty = {
  -- FÁCEIS (Waves 1-6) - Conceitos básicos e óbvios
  [1] = {
    {
      text = 'Sua senha é "123456". Qual a melhor prática?',
      options = {
        'Manter, pois é fácil de lembrar',
        'Trocar por uma senha forte com letras, números e símbolos',
        'Usar dados pessoais para facilitar a memorização'
      },
      correct = 2
    },
    {
      text = 'Você encontrou um pen drive no campus. O que fazer?',
      options = {
        'Conectar no seu computador para identificar o dono',
        'Entregar à segurança/achados e perdidos; não conectar',
        'Levar para casa para analisar com calma'
      },
      correct = 2
    },
    {
      text = 'Alguém liga dizendo ser do suporte e pede sua senha. O que fazer?',
      options = {
        'Informar a senha por telefone para agilizar',
        'Recusar e confirmar pelo canal oficial da empresa',
        'Enviar a senha por mensagem após a ligação'
      },
      correct = 2
    },
    {
      text = 'Você recebe um e-mail de um príncipe oferecendo milhões. O que fazer?',
      options = {
        'Responder pedindo os detalhes da transferência',
        'Ignorar e deletar, é golpe clássico',
        'Encaminhar para amigos para ver se é real'
      },
      correct = 2
    },
    {
      text = 'O que significa o cadeado na barra de endereços do navegador?',
      options = {
        'O site é 100% confiável e seguro',
        'A conexão é criptografada (HTTPS)',
        'O site foi aprovado pelo governo'
      },
      correct = 2
    },
    {
      text = 'Qual é a forma mais segura de guardar suas senhas?',
      options = {
        'Anotar em um papel na mesa',
        'Usar um gerenciador de senhas confiável',
        'Salvar em um arquivo .txt no desktop'
      },
      correct = 2
    },
    {
      text = 'Você deve compartilhar sua senha com seu melhor amigo?',
      options = {
        'Sim, amigos são confiáveis',
        'Não, senhas são pessoais e intransferíveis',
        'Apenas se ele prometer não contar'
      },
      correct = 2
    },
  },

  -- MÉDIAS (Waves 7-14) - Requerem mais atenção
  [2] = {
    {
      text = 'Um e-mail diz que sua conta será bloqueada se não clicar em um link. O que fazer?',
      options = {
        'Clicar no link e informar seus dados para evitar o bloqueio',
        'Verificar o remetente e acessar o site digitando o endereço oficial',
        'Responder o e-mail pedindo mais informações'
      },
      correct = 2
    },
    {
      text = 'Um anexo de "comprovante" de desconhecido chega no seu e-mail. O que fazer?',
      options = {
        'Abrir o anexo para conferir o conteúdo',
        'Marcar como spam e excluir, sem baixar',
        'Reencaminhar para colegas para eles verificarem'
      },
      correct = 2
    },
    {
      text = 'Uma rede Wi-Fi pública pede apenas para aceitar os termos. Qual a postura segura?',
      options = {
        'Usar normalmente para acessar banco e e-mail',
        'Evitar dados sensíveis e, se possível, usar VPN',
        'Compartilhar arquivos pessoais para testar a velocidade'
      },
      correct = 2
    },
    {
      text = 'Seu navegador avisa que o site não é seguro (HTTP). O que significa?',
      options = {
        'É normal, pode inserir dados sem problemas',
        'A conexão não é criptografada; evite informações sensíveis',
        'O computador está com vírus e precisa ser formatado'
      },
      correct = 2
    },
    {
      text = 'Um app desconhecido pede permissões para câmera e microfone. O que fazer?',
      options = {
        'Conceder tudo para liberar mais rápido',
        'Permitir apenas se o app for confiável e realmente precisar',
        'Conceder e depois revogar quando lembrar'
      },
      correct = 2
    },
    {
      text = 'Você percebe uma cobrança estranha no cartão após comprar online. O que fazer?',
      options = {
        'Ignorar, pois deve ser demora do sistema',
        'Contactar o banco imediatamente e monitorar as transações',
        'Postar nas redes sociais para avisar amigos'
      },
      correct = 2
    },
    {
      text = 'Um colega pede a foto do seu crachá para "verificar o acesso". Como proceder?',
      options = {
        'Enviar a foto imediatamente para ajudar',
        'Confirmar com o setor responsável antes de compartilhar',
        'Publicar a foto no grupo geral e marcar a coordenação'
      },
      correct = 2
    },
  },

  -- DIFÍCEIS (Waves 15-20) - Requerem conhecimento técnico
  [3] = {
    {
      text = 'O que é autenticação de dois fatores (2FA)?',
      options = {
        'Usar duas senhas diferentes para a mesma conta',
        'Uma camada extra de segurança além da senha (código, biometria)',
        'Fazer login duas vezes seguidas para confirmar'
      },
      correct = 2
    },
    {
      text = 'O que é um ataque de phishing?',
      options = {
        'Quando hackers invadem diretamente seu computador',
        'Tentativa de enganar usuários para obter dados via mensagens falsas',
        'Um vírus que destrói arquivos automaticamente'
      },
      correct = 2
    },
    {
      text = 'O que é ransomware?',
      options = {
        'Um programa que acelera o computador',
        'Malware que criptografa dados e exige pagamento para liberá-los',
        'Um tipo de firewall avançado'
      },
      correct = 2
    },
    {
      text = 'O que um firewall faz?',
      options = {
        'Acelera a conexão com a internet',
        'Monitora e controla o tráfego de rede com base em regras',
        'Remove vírus automaticamente do sistema'
      },
      correct = 2
    },
    {
      text = 'O que é engenharia social em cibersegurança?',
      options = {
        'Desenvolvimento de software seguro',
        'Manipulação psicológica para obter informações confidenciais',
        'Criação de redes sociais corporativas'
      },
      correct = 2
    },
    {
      text = 'Qual a diferença entre vírus e worm?',
      options = {
        'Vírus precisa de ação do usuário; worm se espalha sozinho pela rede',
        'São a mesma coisa, apenas nomes diferentes',
        'Worm é mais antigo que vírus'
      },
      correct = 1
    },
  },
}

-- Estado para rastrear perguntas já usadas
local usedQuestions = {}
local currentWave = 0

-- Função para embaralhar array (Fisher-Yates shuffle)
local function shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(1, i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

-- Função para criar cópia da pergunta com respostas embaralhadas
local function shuffleQuestion(q)
  -- Criar array com índices e opções
  local indexed = {}
  for i, opt in ipairs(q.options) do
    table.insert(indexed, { originalIndex = i, text = opt })
  end

  -- Embaralhar
  shuffle(indexed)

  -- Criar nova pergunta com opções embaralhadas
  local newOptions = {}
  local newCorrect = 1
  for i, item in ipairs(indexed) do
    table.insert(newOptions, item.text)
    if item.originalIndex == q.correct then
      newCorrect = i
    end
  end

  return {
    text = q.text,
    options = newOptions,
    correct = newCorrect
  }
end

function Questions.reset()
  usedQuestions = {}
  currentWave = 0
end

function Questions.setWave(wave)
  currentWave = wave
end

function Questions.getForWave(wave)
  -- Determina dificuldade baseada na wave
  local difficulty
  if wave <= 6 then
    difficulty = 1  -- Fácil
  elseif wave <= 14 then
    difficulty = 2  -- Médio
  else
    difficulty = 3  -- Difícil
  end

  local pool = questionsByDifficulty[difficulty]
  if not pool then return nil end

  -- Filtra perguntas não usadas
  local available = {}
  for i, q in ipairs(pool) do
    local key = difficulty .. '_' .. i
    if not usedQuestions[key] then
      table.insert(available, { question = q, key = key })
    end
  end

  -- Se não há perguntas disponíveis nessa dificuldade, tenta outra
  if #available == 0 then
    -- Tenta dificuldade adjacente
    local altDiff = difficulty == 3 and 2 or (difficulty == 1 and 2 or 3)
    pool = questionsByDifficulty[altDiff]
    if pool then
      for i, q in ipairs(pool) do
        local key = altDiff .. '_' .. i
        if not usedQuestions[key] then
          table.insert(available, { question = q, key = key })
        end
      end
    end
  end

  -- Se ainda não há, retorna nil (todas esgotadas)
  if #available == 0 then
    return nil
  end

  -- Seleciona aleatoriamente entre as disponíveis
  local choice = available[math.random(1, #available)]
  usedQuestions[choice.key] = true

  -- Retorna pergunta com respostas embaralhadas
  return shuffleQuestion(choice.question)
end

-- Função legada para compatibilidade
function Questions.random()
  return Questions.getForWave(currentWave)
end

function Questions.allExhausted()
  local totalUsed = 0
  for _ in pairs(usedQuestions) do
    totalUsed = totalUsed + 1
  end
  -- Total de perguntas: 7 + 7 + 6 = 20
  return totalUsed >= 20
end

return Questions
