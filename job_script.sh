#! /bin/bash

# This is a naive job script that uses for loop to launch jobs for hyperparameter
# sweep. The script serves both as a launcher script that should be run on the
# login node and a job script that slurm invokes on the compute nodes. The launcher
# script function is triggered when the script is invoked without any argument.

if [ -z "$1" ]; then  # Check if the script is invoked without any argument
    # Launcher script part
    # Get the current script directory. The script directory variable will be used later.
    SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    cd "$SCRIPT_DIR"

    # A simple function that wraps the slurm configurations
    slurm_run () {
        sbatch \
            --job-name=example_cql \
            --time=72:00:00 \
            --account=co_rail \
            --qos=rail_gpu3_normal \
            --partition=savio3_gpu \
            --nodes=1 \
            --ntasks=1 \
            --cpus-per-task=4 \
            --mem=24G \
            --gres=gpu:TITAN:1 \
            $@
    }

    # The loop for launching jobs. Hyperparameter configurations are passed as
    # script arguments.
    for env in 'hopper-medium-v2' 'walker2d-medium-replay-v2'; do
        for seed in 42 24 37; do
            slurm_run "${BASH_SOURCE[0]}" $SCRIPT_DIR $env $seed
        done
    done

else
    # Receive arguments
    export SCRIPT_DIR=$1
    export ENV=$2
    export SEED=$3
    export PROJECT_HOME=$SCRIPT_DIR

    # Create log output directory
    OUTPUT_DIR="$PROJECT_HOME/experiment_output/"
    EXP_NAME='example_cql_1'
    mkdir -p $OUTPUT_DIR/$EXP_NAME
    cp "${BASH_SOURCE[0]}" $OUTPUT_DIR/$EXP_NAME

    # Command to run this hyperparameter configuration.
    singularity run -B /var/lib/dcv-gl --nv --writable-tmpfs $PROJECT_HOME/code_img.sif \
        SimpleSAC.conservative_sac_main \
            --env=$ENV \
            --seed=$SEED \
            --cql.cql_min_q_weight=5.0 \
            --cql.cql_lagrange=False \
            --cql.cql_temp=1.0 \
            --cql.policy_lr=3e-4 \
            --cql.qf_lr=3e-4 \
            --policy_arch='256-256' \
            --qf_arch='256-256' \
            --eval_period=20 \
            --eval_n_trajs=10 \
            --n_epochs=1000 \
            --device='cuda' \
            --logging.output_dir="$OUTPUT_DIR/$EXP_NAME" \
            --logging.online=False \
            --logging.prefix='ExampleCQL' \
            --logging.project="$EXP_NAME" \
            --logging.random_delay=60.0
fi
