#!/bin/bash
for filename in step-templates/*.json; do
    awk '{gsub(/\\n/,RS)}1' $filename > "$filename.human"
done
