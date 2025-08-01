#!/bin/bash
cd $HOME/noVNC
./utils/novnc_proxy --vnc localhost:$((5900+[DISPLAY]))