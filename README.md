# Example Project for Running SAC on BRC with Singularity Container
This is an example project showcasing a practical workflow on
[BRC Savio cluster](https://docs-research-it.berkeley.edu/services/high-performance-computing/user-guide/).
For demonstration, we will use my SAC implementation as an example, and provide
instructions for building the container and running it on BRC cluster.


## Project Structure

* brc_cql_example
    * [CQL](CQL/):  Python SAC implementation directly taken from [this repo](https://github.com/young-geng/CQL)
        * environment.yml:  anaconda environment file listing all the dependencies
        * ...
    * [base_container.def](base_container.def):   singularity definition file for the base container, with all the dependencies installed but without the code
    * [code_container.def](code_container.def):   singularity definition file for the code container, copying the code to base container
    * [job_script.sh](job_script.sh):    simple script for launching jobs with slurm on BRC
    * [advanced_job_script.sh](advanced_job_script.sh):   more adavanced job script based on GNU Parallel, useful for large hyperparameter sweep



## Instructions
Here we provide step by step instructions for building the container and running
it on BRC. In order to reproduce this steps, you will need a machine running Linux.

### Install Singularity Container
The first step is to install singularity container locally. Please follow the
[instruction here](https://sylabs.io/guides/3.7/user-guide/quick_start.html#quick-installation-steps).
I recommend version no earlier than 3.7.

### Build the Base Container
The base container is the container that packages all the dependencies for this project. It is built on
top of a public singularity image with anconda and mujoco pre-installed. Run the following command to
build the base container. You only need to do this once in the beginning, unless you change the required
python packages. For detailed information about the building process, see [base_container.def](base_container.def).

```
singularity build --fakeroot base_img.sif base_container.def
```

### Build the Code Container
Run the following command to build the code container that package our research
project. For detailed information on how container is built, see [code_container.def](code_container.def).

```
singularity build --fakeroot code_img.sif code_container.def
```


### Copy the Container and Job Script to BRC
First ssh into the BRC DTN node, and create the project directory.
```
cd /global/scratch/users/<YOUR BRC USER NAME>
mkdir brc_cql_example
```

Then use scp to copy the job scripts and container to BRC.
```
scp ./code_img.sif ./job_script.sh ./advanced_job_script.sh \
    <YOUR BRC USER NAME>@dtn.brc.berkeley.edu:/global/scratch/users/<YOUR BRC USER NAME>/brc_cql_example/
```

### Launch the job
We have two example job script here. One naive one that runs one training process
for each slurm job, and one advanced one that runs multiple processes in parallel
for each slurm job. To use the naive one, run the following command on BRC login node:
```
./job_script.sh
```

To used the adavanced job script, run the following command:
```
./advanced_job_script.sh
```