#!/bin/bash

#SBATCH -p stajichlab --ntasks 24 --nodes 1 --mem 32G --out logs/RModeler.%a.log
#SBATCH -a 1
# default array job is 1

module load RepeatModeler
CPU=4
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi
CPUFOUR=$(expr $CPU / 4)
if [ $CPUFOUR == 0 ]; then
	CPUFOUR=1
fi
INDIR=$(realpath genomes)
OUTDIR=$(realpath genomes)
LIBDIR=$(realpath repeat_library)
mkdir -p $LIBDIR

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
     echo "Cannot find $name.sorted.fasta in $INDIR - may not have been run yet"
     exit
  fi
  echo "$name"
  LIBRARY=$LIBDIR/${name}.repeatmodeler-library.fasta
  if [ ! -f $LIBRARY ]; then
	  hostname
	  module load RepeatModeler
	  pushd $SCRATCH
	  BuildDatabase -name ${name} $INDIR/${name}.sorted.fasta
	  RepeatModeler -database ${name} -pa $CPUFOUR -LTRStruct
	  rsync -a $SCRATCH/RM_*/consensi.fa.classified $LIBRARY
	  popd
	  echo "making backup"
	  rsync -a $SCRATCH ./RM_run_copy_$$
  fi
done
