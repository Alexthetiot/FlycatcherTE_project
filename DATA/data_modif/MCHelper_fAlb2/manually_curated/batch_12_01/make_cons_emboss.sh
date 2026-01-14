#!/bin/bash

# dossier de sortie
OUTDIR="cons_emboss"
mkdir -p "$OUTDIR"

# boucle sur tous les .fst
for fst in *.fst; do
    # vérifier qu'il existe bien des fichiers .fst
    [ -e "$fst" ] || continue

    # nom de base sans extension
    base=$(basename "$fst" .fst)

    echo "Traitement de $fst"
    cons -sequence "$fst" -outseq "$OUTDIR/${base}.cons"
done
