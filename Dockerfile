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
 && apt-get install -y curl ca-certificates sudo git curl bzip2 \
 && apt-get install -y build-essential cmake tree htop bmon iotop g++ \
 && apt-get install -y libx11-6 libglib2.0-0 libsm6 libxext6 libxrender-dev

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
  && conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/pytorch/ \
  && conda config --set show_channel_urls yes ; \
 fi

# Install other python dependencies
RUN conda install -y ipython
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

# Set the default command to python3
CMD ["python3"]
WORKDIR /app/code
