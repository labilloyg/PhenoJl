#!/usr/bin/env bash
DATADIR=$1
DATAFILE=$2
CONFIGFILE=$3

if [ -z "$3" ]
    then
        PHENO_CMD="PhenoJl /fixtures/${DATAFILE}"
    else
        PHENO_CMD="PhenoJl /fixtures/${DATAFILE} --configfile /fixtures/${CONFIGFILE}"
fi

echo "Command: $PHENO_CMD"
docker run --rm -v $DATADIR:/fixtures labillgp/phenojl bash -c "$PHENO_CMD"
echo "Done."
