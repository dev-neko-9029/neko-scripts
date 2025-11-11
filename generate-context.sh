#!/bin/bash

# Archivo de salida
OUTPUT_FILE="context.txt"

# Limpiar si ya existe
> "$OUTPUT_FILE"

# Recorre todos los archivos (excepto .git y el propio context.txt)
find . -type f ! -path "*/.git/*" ! -name "context.txt" | while read -r FILE; do
  echo "// archivo en ubicacion ${FILE}" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  cat "$FILE" >> "$OUTPUT_FILE"
  echo -e "\n\n" >> "$OUTPUT_FILE"
done

echo "✅ Contexto generado en $OUTPUT_FILE"
