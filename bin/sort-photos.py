#!/usr/bin/env python3
import subprocess
import os
import sys
import shutil

#---
save_to = "backup2"
#---

directory = sys.argv[1]
if not os.path.exists(save_to):
    os.mkdir(save_to)

get = lambda cmd: subprocess.check_output(["/bin/bash", "-c", cmd]).decode("utf-8")

def check_dir(dr):
    if not os.path.exists(dr):
        os.mkdir(dr)

def rename_dups(target_dir, name):
    n = 1; name_orig = name
    while os.path.exists(target_dir+"/"+name):
        name = "duplicate_"+str(n)+"_"+name_orig
        n = n+1
    return target_dir+"/"+name

for root, dirs, files in os.walk(directory):
    for name in files:
        file = root+"/"+name
        try:
            date = [l for l in get("exif "+'"'+file+'"').splitlines()\
                    if "Dat" in l][0].split("|")[1].split()[0]
            if "-" in date:
                date = date.split("-")[:2]
            elif ":" in date:
                date = date.split(":")[:2]
            targeted_dir = save_to+"/"+date[0]
            check_dir(targeted_dir)
            sub_dir = targeted_dir+"/"+date[1]
        except:
            sub_dir = save_to+"/"+"undetermined"
        check_dir(sub_dir)
        newfile = rename_dups(sub_dir, name)
        shutil.copyfile(file, newfile)