ARG CUDA="9.0"
ARG CUDNN="7"
ARG UBUNTU="16.04"

FROM nvidia/cuda:${CUDA}-cudnn${CUDNN}-devel-ubuntu${UBUNTU}

# Enable repository mirrors for China
ARG USE_MIRROR="true"
ARG BUILD_NIGHTLY="false"
ARG PYTORCH_VERSION=1.1.0
ENV TORCHVISION_VERSION=0.2.2.post3
ARG PYTHON_VERSION=3.5
ARG HOROVOD_VERSION=0.16.1
RUN if [ "x${USE_MIRROR}" = "xtrue" ] ; then echo "Use mirrors"; fi
RUN if [ "x${BUILD_NIGHTLY}" = "xtrue" ] ; then echo "Build with pytorch-nightly"; fi

# Install basic utilities
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN if [ "x${USE_MIRROR}" = "xtrue" ] ; then \
 sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list \
 && sed -i 's/http:\/\/mirrors.ustc.edu.cn/https:\/\/mirrors.ustc.edu.cn/g' /etc/apt/sources.list; \
 fi
RUN apt-get update -y \
 && apt-get install -y curl ca-certificates sudo git curl bzip2 wget rsync\
 && apt-get install -y build-essential cmake tree htop bmon iotop g++ \
 && apt-get install -y libx11-6 libglib2.0-0 libsm6 libxext6 libxrender-dev \
 && apt-get install -y libjpeg-dev libpng-dev \
 && apt-get install -y libibverbs-dev \
 && apt-get install -y python${PYTHON_VERSION} \
 && apt-get install -y python${PYTHON_VERSION}-dev
RUN ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python
RUN curl -O https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    rm get-pip.py

# Create a working directory
RUN mkdir -p /app/code

# Create a non-root user and switch to it
RUN adduser --disabled-password --gecos '' --shell /bin/bash user \
 && chown -R user:user /app
RUN echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-user

# All users can use /home/user as their home directory
ENV HOME=/home/user
# RUN chmod 777 /home/user

# Install other python dependencies
RUN pip install ipython
RUN if [ "x${USE_MIRROR}" = "xtrue" ] ; then \
  pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple ; \
 fi
RUN pip install 'numpy<1.15.0' lmdb tqdm click pillow easydict tensorboardX scipy scikit-image scikit-learn ninja yacs cython matplotlib==3.0.3 opencv-python h5py

# Install PyTorch 1.0 Nightly and OpenCV
RUN if [ "x${BUILD_NIGHTLY}" = "xtrue" ] ; then \
  pip install torch_nightly -f https://download.pytorch.org/whl/nightly/cu90/torch_nightly.html ; \
 else \
  pip install torch==${PYTORCH_VERSION} ; \
 fi

# Install TorchVision master
WORKDIR /app
RUN if [ "x${BUILD_NIGHTLY}" = "xtrue" ] ; then \
  git clone https://github.com/pytorch/vision.git \
  && cd vision \
  && python setup.py install \
  && cd .. && rm -rf vision \
 else \
  pip install torchvision==${TORCHVISION_VERSION} ; \
 fi

# Install OpenMPI
RUN mkdir /tmp/openmpi && \
    cd /tmp/openmpi && \
    wget https://www.open-mpi.org/software/ompi/v4.0/downloads/openmpi-4.0.0.tar.gz && \
    tar zxf openmpi-4.0.0.tar.gz && \
    cd openmpi-4.0.0 && \
    ./configure --enable-orterun-prefix-by-default && \
    make -j $(nproc) all && \
    make install && \
    ldconfig && \
    rm -rf /tmp/openmpi

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
RUN sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config

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
    HOROVOD_GPU_ALLREDUCE=NCCL HOROVOD_WITHOUT_TENSORFLOW=1 HOROVOD_WITH_PYTORCH=1 pip install -U horovod==${HOROVOD_VERSION} && \
    ldconfig

# Set the default command to python3
WORKDIR /app/code
COPY entrypoint.sh .
ENTRYPOINT ["/app/code/entrypoint.sh"]
