#! /bin/bash
# This is a job script that uses array jobs and GNU parallel to launch a hyperparameter
# sweep. We use Parallel to launch M array tasks, with each job running N processes in parallel.
# By using some tricks, we can evenly distribution our overall hyperparameter configurations
# to these M x N total parallel processes.

# Job configurations. Note in the last line that we are launching an array job of 4 tasks,
# all tasks will execute this script. We use the environment variable SLURM_ARRAY_TASK_ID
# to determine which array task it is.

#SBATCH --job-name=example_cql
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=72:00:00
#SBATCH --account=co_rail
#SBATCH --qos=rail_gpu3_normal
#SBATCH --partition=savio3_gpu
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --gres=gpu:TITAN:1
#SBATCH --array=0-3

# Exit the script if it is not launched from slurm.
if [ -z "$SLURM_JOB_ID" ]; then
    echo "This script is not launched with slurm, exiting!"
    exit 1
fi

# Load GNU parallel software
module load gnu-parallel

# Get the current directory of the script
export SCRIPT_PATH="$(scontrol show job $SLURM_JOBID | awk -F= '/Command=/{print $2}' | head -n 1)"
export SCRIPT_DIR="$(dirname $SCRIPT_PATH)"
cd $SCRIPT_DIR


# Create log output directory and copy over this script for logging purpose
OUTPUT_DIR="$SCRIPT_DIR/experiment_output"
EXP_NAME='example_cql_1'
mkdir -p "$OUTPUT_DIR/$EXP_NAME"
cp "$SCRIPT_PATH" "$OUTPUT_DIR/$EXP_NAME/"

# Controls how many processes are running in parallel for each array task
export RUNS_PER_TASK=4

# Use GNU parallel to run the sweep.
# By prefixing the command with '[ $SLURM_ARRAY_TASK_ID == $(({#} % $SLURM_ARRAY_TASK_COUNT)) ] && ',
# we only run the configurations that belongs to the current slurm array task.
# {#} evaluates to the id of each hyperparam config, and
# $SLURM_ARRAY_TASK_ID == $(({#} % $SLURM_ARRAY_TASK_COUNT)) evaluates to true only when
# the current hyperparam id modulus the total number of slurm array tasks equals the
# current slurm array task id. Thefore, the following command would only run if the config id
# belongs to the current slurm array task.
parallel --delay 20 --linebuffer -j $RUNS_PER_TASK \
    '[ $SLURM_ARRAY_TASK_ID == $(({#} % $SLURM_ARRAY_TASK_COUNT)) ] && 'singularity run -B /var/lib/dcv-gl --nv --writable-tmpfs $SCRIPT_DIR/code_img.sif \
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
            --logging.output_dir="$OUTPUT_DIR/example_cql_1" \
            --logging.online=False \
            --logging.prefix='ExampleCQL' \
            --logging.project="$EXP_NAME" \
            --logging.random_delay=60.0 \
        ::: 'hopper-medium-v2' 'walker2d-medium-replay-v2' \
        ::: 42 24 37 \
        ::: 3.0 5.0