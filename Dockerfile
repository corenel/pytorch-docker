FROM nvidia/cuda:9.0-base-ubuntu16.04

# Install some basic utilities
RUN sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
# temporary fix for GPG error
RUN rm /etc/apt/sources.list.d/cuda.list
RUN apt-get update && apt-get install -y --fix-missing \
    curl \
    ca-certificates \
    sudo \
    git \
    bzip2 \
    libx11-6 \
    build-essential \
 && rm -rf /var/lib/apt/lists/*

# Create a working directory
RUN mkdir -p /app/code
WORKDIR /app/code

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
ENV CONDA_AUTO_UPDATE_CONDA=false

# Create a Python 3.5 environment
RUN /home/user/miniconda/bin/conda install conda-build \
 && /home/user/miniconda/bin/conda create -y --name py35 python=3.5.6 \
 && /home/user/miniconda/bin/conda clean -ya
ENV CONDA_DEFAULT_ENV=py35
ENV CONDA_PREFIX=/home/user/miniconda/envs/$CONDA_DEFAULT_ENV
ENV PATH=$CONDA_PREFIX/bin:$PATH

# use USTC anaconda mirror
RUN conda config --add channels https://mirrors.ustc.edu.cn/anaconda/pkgs/free/ \
 && conda config --add channels https://mirrors.ustc.edu.cn/anaconda/pkgs/main/ \
 && conda config --set show_channel_urls yes

# CUDA 9.2-specific steps
RUN conda install -y -c pytorch \
    cuda90=1.0 \
    magma-cuda90=2.3.0 \
    pytorch=0.4.1 \
    torchvision=0.2.1 \
 && conda clean -ya

# Install OpenCV3 Python bindings
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
    libgtk2.0-0 \
    libcanberra-gtk-module \
 && sudo rm -rf /var/lib/apt/lists/*
RUN conda config --add channels https://mirrors.ustc.edu.cn/anaconda/cloud/menpo/ \
 && conda install -y -c menpo opencv3 \
 && conda clean -ya

# Install other python dependencie
RUN pip install six lmdb tqdm click numpy pillow easydict tensorboardX scipy

# Set the default command to python3
CMD ["python3"]