#!/bin/bash

symlink-public-resources() {
    public_source_dir=${1}
    target_dir=${2}

    # need to wait until the dataset has been mounted (async on Paperspace's end)
    COUNTER=0
    # set a timeout of 300s/5m for the while loop as a safety measure
    while [ $COUNTER -lt 300 ] && ( [ ! -d ${public_source_dir} ] || [ -z "$(ls -A ${public_source_dir})" ] )
    do
        echo "Waiting for dataset "${public_source_dir}" to be mounted..."
        sleep 1
        ((COUNTER++))
        if [ $COUNTER -eq 300 ]; then
            echo "Warning! Abandoning symlink - source Dataset ${public_source_dir} has not been mounted & populated after 5m."
            return
        fi
    done

    echo "Symlinking - ${public_source_dir} to ${target_dir}"

    # Make sure it exists otherwise you'll copy your current dir
    mkdir -p ${target_dir}
    workdir="/fusedoverlay/workdirs/${public_source_dir}"
    upperdir="/fusedoverlay/upperdir/${public_source_dir}"
    mkdir -p ${workdir}
    mkdir -p ${upperdir}
    fuse-overlayfs -o lowerdir=${public_source_dir},upperdir=${upperdir},workdir=${workdir} ${target_dir}

}

if [ ! "$(command -v fuse-overlayfs)" ]
then
    echo "fuse-overlayfs not found installing - please update to our latest image"
    apt update -y
    apt install -o DPkg::Lock::Timeout=120 -y psmisc libfuse3-dev fuse-overlayfs
fi

echo "Starting preparation of datasets"

# symlink exe_cache files
symlink-public-resources "${PUBLIC_DATASET_DIR}/poplar-executables-tf2-3-1" $POPLAR_EXECUTABLE_CACHE_DIR
# symlink ogbn_arxiv dataset for cluster gcn notebook
symlink-public-resources "${PUBLIC_DATASET_DIR}/ogbn_arxiv" "${DATASET_DIR}/ogbn_arxiv"
# symlink OGB-specific folders
symlink-public-resources "${PUBLIC_DATASET_DIR}/ogb_lsc_pcqm4mv2/datasets" "${OGB_DATASET_DIR}"
symlink-public-resources "${PUBLIC_DATASET_DIR}/ogb_lsc_pcqm4mv2/checkpoints" "${OGB_CHECKPOINT_DIR}"

# Make the custom ops for the OGB notebooks
python -m pip install -r /notebooks/ogb-competition/requirements.txt
cd "/notebooks/ogb-competition/${OGB_SUBMISSION_CODE}"
make -C data_utils/feature_generation
make -C static_ops
cd -


echo "Finished running setup.sh."
# Run automated test if specified
if [[ "$1" == "test" ]]; then

    bash /notebooks/.gradient/automated-test.sh "${@:2}"
elif [[ "$2" == "test" ]]; then
    bash /notebooks/.gradient/automated-test.sh "${@:3}"
fi
