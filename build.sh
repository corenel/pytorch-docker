#!/bin/bash
docker build -t corenel/pytorch:cu90-pytorch1.0.0-distributed  -f Dockerfile .
docker build -t corenel/pytorch:cu90-pytorch-nightly-distributed -f Dockerfile --build-arg BUILD_NIGHTLY=true .
