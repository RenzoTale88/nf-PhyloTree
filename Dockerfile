FROM condaforge/mambaforge:latest AS build

LABEL authors="andrea.talenti@ed.ac.uk" \
      description="Docker image containing base requirements for ADMIXBoots pipelines"

# Install the updates first
RUN apt-get update && \
  apt-get install -y gcc g++ git make zlib1g-dev && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install the package as normal:
COPY environment.yml .
RUN mamba env create -f environment.yml

# Install conda-pack:
RUN mamba install -c conda-forge conda-pack

# Use conda-pack to create a standalone enviornment
# in /venv:
RUN conda-pack --ignore-missing-files -n phylotree -o /tmp/env.tar && \
    mkdir /venv && \
    cd /venv && \
    tar xf /tmp/env.tar && \
    /venv/bin/conda-unpack

# The runtime-stage image; we can use Debian as the
# base image since the Conda env also includes Python
# for us.
FROM ubuntu:24.04 AS runtime

# Install procps in debian to make it compatible with reporting
RUN apt-get update && \
  apt install -y git procps file wget python3-dev python3-pip && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy /venv from the previous stage:
COPY --from=build /venv /venv

# When image is run, run the code with the environment
# activated:
ENV PATH=/venv/bin/:$PATH
SHELL ["/bin/bash", "-c"]
