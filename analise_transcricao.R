library(shiny)
library(jsonlite)
library(httr)
library(fs)
library(stringr)

# =========================
# INSIRA SUA CHAVE AQUI 👇
# =========================
OPENAI_API_KEY <- "sO"
MODEL <- "gpt-4o-mini"

# -------------------------
# PROMPT BASE (O SEU)
# -------------------------
prompt_base <- "
Você é um analista de transcrições de conversas. Sua tarefa é processar o conteúdo fornecido na chave `[Transcrição]`, extraindo informações específicas para análise de qualidade e desempenho.

Siga estas etapas rigorosamente:

1.  **Identificação dos Participantes**:
      * Identifique o **atendente** e o **cliente** da conversa.
      * Use os nomes ou identificadores correspondentes (ex: Leticia e Wendel).

2.  **Análise Sequencial e Estruturação em Blocos**:
      * Separe a transcrição em blocos sequenciais, onde cada bloco representa uma troca de assunto ou uma fase distinta da interação (ex: saudação, oferta de produto, resolução, etc.).
      * Para cada bloco, crie um objeto JSON com as seguintes chaves de valor:
          * \"bloco\": O número sequencial do bloco.
          * \"falantes\": Um objeto contendo os identificadores do \"atendente\" e do \"cliente\".
          * \"assunto_atendente\": Uma breve descrição do que o atendente está falando ou tentando fazer nesse bloco.
          * \"minutagem_trecho_chat_comprova_assunto_atendente\": A minutagem exata do trecho da transcrição que comprova o `assunto_atendente`.
          * \"trecho_chat_comprova_assunto_atendente\": O trecho literal da transcrição que comprova o `assunto_atendente`.
          * \"assunto_cliente\": Uma breve descrição do que o cliente está falando ou solicitando nesse bloco.
          * \"minutagem_trecho_chat_comprova_assunto_cliente\": A minutagem exata do trecho da transcrição que comprova o `assunto_cliente`.
          * \"trecho_chat_comprova_assunto_cliente\": O trecho literal da transcrição que comprova o `assunto_cliente`.
          * \"calculo_TMA\": O Tempo Médio de Atendimento do bloco. Calcule a diferença entre a minutagem da primeira fala do cliente e a da primeira fala do atendente no mesmo bloco.
          * \"calculo_TME\": O Tempo Médio de Espera do bloco. Calcule a diferença entre a minutagem da última fala do atendente e a da primeira fala do cliente no mesmo bloco.

3.  **Avaliação dos Critérios de Qualidade (Relacionamento com o Cliente)**:
      * Dentro de cada bloco, adicione uma chave \"avaliacao_qualidade\" que será um objeto contendo:
          * \"saudacao\" (pontuação 5 ou 0)
          * \"respeito_atendente\" (10 ou 0)
          * \"respeito_cliente\"
          * \"clareza_informacoes\" (10 ou 0)
          * \"linguagem_atendente\" (5 ou 0)
          * \"linguagem_cliente\"
          * \"experiencia_cliente\" (5 ou 0)
      * Para cada critério, adicione um campo \"trecho_chat_comprova\" com o trecho literal da transcrição.

4.  **Cálculo Final**:
      * Após a análise de todos os blocos, adicione:
          * \"TMA_TOTAL\": tempo total da conversa
          * \"nota_total\": soma das pontuações dos critérios de qualidade.

5.  **Formato de Saída**:
      * A resposta deve ser um objeto JSON único.
"

# -------------------------
# FUNÇÃO PARA CHAMAR OPENAI
# -------------------------
analisar_transcricao <- function(texto_transcricao) {
  body <- list(
    model = MODEL,
    messages = list(
      list(role = "system", content = prompt_base),
      list(role = "user", content = paste0("[Transcrição]{\n", texto_transcricao, "\n}"))
    ),
    temperature = 0.2
  )
  
  response <- POST(
    url = "https://api.openai.com/v1/chat/completions",
    add_headers(
      Authorization = paste("Bearer", OPENAI_API_KEY),
      "Content-Type" = "application/json"
    ),
    body = toJSON(body, auto_unbox = TRUE)
  )
  
  content_text <- content(response, "text", encoding = "UTF-8")
  
  parsed <- tryCatch(fromJSON(content_text, simplifyVector = FALSE), error = function(e) NULL)
  
  # Verificação segura para evitar erro de vetor atômico
  if (!is.null(parsed) && is.list(parsed) && "choices" %in% names(parsed)) {
    # Verifica se choices é uma lista e tem pelo menos um elemento
    if (is.list(parsed$choices) && length(parsed$choices) > 0) {
      # Verifica se o primeiro elemento de choices tem a estrutura esperada
      if (is.list(parsed$choices[[1]]) && "message" %in% names(parsed$choices[[1]])) {
        if (is.list(parsed$choices[[1]]$message) && "content" %in% names(parsed$choices[[1]]$message)) {
          return(parsed$choices[[1]]$message$content)
        }
      }
    }
  }
  
  # Se chegou aqui, retorna o texto bruto (erro ou resposta não estruturada)
  return(content_text)
}

# -------------------------
# INTERFACE SHINY
# -------------------------
ui <- fluidPage(
  titlePanel("Análise Inteligente de Transcrições (OpenAI)"),
  sidebarLayout(
    sidebarPanel(
      fileInput("file_input", "Escolha o arquivo TXT ou JSON", accept = c(".txt", ".json")),
      actionButton("analisar_btn", "Analisar com IA")
    ),
    mainPanel(
      verbatimTextOutput("status_output")
    )
  )
)

# -------------------------
# SERVIDOR SHINY
# -------------------------
server <- function(input, output) {
  observeEvent(input$analisar_btn, {
    req(input$file_input)
    
    output$status_output <- renderText({
      arquivo <- input$file_input$datapath
      extensao <- tools::file_ext(arquivo)
      
      conteudo_bruto <- paste(readLines(arquivo, encoding = "UTF-8"), collapse = "\n")
      
      # Extrai conteúdo da transcrição
      if (grepl("Transcrição", conteudo_bruto, ignore.case = TRUE)) {
        match <- str_match(conteudo_bruto, "Transcri[cç][aã]o\\s*:?\\s*\\{?(.*)\\}?$")
        conteudo_transcricao <- ifelse(!is.na(match[2]), match[2], conteudo_bruto)
      } else if (extensao == "json") {
        json_data <- tryCatch(fromJSON(arquivo), error = function(e) NULL)
        conteudo_transcricao <- if (!is.null(json_data$Transcrição)) json_data$Transcrição else conteudo_bruto
      } else {
        conteudo_transcricao <- conteudo_bruto
      }
      
      if (nchar(conteudo_transcricao) < 50) {
        return("❌ Erro: transcrição muito curta ou não encontrada no arquivo.")
      }
      
      resultado <- analisar_transcricao(conteudo_transcricao)
      
      output_dir <- "L:/Relacionamento com Cliente - Qualidade/Célula Qualidade/Francisco/PROJETOS_MANUTENCAO/CHAT_GI_MONITORIA/PASSO3_BLOCOS_IA"
      dir_create(output_dir, recurse = TRUE)
      
      nome_base <- tools::file_path_sans_ext(basename(input$file_input$name))
      caminho_saida <- file.path(output_dir, paste0(nome_base, "_IA.json"))
      
      writeLines(resultado, caminho_saida, useBytes = TRUE)
      
      paste0("✅ Análise concluída e salva em:\n", caminho_saida)
    })
  })
}

# -------------------------
# RODAR APP
# -------------------------
shinyApp(ui = ui, server = server)