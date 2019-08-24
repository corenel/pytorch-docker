#!/bin/bash
docker build -t corenel/pytorch:cu100-pytorch1.2.0-distributed  -f Dockerfile.cu100.py36 .
docker build -t corenel/pytorch:cu100-pytorch-nightly-distributed -f Dockerfile.cu100.py36 --build-arg BUILD_NIGHTLY=true .
