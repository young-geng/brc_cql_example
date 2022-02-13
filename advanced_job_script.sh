#! /bin/bash

# This is an advanced job script that uses GNU Parallel for hyperparameter seach.
# We use Parallel to launch M jobs, with each job running N processes in parallel.
# By using some tricks, we can evenly distribution our overall hyperparameter configurations
# to these M x N total parallel processes.
#
# The script serves both as a launcher script that should be run on the
# login node and a job script that slurm invokes on the compute nodes. The launcher
# script function is triggered when the script is invoked without any argument.

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

    # Here we use a single for loop to launch N slurm jobs. We pass the following
    # arguments to the job: total job count, job index, parallel processes for each job, script directory
    job_count=3  # Total number of slurm jobs
    runs_per_job=2  # Number of processes to run in parallel for each slurm job
    for job_idx in $(seq 0 $(($job_count - 1))); do
        slurm_run "${BASH_SOURCE[0]}" $job_count $job_idx $runs_per_job $SCRIPT_DIR
    done

else
    # Receive arguments
    export JOB_COUNT=$1
    export JOB_IDX=$2
    export RUNS_PER_JOB=$3
    export SCRIPT_DIR=$4
    export PROJECT_HOME=$SCRIPT_DIR

    # Make GNU Parallel available
    module load gnu-parallel

    # Create log output directory
    OUTPUT_DIR="$PROJECT_HOME/experiment_output/"
    EXP_NAME='example_cql_1'
    mkdir -p $OUTPUT_DIR/$EXP_NAME
    cp "${BASH_SOURCE[0]}" $OUTPUT_DIR/$EXP_NAME


    # Use GNU parallel to run the job.
    # By prefixing the command with '[ $JOB_IDX == $(({#} % $JOB_COUNT)) ] && ',
    # we only run the configurations that belongs to the current slurm job.
    # {#} evaluates to the id of each hyperparam config, and $JOB_IDX == $(({#} % $JOB_COUNT))
    # evaluates to true only when the current hyperparam id modulus the total number of
    # slurm jobs equals the current slurm job id. Thefore, the following command
    # would only run if the config id belongs to the current slurm job.
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
                --logging.random_delay=60.0 \
            ::: 'hopper-medium-v2' 'walker2d-medium-replay-v2' \
            ::: 42 24 37 \
            ::: 5.0
fi
