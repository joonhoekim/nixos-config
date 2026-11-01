# `colima-up` sizes the VM to this host: CPU = physicalcpu/2 (2-8), MEM = memsize/3 GB (2-12), DISK = 60GB.
# An already-created VM keeps its prior CPU/MEM — `colima delete` first (or `colima stop && colima-up`) to resize.
# Sourced into both ~/.bashrc and ~/.zshrc (Darwin only) by modules/shared/shell-init.nix, so it must parse in both.
colima-up() {
  local phys mem_total cpu mem
  phys=$(sysctl -n hw.physicalcpu)
  mem_total=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
  cpu=$(( phys / 2 )); (( cpu < 2 )) && cpu=2; (( cpu > 8 )) && cpu=8
  mem=$(( mem_total / 3 )); (( mem < 2 )) && mem=2; (( mem > 12 )) && mem=12
  echo "colima: ${cpu} CPU / ${mem}GB RAM / 60GB disk  (host: ${phys} cores, ${mem_total}GB)"
  colima start --cpu "$cpu" --memory "$mem" --disk 60 \
    --vm-type vz --vz-rosetta --mount-type virtiofs "$@"
}
