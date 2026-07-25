#!/bin/bash

# Script para ejecutar el script de AWX con parámetros
# Uso: ./script.sh <HOST> <TOKEN>

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}Script de Activación SCM Workflows para AWX${NC}"
    echo ""
    echo "Uso: $0 [HOST] [TOKEN]"
    echo ""
    echo "Parámetros:"
    echo "  HOST    URL del servidor AWX (ej: <host>)"
    echo "  TOKEN   Token de autenticación de AWX"
    echo ""
    echo "Si no se proporcionan parámetros, el script los solicitará interactivamente."
    echo ""
    echo "Ejemplo:"
    echo "  $0 <host> <token>"
    echo ""
    echo "Opciones:"
    echo "  --help  Mostrar esta ayuda"
    exit 0
}

# Verificar si se pide ayuda
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
fi

# Asignar parámetros
HOST="$1"
TOKEN="$2"

# Si no se proporcionaron parámetros, solicitarlos interactivamente
if [[ -z "$HOST" ]] || [[ -z "$TOKEN" ]]; then
    echo -e "${YELLOW}No se proporcionaron todos los parámetros.${NC}"
    echo -e "${BLUE}Puedes ejecutar este script pasando los parámetros directamente:${NC}"
    echo -e "  $0 <HOST> <TOKEN>\n"
    
    read -p "Introduce la URL de tu AWX (ej: <host>): " HOST
    read -sp "Introduce tu Token de AWX: " TOKEN
    echo ""
fi

# Validar que se hayan proporcionado los parámetros
if [[ -z "$HOST" ]] || [[ -z "$TOKEN" ]]; then
    echo -e "${RED}[!] El host y el token son obligatorios.${NC}"
    exit 1
fi

echo -e "${GREEN}🚀 Ejecutando script de AWX...${NC}"
echo -e "${YELLOW}📡 Host: $HOST${NC}"
echo -e "${YELLOW}🔑 Token: ${TOKEN:0:10}...${TOKEN: -5}${NC}"
echo ""

# Verificar si existe el archivo del script
SCRIPT_FILE="activar_scm_workflows.js"
if [[ ! -f "$SCRIPT_FILE" ]]; then
    echo -e "${RED}[!] No se encontró el archivo $SCRIPT_FILE${NC}"
    echo -e "${YELLOW}Creando archivo $SCRIPT_FILE...${NC}"
    
    # Crear el archivo JavaScript con el código proporcionado
    cat > "$SCRIPT_FILE" << 'EOF'
const readline = require('readline/promises');
const { stdin: input, stdout: output } = require('process');

// Desactivar alertas SSL por si tu AWX usa certificados internos/autofirmados
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

async function corregirWorkflows() {
    let host = process.argv[2];
    let token = process.argv[3];

    // Si no se pasan argumentos, se solicitan de forma interactiva en la terminal
    if (!host || !token) {
        console.log("Puedes ejecutar este script pasando los parámetros directamente:");
        console.log("  node activar_scm_workflows.js <HOST> <TOKEN>\n");

        const rl = readline.createInterface({ input, output });
        host = await rl.question('Introduce la URL de tu AWX (ej: <host>): ');
        token = await rl.question('Introduce tu Token de AWX: ');
        rl.close();
    }

    if (!host || !token) {
        console.error("[!] El host y el token son obligatorios.");
        process.exit(1);
    }

    // Asegurar formato correcto de la URL
    if (!host.startsWith('http')) {
        host = `https://${host}`;
    }
    host = host.replace(/\/$/, ""); 

    let url = `${host}/api/v2/workflow_job_templates/`;
    const headers = {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
    };

    console.log(`[*] Conectando a AWX en: ${host}`);
    console.log(`[*] Buscando Workflow Job Templates...\n`);

    let contadorActualizados = 0;
    let contadorOmitidos = 0;

    while (url) {
        try {
            const response = await fetch(url, { headers });
            
            if (!response.ok) {
                throw new Error(`Error HTTP: ${response.status} ${response.statusText}`);
            }

            const data = await response.json();
            const workflows = data.results || [];

            for (const wf of workflows) {
                const wfId = wf.id;
                const wfName = wf.name;
                const askScmBranch = wf.ask_scm_branch_on_launch || false;

                if (!askScmBranch) {
                    console.log(`[+] Modificando -> Workflow [${wfId}] '${wfName}'`);
                    console.log(`    Estado anterior: DESACTIVADO. Activando 'Ask on Launch' para SCM Branch...`);

                    const patchUrl = `${host}/api/v2/workflow_job_templates/${wfId}/`;
                    
                    try {
                        const patchResponse = await fetch(patchUrl, {
                            method: 'PATCH',
                            headers,
                            body: JSON.stringify({ ask_scm_branch_on_launch: true })
                        });

                        if (!patchResponse.ok) {
                            throw new Error(`Error al actualizar [${patchResponse.status}]`);
                        }

                        console.log(`    [OK] ¡Activado con éxito!\n`);
                        contadorActualizados++;
                    } catch (patchErr) {
                        console.error(`    [ERROR] No se pudo actualizar el workflow ${wfId}: ${patchErr.message}\n`);
                    }
                } else {
                    console.log(`[-] Omitiendo -> Workflow [${wfId}] '${wfName}' ya lo tiene activado.\n`);
                    contadorOmitidos++;
                }
            }

            // Manejo de la paginación de AWX
            url = data.next;
            if (url && !url.startsWith('http')) {
                url = `${host}${url}`;
            }

        } catch (err) {
            console.error(`[!] Error de conexión con la API: ${err.message}`);
            process.exit(1);
        }
    }

    console.log("--- Resumen de ejecución ---");
    console.log(`Workflows actualizados: ${contadorActualizados}`);
    console.log(`Workflows omitidos (ya listos): ${contadorOmitidos}`);
}

corregirWorkflows();
EOF
    
    echo -e "${GREEN}✅ Archivo $SCRIPT_FILE creado${NC}"
fi

# Ejecutar el script de Node.js con los parámetros
echo -e "${GREEN}🔧 Ejecutando script...${NC}"
echo ""

node "$SCRIPT_FILE" "$HOST" "$TOKEN"

# Guardar el código de salida
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "\n${GREEN}✅ Ejecución completada exitosamente${NC}"
else
    echo -e "\n${RED}❌ Error en la ejecución (código: $EXIT_CODE)${NC}"
fi

exit $EXIT_CODE
