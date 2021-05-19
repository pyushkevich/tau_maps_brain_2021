#!/bin/bash
for id in $(ls work); do 
  for bl in $(ls work/$id/regeval); do 
    for stage in $(ls work/$id/regeval/$bl/metric); do 
      if [[ -d work/$id/regeval/$bl/metric/$stage ]]; then 
        for fn in $(find work/$id/regeval/$bl/metric/$stage/ -name '*.json'); do 
          echo $id $bl $stage $(cat $fn | jq .label,.bde_mad,.bde_median,.bde_mse); 
        done; 
      fi; 
    done; 
  done; 
done 2> /dev/null | awk '$4 > 0 {print $0}'
