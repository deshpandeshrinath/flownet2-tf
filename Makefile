# Makefile

TF_INC = `python -c "import tensorflow; print(tensorflow.sysconfig.get_include())"`

ifndef CUDA_HOME
    CUDA_HOME := /usr/local/cuda
endif

CC        = gcc -O2 -pthread
CXX       = g++
GPUCC     = nvcc
CFLAGS    = -std=c++11 -I$(TF_INC) -I"$(CUDA_HOME)/include" -DGOOGLE_CUDA=1
GPUCFLAGS = -c
LFLAGS    = -pthread -shared -fPIC
GPULFLAGS = -x cu -Xcompiler -fPIC
CGPUFLAGS = -L$(CUDA_HOME)/lib -L$(CUDA_HOME)/lib64 -lcudart

OUT_DIR   = src/ops/build
PREPROCESSING_SRC = "src/ops/preprocessing/preprocessing.cc" "src/ops/preprocessing/kernels/flow_augmentation.cc" "src/ops/preprocessing/kernels/spatial_transform.cc"
GPU_SRC_SPATIAL  	= src/ops/preprocessing/kernels/spatial_transform_gpu.cu.cc
GPU_SRC_FLOW     	= src/ops/preprocessing/kernels/flow_augmentation_gpu.cu.cc
GPU_PROD_SPATIAL 	= $(OUT_DIR)/spatial_transform_gpu.o
GPU_PROD_FLOW    	= $(OUT_DIR)/flow_augmentation_gpu.o
PREPROCESSING_PROD	= $(OUT_DIR)/preprocessing.so

DOWNSAMPLE_SRC = "src/ops/downsample/downsample_kernel.cc" "src/ops/downsample/downsample_op.cc"
GPU_SRC_DOWNSAMPLE  = src/ops/downsample/downsample_kernel_gpu.cu.cc
GPU_PROD_DOWNSAMPLE = $(OUT_DIR)/downsample_kernel_gpu.o
DOWNSAMPLE_PROD 	= $(OUT_DIR)/downsample.so


ifeq ($(OS),Windows_NT)
    detected_OS := Windows
else
    detected_OS := $(shell sh -c 'uname -s 2>/dev/null || echo not')
endif
ifeq ($(detected_OS),Darwin)  # Mac OS X
	CGPUFLAGS += -undefined dynamic_lookup
endif
ifeq ($(detected_OS),Linux)
	CFLAGS += -D_MWAITXINTRIN_H_INCLUDED -D_FORCE_INLINES -D__STRICT_ANSI__ -D_GLIBCXX_USE_CXX11_ABI=0
endif

default: gpu

gpu:
	$(GPUCC) -g $(CFLAGS) $(GPUCFLAGS) $(GPU_SRC_SPATIAL) $(GPULFLAGS) $(GPUDEF) -o $(GPU_PROD_SPATIAL)
	$(GPUCC) -g $(CFLAGS) $(GPUCFLAGS) $(GPU_SRC_FLOW) $(GPULFLAGS) $(GPUDEF) -o $(GPU_PROD_FLOW)
	$(CXX) -g $(CFLAGS)  $(PREPROCESSING_SRC) $(GPU_PROD_SPATIAL) $(GPU_PROD_FLOW) $(LFLAGS) $(CGPUFLAGS) -o $(PREPROCESSING_PROD)
	$(GPUCC) -g $(CFLAGS) $(GPUCFLAGS) $(GPU_SRC_DOWNSAMPLE) $(GPULFLAGS) $(GPUDEF) -o $(GPU_PROD_DOWNSAMPLE)
	$(CXX) -g $(CFLAGS)  $(DOWNSAMPLE_SRC) $(GPU_PROD_DOWNSAMPLE) $(LFLAGS) $(CGPUFLAGS) -o $(DOWNSAMPLE_PROD)

clean:
	rm -f $(PREPROCESSING_PROD) $(GPU_PROD_FLOW) $(GPU_PROD_SPATIAL) $(DOWNSAMPLE_PROD) $(GPU_PROD_DOWNSAMPLE)
