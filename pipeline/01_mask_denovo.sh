#!/bin/bash
#SBATCH -p batch --time 2-0:00:00 --ntasks 8 --nodes 1 --mem 24G --out logs/mask.%a.log
module load workspace/scratch
CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi

INDIR=$(realpath genomes)
OUTDIR=$(realpath genomes)

mkdir -p repeat_library

SAMPFILE=samples.csv
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPFILE | awk '{print $1}')
if [ $N -gt $(expr $MAX) ]; then
    MAXSMALL=$(expr $MAX)
    echo "$N is too big, only $MAXSMALL lines in $SAMPFILE"
    exit
fi

IFS=,
tail -n +2 $SAMPFILE | sed -n ${N}p | while read SPECIES STRAIN PHYLUM BIOPROJECT BIOSAMPLE LOCUS
do
  name=$(echo -n ${SPECIES}_${STRAIN} | perl -p -e 's/\s+/_/g')
  if [ ! -f $INDIR/${name}.sorted.fasta ]; then
     echo "Cannot find $name in $INDIR - may not have been run yet"
     exit
  fi
  echo "$name"
  
  if [ ! -f $OUTDIR/${name}.masked.fasta ]; then
     module load funannotate
     export AUGUSTUS_CONFIG_PATH=$(realpath lib/augustus/3.3/config)
     if [ -f repeat_library/${name}.repeatmodeler-library.fasta ]; then
    	  LIBRARY=$(realpath repeat_library/${name}.repeatmodeler-library.fasta)
     fi
     echo "LIBRARY is $LIBRARY"
     if [ ! -z $LIBRARY ]; then
    	 funannotate mask --cpus $CPU -i $INDIR/${name}.sorted.fasta -o $OUTDIR/${name}.masked.fasta -l $LIBRARY --method repeatmodeler
     else
       funannotate mask --cpus $CPU -i $INDIR/${name}.sorted.fasta -o $OUTDIR/${name}.masked.fasta --method repeatmodeler
       mv repeatmodeler-library.*.fasta ../repeat_library/${name}.repeatmodeler-library.fasta
       mv funannotate-mask.log ../logs/masklog_long.$name.log
     fi
     popd
  else
     echo "Skipping ${name} as masked already"
  fi
done
