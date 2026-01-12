#!/bin bash
for f in ind_seq/*\#*; do
    mv "$f" "${f//\#/_}"
done
