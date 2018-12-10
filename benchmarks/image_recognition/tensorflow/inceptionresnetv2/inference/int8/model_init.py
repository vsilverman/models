#
# -*- coding: utf-8 -*-
#
# Copyright (c) 2018 Intel Corporation
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
# SPDX-License-Identifier: EPL-2.0
#

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from common.base_model_init import BaseModelInitializer

import os

os.environ["KMP_BLOCKTIME"] = "1"
os.environ["KMP_AFFINITY"] = "granularity=fine,verbose,compact,1,0"
os.environ["KMP_SETTINGS"] = "1"


class ModelInitializer(BaseModelInitializer):
  """Detect the platform information and set necessary variables before launching the model"""

  def __init__(self, args, custom_args=[], platform_util=None):

    self.args = args
    self.platform_util = platform_util
    self.inference_command = ''

    # use default batch size if -1
    if self.args.batch_size == -1:
      self.args.batch_size = 128

    self.args.num_inter_threads = 1
    self.args.num_intra_threads = self.platform_util.num_cores_per_socket()

    if not self.args.single_socket:
      self.args.num_intra_threads *= self.platform_util.num_cpu_sockets()
      self.args.num_inter_threads = 2

    if self.args.benchmark_only:
      # benchmark_script = os.path.join(
      #   os.path.dirname(os.path.realpath(__file__)), "eval_image_classifier_benchmark.py")

      benchmark_script = os.path.join(self.args.intelai_models,
                                      self.args.platform, "eval_image_classifier_benchmark.py")
      self.inference_command = "python " + benchmark_script

      if self.args.single_socket:
        socket_id_str = str(self.args.socket_id)
        self.inference_command = \
          'numactl --cpunodebind=' + socket_id_str + ' --membind=' + socket_id_str + ' ' + self.inference_command

      os.environ["OMP_NUM_THREADS"] = str(self.args.num_intra_threads)

      self.inference_command = self.inference_command + \
                               ' --input-graph=' + self.args.input_graph + \
                               ' --inter-op-parallelism-threads=' + str(self.args.num_inter_threads) + \
                               ' --intra-op-parallelism-threads=' + str(self.args.num_intra_threads) + \
                               ' --batch-size=' + str(self.args.batch_size)

    elif self.args.accuracy_only:
      # accuracy_script = os.path.join(
      #   os.path.dirname(os.path.realpath(__file__)), "eval_image_classifier_accuracy.py")

      accuracy_script = os.path.join(self.args.intelai_models,
                                     self.args.platform, "eval_image_classifier_accuracy.py")
      self.inference_command = "python " + accuracy_script

      if self.args.single_socket:
        socket_id_str = str(self.args.socket_id)
        self.inference_command = \
          'numactl --cpunodebind=' + socket_id_str + ' --membind=' + socket_id_str + ' ' + self.inference_command

      os.environ["OMP_NUM_THREADS"] = str(self.args.num_intra_threads)

      self.inference_command = self.inference_command + \
                               ' --input_graph=' + self.args.input_graph + \
                               ' --data_location=' + self.args.data_location + \
                               ' --input_height=299' + \
                               ' --input_width=299' + \
                               ' --num_inter_threads=' + str(self.args.num_inter_threads) + \
                               ' --num_intra_threads=' + str(self.args.num_intra_threads) + \
                               ' --output_layer=InceptionResnetV2/Logits/Predictions' + \
                               ' --batch_size=' + str(self.args.batch_size)


  def run(self):
    """run command to enable model benchmark or accuracy measurement"""

    if self.inference_command:
      self.run_command(self.inference_command)
