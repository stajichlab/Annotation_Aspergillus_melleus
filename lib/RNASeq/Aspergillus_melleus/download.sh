#!/usr/bin/bash
#SBATCH -p batch -N 1 -n 8 --mem 1gb

module load aspera
module load workspace/scratch

#~/bin/sra_download.pl --ascp -id $ASPERAKEY sra.txt

pigz -dc SRR1214252?/SRR1214252?_1.fastq.gz | perl -p -e 's/ \d+(\/\d+)/$1/' > $SCRATCH/Forward.fq
pigz -dc SRR1214252?/SRR1214252?_2.fastq.gz | perl -p -e 's/ \d+(\/\d+)/$1/' > $SCRATCH/Reverse.fq

pigz $SCRATCH/Forward.fq $SCRATCH/Reverse.fq
mv  $SCRATCH/Forward.fq.gz  $SCRATCH/Reverse.fq.gz .
