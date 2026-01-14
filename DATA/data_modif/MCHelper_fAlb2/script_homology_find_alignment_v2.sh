#!/bin/bash

# Configuration des chemins
CSV_FILE="MCHelper_fAlb2_final_priority.csv"
IND_SEQ_DIR="ind_seq"
GENOME="$HOME/FlycatcherTE_project/DATA/data_modif/fAlb2.0.CLEAN_withMT.fa"
BLAST_SCRIPT="/home/athetiot/FlycatcherTE_project/TE_ManAnnot/bin/make_fasta_from_blast_modif.sh"
MIN_LENGTH=0
FLANK=500
OUTPUT_DIR="processed_sequences"

# Vérifier que les fichiers/dossiers nécessaires existent
if [ ! -f "$CSV_FILE" ]; then
    echo "ERREUR: Fichier CSV non trouvé: $CSV_FILE"
    exit 1
fi

if [ ! -d "$IND_SEQ_DIR" ]; then
    echo "ERREUR: Dossier ind_seq non trouvé: $IND_SEQ_DIR"
    exit 1
fi

if [ ! -f "$GENOME" ]; then
    echo "ERREUR: Fichier génome non trouvé: $GENOME"
    exit 1
fi

if [ ! -f "$BLAST_SCRIPT" ]; then
    echo "ERREUR: Script make_fasta_from_blast.sh non trouvé: $BLAST_SCRIPT"
    exit 1
fi

# Créer le répertoire de sortie s'il n'existe pas
mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "Extraction des séquences depuis le CSV"
echo "=========================================="

# Extraire uniquement les noms de famille (première colonne) qui respectent les critères
# No of good blast hits >= 10 ET No of Pfam conserved domains >= 1
# On utilise aussi 'sort -u' pour ne garder que les occurrences uniques
awk -F',' 'NR==1 {
    for(i=1; i<=NF; i++) {
        if($i=="Family_name") fname=i;
        if($i=="No of good blast hits") blast=i;
        if($i=="No of Pfam conserved domains") pfam=i;
    }
    next
}
NR>1 && $blast>=10 && $pfam>=1 {
    # Extraire seulement le nom de la famille (première colonne avant le premier tab)
    split($fname, arr, "\t");
    print arr[1]
}' "$CSV_FILE" | sort -u > selected_families.txt

if [ ! -s selected_families.txt ]; then
    echo "ERREUR: Aucune famille sélectionnée. Vérifiez les noms de colonnes dans le CSV."
    echo "Affichage de l'en-tête du CSV:"
    head -1 "$CSV_FILE"
    exit 1
fi

echo "Nombre de familles uniques sélectionnées: $(wc -l < selected_families.txt)"
echo ""

# Afficher les premières familles sélectionnées
echo "Premières familles sélectionnées (uniques):"
head -20 selected_families.txt
echo ""

echo "=========================================="
echo "Recherche des fichiers correspondants"
echo "=========================================="

# Créer un fichier pour stocker les correspondances
> matched_files.txt

# Pour chaque nom extrait, chercher TOUS les fichiers correspondants dans ind_seq
while IFS= read -r family_name; do
    # Retirer les espaces et retours chariot éventuels
    family_name=$(echo "$family_name" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -z "$family_name" ]; then
        continue
    fi
    
    # Chercher TOUS les fichiers qui commencent par ce nom dans ind_seq
    # Le nom du CSV est tronqué, donc on cherche les fichiers qui commencent par ce pattern
    found_files=$(find "$IND_SEQ_DIR" -type f -name "${family_name}*.fa" 2>/dev/null)
    
    if [ -n "$found_files" ]; then
        # Compter le nombre de fichiers trouvés pour cette famille
        num_files=$(echo "$found_files" | wc -l)
        echo "✓ Trouvé $num_files fichier(s) pour $family_name:"
        
        # Ajouter chaque fichier trouvé à la liste
        while IFS= read -r file; do
            echo "$file" >> matched_files.txt
            echo "  - $(basename "$file")"
        done <<< "$found_files"
    else
        echo "✗ Aucun fichier trouvé pour: $family_name"
    fi
done < selected_families.txt

if [ ! -s matched_files.txt ]; then
    echo ""
    echo "ERREUR: Aucun fichier correspondant trouvé dans $IND_SEQ_DIR"
    echo "Fichiers disponibles dans ind_seq:"
    ls -1 "$IND_SEQ_DIR" | head -10
    exit 1
fi

echo ""
echo "Nombre total de fichiers à traiter: $(wc -l < matched_files.txt)"
echo ""

echo "=========================================="
echo "Traitement des séquences"
echo "=========================================="

# Compteur pour le suivi
total=$(wc -l < matched_files.txt)
current=0

# Traiter chaque fichier trouvé
while IFS= read -r fasta_file; do
    current=$((current + 1))
    
    # Extraire le nom de base du fichier
    basename_file=$(basename "$fasta_file")
    family_id="${basename_file%.fa}"
    
    echo ""
    echo "[$current/$total] Traitement de: $basename_file"
    echo "----------------------------------------"
    
    # Étape 1: make_fasta_from_blast.sh
    echo "  → Exécution de make_fasta_from_blast.sh..."
    bash "$BLAST_SCRIPT" "$GENOME" "$fasta_file" "$MIN_LENGTH" "$FLANK" 2>&1 | grep -v "^$"
    
    blast_output="${fasta_file}.blast.bed.fa"
    
    if [ -f "$blast_output" ]; then
        # Compter le nombre de séquences dans le fichier BLAST
        num_seqs=$(grep -c "^>" "$blast_output" 2>/dev/null || echo "0")
        echo "  ✓ Fichier BLAST créé: $blast_output ($num_seqs séquences)"
        
        if [ "$num_seqs" -gt 0 ]; then
            # Étape 2: MAFFT alignment
            maf_output="${OUTPUT_DIR}/${family_id}.maf"
            echo "  → Alignement avec MAFFT..."
            mafft --quiet "$blast_output" > "$maf_output" 2>/dev/null
            
            if [ -f "$maf_output" ] && [ -s "$maf_output" ]; then
                echo "  ✓ Alignement créé: $maf_output"
            else
                echo "  ✗ Erreur lors de la création de l'alignement"
            fi
        else
            echo "  ⚠ Aucune séquence trouvée, alignement ignoré"
        fi
    else
        echo "  ✗ Erreur: fichier BLAST non créé"
    fi
    
done < matched_files.txt

echo ""
echo "=========================================="
echo "Traitement terminé!"
echo "=========================================="
echo "Fichiers d'alignement générés dans: $OUTPUT_DIR"
echo "Nombre total de fichiers traités: $current"
echo ""

# Afficher un résumé
maf_count=$(ls -1 "$OUTPUT_DIR"/*.maf 2>/dev/null | wc -l)
echo "Résumé des fichiers .maf créés: $maf_count fichiers"
if [ $maf_count -gt 0 ]; then
    echo ""
    echo "Liste des fichiers .maf créés:"
    ls -lh "$OUTPUT_DIR"/*.maf | awk '{print $9, "(" $5 ")"}'
fi

# Nettoyer les fichiers temporaires
echo ""
read -p "Voulez-vous supprimer les fichiers temporaires (selected_families.txt, matched_files.txt)? (o/n): " cleanup
if [ "$cleanup" = "o" ] || [ "$cleanup" = "O" ]; then
    rm -f selected_families.txt matched_files.txt
    echo "Fichiers temporaires supprimés."
fi
