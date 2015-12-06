SQS Resurrector
=====================
[![Circle CI](https://circleci.com/gh/haskell-works/sqs-resurrector.svg?style=svg&circle-token=a3229b274096969da3d78aa37bbb8e185e6fa620)](https://circleci.com/gh/haskell-works/sqs-resurrector)
[![Docker Repository on Quay](https://quay.io/repository/haskell_works/sqs-resurrector/status "Docker Repository on Quay")](https://quay.io/repository/haskell_works/sqs-resurrector)

SQS Deal Letter Queue messages resurrector

```
Usage: sqs-resurrector [-r|--region REGION] (-q|--queue QUEUE_NAME)  
  Resurrects messages from a given dead letter queue  

Available options:  
  -h,--help                Show this help text  
  -r,--region REGION       AWS Region Name (default: Oregon)  
  -q,--queue QUEUE_NAME    Dead Letter Queue
  -l,--log LOG_LEVEL       Log level (default: Error)
  
```
