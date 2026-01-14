#!/bin/bash
set -euo pipefail

#############################
# CONFIGURATION
#############################

INPUT_DIR="align_seq"
OUTPUT_DIR="align_seq_rmgap"
GAP_THRESHOLD=80

#############################
# VÉRIFICATIONS
#############################

command -v t_coffee >/dev/null 2>&1 || {
    echo "ERREUR : t_coffee n'est pas disponible dans le PATH"
    exit 1
}

mkdir -p "$OUTPUT_DIR"

#############################
# TRAITEMENT
#############################

echo "=========================================="
echo "Suppression des colonnes riches en gaps"
echo "Seuil : ${GAP_THRESHOLD}%"
echo "=========================================="

for aln in "$INPUT_DIR"/*.maf; do
    [ -e "$aln" ] || continue

    base=$(basename "$aln")
    prefix="${base%.maf}"

    output="$OUTPUT_DIR/${prefix}.rmgap${GAP_THRESHOLD}.maf"

    echo "→ Traitement : $base"

    t_coffee \
        -other_pg seq_reformat \
        -in "$aln" \
        -action +rm_gap "$GAP_THRESHOLD" \
        > "$output"

    if [ -s "$output" ]; then
        echo "  ✓ Alignement nettoyé : $(basename "$output")"
    else
        echo "  ⚠ Fichier vide, ignoré"
        rm -f "$output"
    fi
done

echo ""
echo "=========================================="
echo "Terminé"
echo "Alignements nettoyés : $OUTPUT_DIR"
echo "=========================================="

