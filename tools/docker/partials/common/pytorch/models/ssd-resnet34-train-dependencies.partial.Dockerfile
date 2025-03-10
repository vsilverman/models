RUN source activate pytorch && \
    pip install --upgrade pip && \
    pip install --no-cache-dir https://github.com/mlperf/logging/archive/9ea0afa.zip && \
    pip install --no-cache-dir \
        Cython==0.28.4 \
        git+http://github.com/NVIDIA/apex.git@9041a868a1a253172d94b113a963375b9badd030#egg=apex \
        mlperf-compliance==0.0.10 \
        cycler==0.10.0 \
        kiwisolver==1.0.1 \
        matplotlib==2.2.2 \
        Pillow>=9.3.0 \
        pyparsing==2.2.0 \
        python-dateutil==2.7.3 \
        pytz==2018.5 \
        six==1.11.0 \
        torchvision==0.2.1 \
        pycocotools==2.0.2
