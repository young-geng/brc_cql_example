#! /bin/bash

if [ -z "$1" ]; then
    SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    cd "$SCRIPT_DIR"

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

    job_count=3
    runs_per_job=2
    for job_idx in $(seq 0 $(($job_count - 1))); do
        slurm_run "${BASH_SOURCE[0]}" $job_count $job_idx $runs_per_job $SCRIPT_DIR
    done

else
    export JOB_COUNT=$1
    export JOB_IDX=$2
    export RUNS_PER_JOB=$3
    export SCRIPT_DIR=$4
    export PROJECT_HOME=$SCRIPT_DIR

    module load gnu-parallel

    OUTPUT_DIR="$PROJECT_HOME/experiment_output/"
    EXP_NAME='example_cql_1'
    mkdir -p $OUTPUT_DIR/$EXP_NAME
    cp "${BASH_SOURCE[0]}" $OUTPUT_DIR/$EXP_NAME

    parallel --delay 20 --linebuffer -j $RUNS_PER_JOB \
        '[ $JOB_IDX == $(({#} % $JOB_COUNT)) ] && 'singularity run -B /var/lib/dcv-gl --nv --writable-tmpfs $PROJECT_HOME/code_img.sif \
            SimpleSAC.conservative_sac_main \
                --env={1} \
                --seed={2} \
                --cql.cql_min_q_weight={3} \
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
                --logging.random_delay=30.0 \
            ::: 'hopper-medium-v2' 'walker2d-medium-replay-v2' \
            ::: 42 24 37 \
            ::: 5.0
fi
