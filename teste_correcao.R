# Script de teste para verificar a correção do erro
library(jsonlite)
library(httr)

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

# Função corrigida para processar resposta
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
  
  # Se chegou aqui, retorna o texto bruto (erro ou resposta não estruturada)
  return(content_text)
}

# Teste
cat("Testando a função corrigida...\n")
resposta_teste <- simular_resposta_openai()
resultado <- processar_resposta_corrigida(resposta_teste)
cat("Resultado:", resultado, "\n")

# Teste com JSON malformado
cat("\nTestando com JSON malformado...\n")
json_malformado <- '{"error": "invalid request"}'
resultado2 <- processar_resposta_corrigida(json_malformado)
cat("Resultado:", resultado2, "\n")