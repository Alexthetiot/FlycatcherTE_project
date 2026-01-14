#!/bin/bash
set -euo pipefail

#############################
# CONFIGURATION
#############################

INPUT_DIR="blast_seq"
SUB_DIR="subsampled_seq"
ALIGN_DIR="align_seq"

MAX_SEQ=100
THREADS=4

#############################
# VÉRIFICATIONS
#############################

command -v mafft >/dev/null 2>&1 || {
    echo "ERREUR : MAFFT n'est pas disponible dans le PATH"
    exit 1
}

command -v seqtk >/dev/null 2>&1 || {
    echo "ERREUR : seqtk n'est pas disponible dans le PATH"
    exit 1
}

mkdir -p "$SUB_DIR" "$ALIGN_DIR"

#############################
# TRAITEMENT
#############################

echo "=========================================="
echo "Subsampling + alignement MAFFT"
echo "=========================================="

for fasta in "$INPUT_DIR"/*.fa.blast.flank.bed.fa; do
    [ -e "$fasta" ] || continue

    base=$(basename "$fasta")
    prefix="${base%%.fa*}"

    echo ""
    echo "Traitement : $base"

    # Compter le nombre de séquences
    nseq=$(grep -c "^>" "$fasta")

    echo "  → Nombre de séquences : $nseq"

    subsampled_fa="$SUB_DIR/${prefix}.fa"
    output_maf="$ALIGN_DIR/${prefix}.maf"

    if [ "$nseq" -gt "$MAX_SEQ" ]; then
        echo "  → Subsampling à $MAX_SEQ séquences"
        seqtk sample -s100 "$fasta" "$MAX_SEQ" > "$subsampled_fa"
    else
        echo "  → ≤ $MAX_SEQ séquences : pas de subsampling"
        cp "$fasta" "$subsampled_fa"
    fi

    # Vérification post-subsampling
    final_nseq=$(grep -c "^>" "$subsampled_fa" || echo 0)

    if [ "$final_nseq" -lt 2 ]; then
        echo "  ⚠ Pas assez de séquences pour aligner, ignoré"
        continue
    fi

    echo "  → Alignement MAFFT ($final_nseq séquences)"
    mafft --thread "$THREADS" --quiet "$subsampled_fa" > "$output_maf"

    if [ -s "$output_maf" ]; then
        echo "  ✓ Alignement créé : $(basename "$output_maf")"
    else
        echo "  ✗ Erreur MAFFT"
    fi
done

echo ""
echo "=========================================="
echo "Terminé"
echo "Alignements : $ALIGN_DIR"
echo "Fasta finaux : $SUB_DIR"
echo "=========================================="

