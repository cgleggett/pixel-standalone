TARGETS = naive cuda cupla kokkos oneapi

.PHONY: all debug clean $(TARGETS)

CXX := g++
CXX_FLAGS := -O2 -std=c++14 -ftemplate-depth-512
CXX_DEBUG := -g

CUDA_BASE := /usr/local/cuda
NVCC := $(CUDA_BASE)/bin/nvcc -ccbin $(CXX)
NVCC_FLAGS := -O2 -std=c++14 --expt-relaxed-constexpr -w --generate-code arch=compute_35,code=sm_35
NVCC_DEBUG := -g -lineinfo

ALPAKA_BASE  := /usr/local/alpaka/alpaka
ALPAKA_FLAGS := -DALPAKA_DEBUG=0 -I$(ALPAKA_BASE)/include
CUPLA_BASE   := /usr/local/alpaka/cupla
CUPLA_FLAGS  := $(ALPAKA_FLAGS) -I$(CUPLA_BASE)/include

ONEAPI_CXX := $(shell which dpcpp 2> /dev/null)

GREEN := '\033[32m'
RED := '\033[31m'
RESET := '\033[0m'

all: $(TARGETS)

debug: $(TARGETS:%=%-debug)

clean:
	rm -f main-* debug-*

# Recommended to include only after the first target
# https://github.com/kokkos/kokkos/wiki/Compiling#42-using-kokkos-makefile-system
ifdef KOKKOS_BASE
  include $(KOKKOS_BASE)/Makefile.kokkos
  ifeq ($(KOKKOS_INTERNAL_USE_CUDA),1)
    CXX_KOKKOS := $(NVCC_WRAPPER)
    KOKKOS_CXXFLAGS += --expt-relaxed-constexpr
  else
    CXX_KOKKOS := $(CXX)
  endif
endif

# Naive CPU implementation
naive: main-naive
	@echo -e $(GREEN)naive targets built$(RESET)

naive-debug: debug-naive
	@echo -e $(GREEN)naive debug targets built$(RESET)

main-naive: main_naive.cc rawtodigi_naive.h
	$(CXX) $(CXX_FLAGS) -DDIGI_NAIVE -o $@ main_naive.cc

debug-naive: main_naive.cc rawtodigi_naive.h
	$(CXX) $(CXX_FLAGS) -DDIGI_NAIVE $(CXX_DEBUG) -o $@ main_naive.cc

ifdef CUDA_BASE
# CUDA implementation
cuda: main-cuda
	@echo -e $(GREEN)CUDA targets built$(RESET)

cuda-debug: debug-cuda
	@echo -e $(GREEN)CUDA debug targets built$(RESET)

main-cuda: main_cuda.cc rawtodigi_cuda.cu rawtodigi_cuda.h
	$(NVCC) $(NVCC_FLAGS) -DDIGI_CUDA -o $@ main_cuda.cc rawtodigi_cuda.cu

debug-cuda: main_cuda.cc rawtodigi_cuda.cu rawtodigi_cuda.h
	$(NVCC) $(NVCC_FLAGS) -DDIGI_CUDA $(NVCC_DEBUG) -o $@ main_cuda.cc rawtodigi_cuda.cu
else
cuda:
	@echo -e $(RED)NVIDIA CUDA not found$(RESET), CUDA targets will not be built

cuda-debug:
	@echo -e $(RED)NVIDIA CUDA not found$(RESET), CUDA debug targets will not be built

endif

ifdef ALPAKA_BASE
cupla: main-cupla-cuda-async main-cupla-seq-seq-async main-cupla-seq-seq-sync main-cupla-tbb-seq-async main-cupla-omp2-seq-async
	@echo -e $(GREEN)Cupla targets built$(RESET)

cupla-debug: debug-cupla-cuda-async debug-cupla-seq-seq-async debug-cupla-seq-seq-sync debug-cupla-tbb-seq-async debug-cupla-omp2-seq-async
	@echo -e $(GREEN)Cupla debug targets built$(RESET)

