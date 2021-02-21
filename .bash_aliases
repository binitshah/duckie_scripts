PATH=$PATH:/opt/vc/bin
export PATH
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/vc/lib
export LD_LIBRARY_PATH

# After long periods of storage, the Duckiebots' time can get old. Use the following alias to update it.
update_date() {
    sudo date -s "$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z"
}
