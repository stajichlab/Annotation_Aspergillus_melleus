#!/bin/bash
#SBATCH -p intel,batch --time 3-0:00:00 --ntasks 24 --nodes 1 --mem 96G --out logs/predict.%a.log

module unload miniconda2
module unload anaconda3
module unload perl
module unload python
module load funannotate

CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi

BUSCO=fungi_odb10 # This could be changed to the core BUSCO set you want to use
INDIR=genomes
OUTDIR=annotate
PREDS=$(realpath prediction_support)
mkdir -p $OUTDIR
SAMPFILE=samples.csv
INFORMANT=$(realpath lib/informant_proteins.aa)
N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=`wc -l $SAMPFILE | awk '{print $1}'`

if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPFILE"
    exit
fi

export AUGUSTUS_CONFIG_PATH=$(realpath lib/augustus/3.3/config)

export FUNANNOTATE_DB=/bigdata/stajichlab/shared/lib/funannotate_db
# make genemark key link required to run it
if [ ! -s ~/.gm_key ]; then
	module  load  genemarkESET/4.62_lic
	GMFOLDER=`dirname $(which gmhmme3)`
  ln -s $GMFOLDER/.gm_key ~/.gm_key
  module unload genemarkESET
fi
SEED_SPECIES=anidulans

IFS=,
tail -n +2 $SAMPFILE | sed -n ${N}p | while read SPECIES STRAIN PHYLUM BIOSAMPLE BIOPROJECT LOCUSTAG
do
    SEQCENTER=UCR_Harvard
    BASE=$(echo -n "$SPECIES $STRAIN" | perl -p -e 's/\s+/_/g')
    echo "sample is $BASE"
    MASKED=$(realpath $INDIR/$BASE.masked.fasta)
    if [ ! -f $MASKED ]; then
      echo "Cannot find $BASE.masked.fasta in $INDIR - may not have been run yet"
      exit
    fi
    mkdir $BASE.predict.$$
    pushd $BASE.predict.$$
    if [[ -f $PREDS/$BASE.genemark.gtf ]]; then
    funannotate predict --cpus $CPU --keep_no_stops --SeqCenter $SEQCENTER --busco_db $BUSCO --optimize_augustus \
        --strain $STRAIN --min_training_models 100 --AUGUSTUS_CONFIG_PATH $AUGUSTUS_CONFIG_PATH \
        -i ../$INDIR/$BASE.masked.fasta --name $LOCUSTAG  \
        -s "$SPECIES"  -o ../$OUTDIR/$BASE 
    #--protein_evidence $INFORMANT \
    #--busco_seed_species $SEED_SPECIES --genemark_gtf $PREDS/$BASE.genemark.gtf
    else
    funannotate predict --cpus $CPU --keep_no_stops --SeqCenter $SEQCENTER --busco_db $BUSCO --optimize_augustus \
	--strain $STRAIN --min_training_models 100 --AUGUSTUS_CONFIG_PATH $AUGUSTUS_CONFIG_PATH \
	-i ../$INDIR/$BASE.masked.fasta --name $LOCUSTAG \
	-s "$SPECIES"  -o ../$OUTDIR/$BASE 
    #--protein_evidence $INFORMANT \
    #--busco_seed_species $SEED_SPECIES
    fi
    popd
    rmdir $BASE.predict.$$
done
