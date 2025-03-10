#
# Copyright (c) 2021 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


MODEL_DIR=${MODEL_DIR-$PWD}

if [ ! -e "${MODEL_DIR}/models/image_recognition/pytorch/common/inference.py" ]; then
  echo "Could not find the script of inference.py. Please set environment variable '\${MODEL_DIR}'."
  echo "From which the inference.py exist at the: \${MODEL_DIR}/models/image_recognition/pytorch/common/inference.py"
  exit 1
fi

if [ -z "${DATASET_DIR}" ]; then
  echo "The required environment variable DATASET_DIR has not been set"
  exit 1
fi

if [ ! -d "${DATASET_DIR}" ]; then
  echo "The DATASET_DIR '${DATASET_DIR}' does not exist"
  exit 1
fi

if [ -z "${OUTPUT_DIR}" ]; then
  echo "The required environment variable OUTPUT_DIR has not been set"
  exit 1
fi

# Create the output directory in case it doesn't already exist
mkdir -p ${OUTPUT_DIR}

ARGS=""
PRECISION="fp32"
if [ "$1" == "bf16" ]; then
  ARGS="$ARGS --precision bf16"
  PRECISION="bf16"
  echo "### running bf16 datatype"
elif [ "$1" == "fp32" ]; then
  ARGS="$ARGS --precision fp32"
  echo "### running fp32 datatype"
else
  echo "The specified precision '$1' is unsupported."
  echo "Supported precisions are: fp32 and bf16"
  exit 1
fi

export DNNL_PRIMITIVE_CACHE_CAPACITY=1024
export KMP_BLOCKTIME=1
export KMP_AFFINITY=granularity=fine,compact,1,0

BATCH_SIZE=1

source "${MODEL_DIR}/quickstart/common/utils.sh"
_get_platform_type
MULTI_INSTANCE_ARGS=""
if [[ ${PLATFORM} == "linux" ]]; then
    pip list | grep intel-extension-for-pytorch
    if [[ "$?" == 0 ]]; then
        MULTI_INSTANCE_ARGS="-m intel_extension_for_pytorch.cpu.launch \
        --use_default_allocator --latency_mode --log_path=${OUTPUT_DIR} \
        --log_file_prefix="vgg11_bn_latency_log_${PRECISION}""

        # in case IPEX is used, we set ipex arg
        ARGS="${ARGS} --ipex"
        echo "Running using ${ARGS} args ..."
    fi
fi

python ${MULTI_INSTANCE_ARGS} \
  ${MODEL_DIR}/models/image_recognition/pytorch/common/inference.py \
  --data_path ${DATASET_DIR} \
  --arch vgg11_bn \
  --batch_size $BATCH_SIZE \
  --jit \
  -j 0 \
  -p 100 \
  --max_iterations 1000 \
  $ARGS 

wait

if [[ ${PLATFORM} == "linux" ]]; then
  CORES=`lscpu | grep Core | awk '{print $4}'`
  CORES_PER_INSTANCE=4

  INSTANCES_THROUGHPUT_BENCHMARK_PER_SOCKET=`expr $CORES / $CORES_PER_INSTANCE`

  throughput=$(grep 'Throughput:' ${OUTPUT_DIR}/vgg11_bn_latency_log_${PRECISION}_* |sed -e 's/.*Throughput//;s/[^0-9.]//g' |awk -v INSTANCES_PER_SOCKET=$INSTANCES_THROUGHPUT_BENCHMARK_PER_SOCKET '
  BEGIN {
          sum = 0;
          i = 0;
        }
        {
          sum = sum + $1;
          i++;
        }
  END   {
          sum = sum / i * INSTANCES_PER_SOCKET;
          printf("%.2f", sum);
  }')
  echo "vgg11_bn;"latency";${PRECISION};${BATCH_SIZE};${throughput}" | tee -a ${OUTPUT_DIR}/summary.log
fi