ifdef CUDA_BASE
# Alpaka/cupla implementation, with the CUDA GPU async backend
main-cupla-cuda-async: main_cupla.cc rawtodigi_cupla.cc rawtodigi_cupla.h
	$(NVCC) -x cu -w $(NVCC_FLAGS) -DDIGI_CUPLA -include "cupla/config/GpuCudaRt.hpp" -DCUPLA_STREAM_ASYNC_ENABLED=1 $(CUPLA_FLAGS) -o $@ main_cupla.cc rawtodigi_cupla.cc

debug-cupla-cuda-async: main_cupla.cc rawtodigi_cupla.cc rawtodigi_cupla.h
	$(NVCC) -x cu -w $(NVCC_FLAGS) -DDIGI_CUPLA -include "cupla/config/GpuCudaRt.hpp" -DCUPLA_STREAM_ASYNC_ENABLED=1 $(CUPLA_FLAGS) $(NVCC_DEBUG) -o $@ main_cupla.cc rawtodigi_cupla.cc

else
main-cupla-cuda-async:
	@echo -e $(RED)NVIDIA CUDA not found$(RESET), Cupla targets using CUDA will not be built

debug-cupla-cuda-async:
	@echo -e $(RED)NVIDIA CUDA not found$(RESET), Cupla debug targets using CUDA will not be built

endif

# Alpaka/cupla implementation, with the serial CPU async backend
main-cupla-seq-seq-async: main_cupla.cc rawtodigi_cupla.cc rawtodigi_cupla.h
	$(CXX) $(CXX_FLAGS) -DDIGI_CUPLA -include "cupla/config/CpuSerial.hpp" -DCUPLA_STREAM_ASYNC_ENABLED=1 $(CUPLA_FLAGS) -pthread -o $@ main_cupla.cc rawtodigi_cupla.cc

debug-cupla-seq-seq-async: main_cupla.cc rawtodigi_cupla.cc rawtodigi_cupla.h
	$(CXX) $(CXX_FLAGS) -DDIGI_CUPLA -include "cupla/config/CpuSerial.hpp" -DCUPLA_STREAM_ASYNC_ENABLED=1 $(CUPLA_FLAGS) -pthread $(CXX_DEBUG) -o $@ main_cupla.cc rawtodigi_cupla.cc

# Alpaka/cupla implementation, with the serial CPU sync backend
main-cupla-seq-seq-sync: main_cupla.cc rawtodigi_cupla.cc rawtodigi_cupla.h
	$(CXX) $(CXX_FLAGS) -DDIGI_CUPLA -include "cupla/config/CpuSerial.hpp" -DCUPLA_STREAM_ASYNC_ENABLED=0 $(CUPLA_FLAGS) -pthread -o $@ main_cupla.cc rawtodigi_cupla.cc

debug-cupla-seq-seq-sync: main_cupla.cc rawtodigi_cupla.cc rawtodigi_cupla.h
	$(CXX) $(CXX_FLAGS) -DDIGI_CUPLA -include "cupla/config/CpuSerial.hpp" -DCUPLA_STREAM_ASYNC_ENABLED=0 $(CUPLA_FLAGS) -pthread $(CXX_DEBUG) -o $@ main_cupla.cc rawtodigi_cupla.cc

# Alpaka/cupla implementation, with the TBB blocks backend
main-cupla-tbb-seq-async: main_cupla.cc rawtodigi_cupla.cc rawtodigi_cupla.h
	$(CXX) $(CXX_FLAGS) -DDIGI_CUPLA -include "cupla/config/CpuTbbBlocks.hpp" -DCUPLA_STREAM_ASYNC_ENABLED=1 $(CUPLA_FLAGS) -pthread -o $@ main_cupla.cc rawtodigi_cupla.cc -ltbb -lrt

debug-cupla-tbb-seq-async: main_cupla.cc rawtodigi_cupla.cc rawtodigi_cupla.h
	$(CXX) $(CXX_FLAGS) -DDIGI_CUPLA -include "cupla/config/CpuTbbBlocks.hpp" -DCUPLA_STREAM_ASYNC_ENABLED=1 $(CUPLA_FLAGS) -pthread $(CXX_DEBUG) -o $@ main_cupla.cc rawtodigi_cupla.cc -ltbb -lrt

