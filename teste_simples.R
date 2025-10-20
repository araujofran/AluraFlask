# Script de teste simples para verificar a correção do erro
library(jsonlite, lib.loc='~/.local/lib/R/library')

# Simula uma resposta da API OpenAI (estrutura típica)
simular_resposta_openai <- function() {
  return('{
    "id": "chatcmpl-123",
    "object": "chat.completion",
    "created": 1677652288,
    "model": "gpt-4o-mini",
    "choices": [
      {
        "index": 0,
        "message": {
          "role": "assistant",
          "content": "Esta é uma resposta de teste da API OpenAI"
        },
        "finish_reason": "stop"
      }
    ],
    "usage": {
      "prompt_tokens": 9,
      "completion_tokens": 12,
      "total_tokens": 21
    }
  }')
}

# Função original (com erro)
processar_resposta_original <- function(content_text) {
  parsed <- tryCatch(fromJSON(content_text, simplifyVector = TRUE), error = function(e) NULL)
  
  # Verificação que causa o erro
  if (!is.null(parsed) && is.list(parsed) && "choices" %in% names(parsed)) {
    if (!is.null(parsed$choices[[1]]$message$content)) {
      return(parsed$choices[[1]]$message$content)
    }
  }
  
  return(content_text)
}

# Função corrigida
processar_resposta_corrigida <- function(content_text) {
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
  
  return(content_text)
}

# Teste
cat("=== TESTE DA FUNÇÃO ORIGINAL (COM ERRO) ===\n")
tryCatch({
  resposta_teste <- simular_resposta_openai()
  resultado_original <- processar_resposta_original(resposta_teste)
  cat("Resultado original:", resultado_original, "\n")
}, error = function(e) {
  cat("ERRO na função original:", e$message, "\n")
})

cat("\n=== TESTE DA FUNÇÃO CORRIGIDA ===\n")
resposta_teste <- simular_resposta_openai()
resultado_corrigido <- processar_resposta_corrigida(resposta_teste)
cat("Resultado corrigido:", resultado_corrigido, "\n")

# Teste com JSON malformado
cat("\n=== TESTE COM JSON MALFORMADO ===\n")
json_malformado <- '{"error": "invalid request"}'
resultado_malformado <- processar_resposta_corrigida(json_malformado)
cat("Resultado com JSON malformado:", resultado_malformado, "\n")