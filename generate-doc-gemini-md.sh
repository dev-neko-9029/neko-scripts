#!/bin/bash

# ------------------------------------------------------------
# Script: generate-doc-gemini-md.sh
# Descripción: Genera documentación en Markdown de un proyecto
#              basado en microservicios, analizando archivos y
#              deduciendo el propósito del servicio según su
#              contenido y nombre de carpeta.
# ------------------------------------------------------------

OUTPUT_FILE="project_documentation.md"
TEMP_DIR=$(mktemp -d)
PARTIAL_FILE="$TEMP_DIR/partials.txt"
PROJECT_NAME=$(basename "$(pwd)")

if [ -z "$GEMINI_TOKEN" ]; then
  echo "Error: falta el token de Gemini."
  echo "Por favor, ejecuta:"
  echo "export GEMINI_TOKEN=<your_token_here>"
  exit 1
fi

echo "Analizando archivos del proyecto ${PROJECT_NAME}..."

find . -type f \
  ! -path "*/.git/*" \
  ! -path "*/node_modules/*" \
  ! -path "*/.github/*" \
  ! -path "*/.config/*" \
  ! -path "*/dist/*" \
  ! -path "*/build/*" \
  ! -path "*/__pycache__/*" \
  ! -name "*.png" \
  ! -name "*.jpg" \
  ! -name "*.jpeg" \
  ! -name "*.gif" \
  ! -name "*.zip" \
  ! -name "*.tar" \
  ! -name "*.gz" \
  ! -name "template.yaml" \
  ! -name "samconfig.toml" \
  ! -name "$OUTPUT_FILE" \
| while read -r FILE; do
    CONTENT=$(head -n 500 "$FILE")
    PROMPT="Analiza el siguiente archivo del proyecto llamado '${PROJECT_NAME}'. 
Explica, de manera breve y comprensible para una persona no técnica, 
qué papel cumple este archivo dentro del proyecto y cómo contribuye 
a la funcionalidad general. No incluyas fragmentos de código.

Archivo: ${FILE}
Contenido:
${CONTENT}"
    
    RESPONSE=$(curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_TOKEN}" \
      -H "Content-Type: application/json" \
      -d @- <<EOF
{
  "contents": [
    {"role": "user", "parts": [{"text": "$PROMPT"}]}
  ]
}
EOF
)
    DESC=$(echo "$RESPONSE" | grep -o '"text":".*"' | sed 's/"text":"\(.*\)"/\1/' | sed 's/\\n/\n/g' | sed 's/\\"/"/g')
    if [ -n "$DESC" ]; then
      echo "- ${FILE}: ${DESC}" >> "$PARTIAL_FILE"
    fi
done

echo "Generando documentación final basada en los análisis..."

CONTEXT=$(head -c 200000 "$PARTIAL_FILE" | sed 's/"/\\"/g')

FINAL_PROMPT=$(cat <<EOF
Eres un experto en documentación técnica y comunicación empresarial.
Tu tarea es crear la documentación final de un microservicio llamado "${PROJECT_NAME}".

El objetivo es que cualquier persona (incluso sin perfil técnico) 
entienda qué hace el servicio, cuál es su propósito, cómo parece estar construido 
y cómo encajaría dentro de un ecosistema de microservicios empresariales.

Debes basarte tanto en las descripciones de los archivos como 
en el nombre del proyecto, que indica su propósito funcional.

Usa el siguiente formato Markdown:

# ${PROJECT_NAME}

## Descripción General
Describe qué hace el microservicio y qué problema resuelve.

## Propósito e Interpretación del Servicio
Interpreta el rol del servicio dentro de un ecosistema mayor (por ejemplo, orquestador financiero, servicio de cálculos, autenticación, notificaciones, etc.)

## Arquitectura y Componentes
Explica la estructura general detectada (módulos, capas, rutas, archivos principales).

## Tecnologías y Herramientas
Indica los lenguajes, frameworks, servicios o infraestructuras inferidas.

## Flujo de Operación
Explica cómo parece funcionar el servicio de forma narrativa.

## Archivos y Módulos Clave
Resume los archivos relevantes y lo que aportan.

## Público Objetivo
Describe para quién parece estar diseñado (otros servicios, equipos internos, clientes).

## Contexto y Origen
Intenta deducir en qué entorno o sistema mayor encaja el servicio.

## Observaciones Finales
Notas sobre estilo, calidad, mantenibilidad o estructura detectada.

A continuación, las descripciones de los archivos obtenidas:

${CONTEXT}
EOF
)

FINAL_RESPONSE=$(curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=${GEMINI_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "contents": [
    {"role": "user", "parts": [{"text": "$FINAL_PROMPT"}]}
  ]
}
EOF
)

FINAL_DOC=$(echo "$FINAL_RESPONSE" | grep -o '"text":".*"' | sed 's/"text":"\(.*\)"/\1/' | sed 's/\\n/\n/g' | sed 's/\\"/"/g')

if [ -z "$FINAL_DOC" ]; then
  echo "No se pudo generar la documentación final. Verifica el token o la cuota de la API."
  rm -rf "$TEMP_DIR"
  exit 1
fi

echo "$FINAL_DOC" > "$OUTPUT_FILE"

rm -rf "$TEMP_DIR"

echo "Documentación generada en $OUTPUT_FILE"
