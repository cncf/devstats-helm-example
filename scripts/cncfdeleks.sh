#!/bin/bash
AWS_PROFILE=cncf eksctl delete cluster --name=CNCFcluster
AWS_PROFILE=cncf eksctl delete nodegroup --name=CNCFnodegroup