# Alpaka/cupla implementation, with the OpenMP 2 blocks backend
main-cupla-omp2-seq-async: main_cupla.cc rawtodigi_cupla.cc rawtodigi_cupla.h
	$(CXX) $(CXX_FLAGS) -DDIGI_CUPLA -include "cupla/config/CpuOmp2Blocks.hpp" -DCUPLA_STREAM_ASYNC_ENABLED=1 $(CUPLA_FLAGS) -pthread -fopenmp -o $@ main_cupla.cc rawtodigi_cupla.cc

debug-cupla-omp2-seq-async: main_cupla.cc rawtodigi_cupla.cc rawtodigi_cupla.h
	$(CXX) $(CXX_FLAGS) -DDIGI_CUPLA -include "cupla/config/CpuOmp2Blocks.hpp" -DCUPLA_STREAM_ASYNC_ENABLED=1 $(CUPLA_FLAGS) -pthread -fopenmp $(CXX_DEBUG) -o $@ main_cupla.cc rawtodigi_cupla.cc

else
cupla:
	@echo -e $(RED)Alpaka and Cupla not found$(RESET), Alpaka and Cupla targets will not be built

cupla-debug:
	@echo -e $(RED)Alpaka and Cupla not found$(RESET), Alpaka and Cupla debug targets will not be built

endif

ifdef KOKKOS_BASE
kokkos: main-kokkos-serial main-kokkos-openmp main-kokkos-cuda
	@echo -e $(GREEN)Kokkos targets built$(RESET)

kokkos-debug:

# Kokkos implementation, serial backend
main-kokkos-serial: main_kokkos.cc rawtodigi_kokkos.h
	$(CXX_KOKKOS) $(CXX_FLAGS) $(KOKKOS_CPPFLAGS) $(KOKKOS_CXXFLAGS) $(KOKKOS_CXXLDFLAGS) -DDIGI_KOKKOS -DDIGI_KOKKOS_SERIAL -o $@ main_kokkos.cc $(KOKKOS_LIBS)

# Kokkos implementation, OpenMP backend
main-kokkos-openmp: main_kokkos.cc rawtodigi_kokkos.h
	$(CXX_KOKKOS) $(CXX_FLAGS)$(KOKKOS_CPPFLAGS) $(KOKKOS_CXXFLAGS) $(KOKKOS_CXXLDFLAGS) -DDIGI_KOKKOS -DDIGI_KOKKOS_OPENMP -o $@ main_kokkos.cc $(KOKKOS_LIBS)

# Kokkos implementation, CUDA backend
main-kokkos-cuda: main_kokkos.cc rawtodigi_kokkos.h
	$(CXX_KOKKOS) $(CXX_FLAGS)$(KOKKOS_CPPFLAGS) $(KOKKOS_CXXFLAGS) $(KOKKOS_CXXLDFLAGS) -DDIGI_KOKKOS -DDIGI_KOKKOS_CUDA -o $@ main_kokkos.cc $(KOKKOS_LIBS)

else
kokkos:
	@echo -e $(RED)Kokkos not found$(RESET), Kokkos targets will not be built

kokkos-debug:

endif

ifdef ONEAPI_CXX
oneapi: main-oneapi
	@echo -e $(GREEN)oneAPI targets built$(RESET)

oneapi-debug: debug-oneapi
	@echo -e $(GREEN)oneAPI debug targets built$(RESET)

# oneAPI implementation
main-oneapi: main_oneapi.cc rawtodigi_oneapi.cc rawtodigi_oneapi.h
	$(ONEAPI_CXX) -O2 -std=c++14 -DDIGI_ONEAPI -DDIGI_ONEAPI_WORKAROUND -o $@ main_oneapi.cc rawtodigi_oneapi.cc

debug-oneapi: main_oneapi.cc rawtodigi_oneapi.cc rawtodigi_oneapi.h
	$(ONEAPI_CXX) -g -O2 -std=c++14 -DDIGI_ONEAPI -DDIGI_ONEAPI_WORKAROUND -o $@ main_oneapi.cc rawtodigi_oneapi.cc

else
oneapi:
	@echo -e $(RED)Intel oneAPI not found$(RESET), oneAPI targets will not be built

oneapi-debug:
	@echo -e $(RED)Intel oneAPI not found$(RESET), oneAPI debug targets will not be built
endif
