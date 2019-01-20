ARG CUDA="9.0"
ARG CUDNN="7"

FROM nvidia/cuda:${CUDA}-cudnn${CUDNN}-devel-ubuntu16.04

# Enable repository mirrors for China
ARG USE_MIRROR="true"
ARG BUILD_NIGHTLY="false"
ARG PYTORCH_VERSION=1.0.0
RUN if [ "x${USE_MIRROR}" = "xtrue" ] ; then echo "Use mirrors"; fi
RUN if [ "x${BUILD_NIGHTLY}" = "xtrue" ] ; then echo "Build with pytorch-nightly"; fi

# Install basic utilities
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN if [ "x${USE_MIRROR}" = "xtrue" ] ; then sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list ; fi
RUN apt-get update -y \
 && apt-get install -y curl ca-certificates sudo git curl bzip2 wget \
 && apt-get install -y build-essential cmake tree htop bmon iotop g++ \
 && apt-get install -y libx11-6 libglib2.0-0 libsm6 libxext6 libxrender-dev \
 && apt-get install -y libjpeg-dev libpng-dev \
 && apt-get install -y libibverbs-dev

# Create a working directory
RUN mkdir -p /app/code

# Create a non-root user and switch to it
RUN adduser --disabled-password --gecos '' --shell /bin/bash user \
 && chown -R user:user /app
RUN echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-user
USER user

# All users can use /home/user as their home directory
ENV HOME=/home/user
RUN chmod 777 /home/user

# Install Miniconda
RUN curl -so ~/miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh \
 && chmod +x ~/miniconda.sh \
 && ~/miniconda.sh -b -p ~/miniconda \
 && rm ~/miniconda.sh
ENV PATH=/home/user/miniconda/bin:$PATH

# Create a Python 3.5 environment
RUN /home/user/miniconda/bin/conda install -y conda-build \
 && /home/user/miniconda/bin/conda create -y --name py35 python=3.5.6 \
 && /home/user/miniconda/bin/conda clean -ya
ENV CONDA_DEFAULT_ENV=py35
ENV CONDA_PREFIX=/home/user/miniconda/envs/$CONDA_DEFAULT_ENV
ENV PATH=$CONDA_PREFIX/bin:$PATH
ENV CONDA_AUTO_UPDATE_CONDA=false

# Use USTC anaconda mirror
RUN if [ "x${USE_MIRROR}" = "xtrue" ] ; then \
  conda config --add channels https://mirrors.ustc.edu.cn/anaconda/pkgs/free/ \
  && conda config --add channels https://mirrors.ustc.edu.cn/anaconda/pkgs/main/ \
  && conda config --add channels https://mirrors.ustc.edu.cn/anaconda/cloud/conda-forge/ \
  && conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/pytorch/ \
  && conda config --set show_channel_urls yes ; \
 fi

# Install other python dependencies
RUN conda install -y ipython
RUN pip install -U pip
RUN if [ "x${USE_MIRROR}" = "xtrue" ] ; then \
  pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple ; \
 fi
RUN pip install lmdb tqdm click pillow easydict tensorboardX scipy scikit-image scikit-learn ninja yacs cython matplotlib opencv-python

# Install PyTorch 1.0 Nightly and OpenCV
RUN if [ "x${BUILD_NIGHTLY}" = "xtrue" ] ; then \
  conda install -y pytorch-nightly -c pytorch  \
  && conda clean -ya ; \
 else \
  conda install -y pytorch=="${PYTORCH_VERSION}" -c pytorch  \
  && conda clean -ya ; \
 fi

# Install TorchVision master
WORKDIR /app
RUN git clone https://github.com/pytorch/vision.git \
 && cd vision \
 && python setup.py install \
 && cd .. && rm -rf vision

# Install OpenMPI
USER root
RUN mkdir /tmp/openmpi && \
    cd /tmp/openmpi && \
    wget https://www.open-mpi.org/software/ompi/v3.1/downloads/openmpi-3.1.2.tar.gz && \
    tar zxf openmpi-3.1.2.tar.gz && \
    cd openmpi-3.1.2 && \
    ./configure --enable-orterun-prefix-by-default && \
    make -j $(nproc) all && \
    make install && \
    ldconfig && \
    rm -rf /tmp/openmpi

# Create a wrapper for OpenMPI to allow running as root by default
RUN mv /usr/local/bin/mpirun /usr/local/bin/mpirun.real && \
    echo '#!/bin/bash' > /usr/local/bin/mpirun && \
    echo 'mpirun.real --allow-run-as-root "$@"' >> /usr/local/bin/mpirun && \
    chmod a+x /usr/local/bin/mpirun

# Configure OpenMPI to run good defaults:
#   --bind-to none --map-by slot --mca btl_tcp_if_exclude lo,docker0
RUN echo "hwloc_base_binding_policy = none" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo "rmaps_base_mapping_policy = slot" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo "btl_tcp_if_exclude = lo,docker0" >> /usr/local/etc/openmpi-mca-params.conf

# Set default NCCL parameters
RUN echo NCCL_DEBUG=INFO >> /etc/nccl.conf

# Install OpenSSH for MPI to communicate between containers
RUN apt-get install -y --no-install-recommends openssh-client openssh-server gosu && \
    mkdir -p /var/run/sshd

# Allow OpenSSH to talk to containers without asking for confirmation
RUN cat /etc/ssh/ssh_config | grep -v StrictHostKeyChecking > /etc/ssh/ssh_config.new && \
    echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config.new && \
    mv /etc/ssh/ssh_config.new /etc/ssh/ssh_config

# Setup root and user login
RUN echo 'root:screencast' | chpasswd
RUN echo 'user:user' | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile
EXPOSE 22

# Fix locale
RUN apt-get update && apt-get install -y locales
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "LANG=en_US.UTF-8" > /etc/locale.conf
RUN locale-gen en_US.UTF-8

# Install Horovod, temporarily using CUDA stubs
RUN ldconfig /usr/local/cuda-9.0/targets/x86_64-linux/lib/stubs && \
    HOROVOD_GPU_ALLREDUCE=NCCL HOROVOD_WITHOUT_TENSORFLOW=1 HOROVOD_WITH_PYTORCH=1 pip install --no-cache-dir git+https://github.com/uber/horovod.git#egg=horovod && \
    ldconfig

# Set the default command to python3
WORKDIR /app/code
ENTRYPOINT ["/app/code/entrypoint.sh"]
