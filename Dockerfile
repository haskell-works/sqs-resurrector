FROM fpco/haskell-scratch
MAINTAINER Alexey Raga <alexey.raga@gmail.com>

COPY .stack-work/install/*/*/*/bin/* /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/sqs-resurrector"]
